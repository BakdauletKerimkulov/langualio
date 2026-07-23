import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { CLAUDE_API_URL, CLAUDE_MODEL } from "../_shared/constants.ts";
import { handleCors } from "../_shared/cors.ts";
import { verifyAuth, type AuthResult } from "../_shared/auth.ts";
import { jsonResponse } from "../_shared/response.ts";
import { requireEnv } from "../_shared/env.ts";

const MAX_TOKENS = 1024;
const MAX_MESSAGE_LENGTH = 10_000;
const MAX_CONTEXT_PAYLOAD_LENGTH = 500;

// CEFR level mapping: DB int → human-readable label
const CEFR_LABELS: Record<number, string> = {
  1: "A1",
  2: "A2",
  3: "B1",
  4: "B2",
  5: "C1",
};

serve(async (req) => {
  // CORS
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // 1. Verify auth
    const authResult = await verifyAuth(req);
    if (authResult instanceof Response) return authResult;
    const { user, supabase } = authResult as AuthResult;

    // 2. Parse request
    const { message, context_source, context_payload } = await req.json();
    if (!message || typeof message !== "string") {
      return jsonResponse({ error: "Message is required" }, 400);
    }

    // Input validation: message length
    if (message.length > MAX_MESSAGE_LENGTH) {
      return jsonResponse({ error: "Message too long" }, 400);
    }

    // 3. Atomic quota check (consume before Claude call, prevents race conditions)
    const { data: configData } = await supabase
      .from("app_config")
      .select("value")
      .eq("key", "daily_message_limit")
      .single();

    const dailyLimit = parseInt(configData?.value ?? "20");

    const { data: quotaGranted, error: quotaError } = await supabase.rpc(
      "try_consume_quota",
      { p_user_id: user.id, p_kind: "message", p_limit: dailyLimit }
    );

    if (quotaError) {
      console.error("Quota RPC error:", quotaError);
      return jsonResponse({ error: "Internal server error" }, 500);
    }

    if (!quotaGranted) {
      return jsonResponse(
        {
          error: "Daily message limit reached",
          daily_remaining: 0,
          daily_limit: dailyLimit,
        },
        429
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

    // 6. Sanitize context_payload and build system prompt
    const sanitizedContext = sanitizeContextPayload(context_payload);
    const systemPrompt = buildSystemPrompt(profile, sanitizedContext);

    // 7. Save user message
    await supabase.from("chat_messages").insert({
      user_id: user.id,
      role: "user",
      text: message,
      context_source: context_source ?? null,
      context_payload: context_payload ?? null,
    });

    // 8. Call Claude API (non-streaming JSON mode)
    const claudeApiKey = requireEnv("CLAUDE_API_KEY");
    const claudeResponse = await fetch(CLAUDE_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": claudeApiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: MAX_TOKENS,
        system: systemPrompt,
        messages,
      }),
    });

    if (!claudeResponse.ok) {
      const errorText = await claudeResponse.text();
      console.error("Claude API error:", claudeResponse.status, errorText);
      return jsonResponse({ error: "AI service error" }, 502);
    }

    const claudeData = await claudeResponse.json();
    console.log(
      `Claude API response: model=${claudeData.model}, stop_reason=${claudeData.stop_reason}, content_blocks=${claudeData.content?.length ?? 0}`
    );
    const responseText = claudeData.content?.[0]?.text ?? "";

    if (!responseText) {
      console.warn(
        "Empty response from Claude API. Raw response:",
        JSON.stringify(claudeData)
      );
    }

    // 9. Save assistant message (quota already consumed atomically in step 3)
    await supabase.from("chat_messages").insert({
      user_id: user.id,
      role: "assistant",
      text: responseText,
    });

    // Fetch updated count for remaining calculation
    const today = new Date().toISOString().split("T")[0];
    const { data: updatedUsage } = await supabase
      .from("user_daily_usage")
      .select("message_count")
      .eq("user_id", user.id)
      .eq("date", today)
      .single();

    const remaining = dailyLimit - (updatedUsage?.message_count ?? 0);

    // 10. Return JSON response
    return jsonResponse(
      {
        text: responseText,
        daily_limit: dailyLimit,
        daily_remaining: remaining,
      },
      200
    );
  } catch (error) {
    console.error("Edge function error:", error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

/// Sanitize context_payload: truncate, strip control chars, escape delimiters
function sanitizeContextPayload(
  payload: string | undefined | null
): string | undefined {
  if (!payload || typeof payload !== "string") return undefined;

  let sanitized = payload.slice(0, MAX_CONTEXT_PAYLOAD_LENGTH);

  // Strip ASCII control characters (0x00–0x1F) except newline (0x0A) and tab (0x09)
  sanitized = sanitized.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, "");

  // Escape prompt section delimiters
  sanitized = sanitized.replace(/^## /gm, "\\## ");
  sanitized = sanitized.replace(/^---$/gm, "\\---");

  return sanitized;
}

function buildSystemPrompt(profile: any, contextPrompt?: string): string {
  const cefrLevel = profile?.cefr_level as number | null;
  const cefrLabel = cefrLevel
    ? (CEFR_LABELS[cefrLevel] ?? "beginner")
    : "beginner";

  const lines = [
    'You are an AI English tutor called "AI Tutor" in the Langualio app.',
    "Your role is to help the user learn English in a friendly and encouraging way.",
    "",
    "## User Profile",
    `- Name: ${profile?.nickname ?? "Learner"}`,
    `- CEFR Level: ${cefrLabel}`,
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
    `- Adapt difficulty to the user's CEFR level (${cefrLabel}).`,
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
