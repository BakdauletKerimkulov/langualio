import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CLAUDE_API_KEY = Deno.env.get("CLAUDE_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CLAUDE_API_URL = "https://api.anthropic.com/v1/messages";
const CLAUDE_MODEL = "claude-sonnet-4-20250514";
const MAX_TOKENS = 1024;

serve(async (req) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey",
      },
    });
  }

  try {
    // 1. Verify auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing authorization" }, 401);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    // 2. Parse request
    const { message, context_source, context_payload } = await req.json();
    if (!message || typeof message !== "string") {
      return jsonResponse({ error: "Message is required" }, 400);
    }

    // 3. Check daily limit
    const today = new Date().toISOString().split("T")[0];

    const { data: configData } = await supabase
      .from("app_config")
      .select("value")
      .eq("key", "daily_message_limit")
      .single();

    const dailyLimit = parseInt(configData?.value ?? "20");

    // Upsert daily usage
    const { data: usageData } = await supabase
      .from("user_daily_usage")
      .select("message_count")
      .eq("user_id", user.id)
      .eq("date", today)
      .single();

    const currentCount = usageData?.message_count ?? 0;

    if (currentCount >= dailyLimit) {
      return jsonResponse(
        { error: "Daily message limit reached", remaining: 0, limit: dailyLimit },
        429,
        { "X-Daily-Limit": String(dailyLimit), "X-Daily-Remaining": "0" }
      );
    }

    // 4. Get user profile for system prompt
    const { data: profile } = await supabase
      .from("profiles")
      .select("*")
      .eq("id", user.id)
      .single();

    // 5. Get recent chat history
    const { data: history } = await supabase
      .from("chat_messages")
      .select("role, text")
      .eq("user_id", user.id)
      .order("created_at", { ascending: false })
      .limit(20);

    const messages = (history ?? []).reverse().map((m: any) => ({
      role: m.role,
      content: m.text,
    }));

    // Add current message
    messages.push({ role: "user", content: message });

    // 6. Build system prompt
    const systemPrompt = buildSystemPrompt(profile, context_payload);

    // 7. Save user message
    await supabase.from("chat_messages").insert({
      user_id: user.id,
      role: "user",
      text: message,
      context_source: context_source ?? null,
      context_payload: context_payload ?? null,
    });

    // 8. Call Claude API with streaming
    const claudeResponse = await fetch(CLAUDE_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": CLAUDE_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: MAX_TOKENS,
        stream: true,
        system: systemPrompt,
        messages,
      }),
    });

    if (!claudeResponse.ok) {
      const errorText = await claudeResponse.text();
      console.error("Claude API error:", claudeResponse.status, errorText);
      return jsonResponse({ error: "AI service error" }, 502);
    }

    // 9. Stream response back, collecting full text
    const reader = claudeResponse.body!.getReader();
    const decoder = new TextDecoder();
    let fullResponse = "";

    const remaining = dailyLimit - currentCount - 1;

    const stream = new ReadableStream({
      async start(controller) {
        const encoder = new TextEncoder();
        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            const chunk = decoder.decode(value, { stream: true });
            controller.enqueue(encoder.encode(chunk));

            // Parse SSE to collect full text
            for (const line of chunk.split("\n")) {
              if (!line.startsWith("data: ")) continue;
              const data = line.substring(6);
              if (data === "[DONE]") continue;
              try {
                const json = JSON.parse(data);
                if (json.type === "content_block_delta" && json.delta?.text) {
                  fullResponse += json.delta.text;
                }
              } catch { /* skip */ }
            }
          }
        } finally {
          // 10. Save assistant message and update usage
          await supabase.from("chat_messages").insert({
            user_id: user.id,
            role: "assistant",
            text: fullResponse,
          });

          // Upsert daily usage
          await supabase.from("user_daily_usage").upsert(
            {
              user_id: user.id,
              date: today,
              message_count: currentCount + 1,
            },
            { onConflict: "user_id,date" }
          );

          controller.close();
        }
      },
    });

    return new Response(stream, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "X-Daily-Limit": String(dailyLimit),
        "X-Daily-Remaining": String(remaining),
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Expose-Headers": "X-Daily-Limit, X-Daily-Remaining",
      },
    });
  } catch (error) {
    console.error("Edge function error:", error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

function buildSystemPrompt(profile: any, contextPrompt?: string): string {
  const lines = [
    'You are an AI English tutor called "AI Tutor" in the Langualio app.',
    "Your role is to help the user learn English in a friendly and encouraging way.",
    "",
    "## User Profile",
    `- Name: ${profile?.name ?? "Learner"}`,
    `- Level: ${profile?.level ?? 1}`,
    `- Current XP: ${profile?.current_xp ?? 0}/${profile?.target_xp ?? 500}`,
    `- Streak: ${profile?.streak_days ?? 0} days`,
    "",
    "## Behaviour Rules",
    "- Explain in Russian, give examples in English.",
    "- Keep answers short and clear — no walls of text.",
    "- When the user makes a mistake, give a hint first, not the answer.",
    "- Do NOT translate large texts — teach the user to break them down.",
    "- Stay on topic: English learning only. Politely redirect off-topic questions.",
    `- Adapt difficulty to the user's level (${profile?.level ?? 1}).`,
    "- Use emoji sparingly for encouragement.",
  ];

  if (contextPrompt) {
    lines.push(
      "",
      "## Current Context",
      "The user opened this chat from a specific screen with this context:",
      contextPrompt
    );
  }

  return lines.join("\n");
}

function jsonResponse(
  body: Record<string, unknown>,
  status: number,
  extraHeaders?: Record<string, string>
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      ...extraHeaders,
    },
  });
}
