import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CLAUDE_API_KEY = Deno.env.get("CLAUDE_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CLAUDE_API_URL = "https://api.anthropic.com/v1/messages";
const CLAUDE_MODEL = "claude-sonnet-4-20250514";
const MAX_TOKENS = 2048;
const DAILY_GENERATION_LIMIT = 10;

const SYSTEM_PROMPT = `You are a linguistic expert that generates structured vocabulary entries for an English learning app.

Given an English word, return a JSON object with these exact fields:
- "word": the English word (string)
- "ipa": IPA pronunciation (string, e.g. "/ˌserənˈdɪpəti/")
- "level": CEFR level, one of "a1", "a2", "b1", "b2", "c1", "c2" (string)
- "meanings": array of meaning objects (at least 1, ideally 2-3 if the word has multiple meanings). Each meaning object has:
  - "part_of_speech": one of "noun", "verb", "adjective", "adverb", "pronoun", "preposition", "conjunction", "interjection", "phrase" (string)
  - "translation": Russian translation for this meaning (string)
  - "alternative_translations": array of alternative Russian translations for this meaning (string[])
  - "definition_en": English definition for this meaning (string)
  - "definition_ru": Russian definition for this meaning (string)
  - "example_en": example sentence in English demonstrating this meaning (string)
  - "example_ru": Russian translation of the example sentence (string)
- "tags": array of topic tags like "emotions", "nature", "business" (string[])
- "topic": general topic category (string, e.g. "everyday", "academic", "business")

Include multiple meanings when the word genuinely has distinct senses (e.g. "run" as verb=бежать, noun=пробежка). Do not invent meanings — only include real, common ones.

Return ONLY valid JSON, no markdown fences, no explanation. Just the JSON object.`;

serve(async (req) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, content-type, x-client-info, apikey",
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
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    // 2. Check per-user rate limit (10 generations/day)
    const today = new Date().toISOString().split("T")[0];
    const { data: usageData } = await supabase
      .from("user_daily_usage")
      .select("generation_count")
      .eq("user_id", user.id)
      .eq("date", today)
      .single();

    const currentGenerations = usageData?.generation_count ?? 0;

    if (currentGenerations >= DAILY_GENERATION_LIMIT) {
      return jsonResponse(
        {
          error: "Daily generation limit reached",
          remaining: 0,
          limit: DAILY_GENERATION_LIMIT,
        },
        429
      );
    }

    // 3. Parse and validate request
    const { word } = await req.json();
    if (!word || typeof word !== "string" || word.trim().length === 0) {
      return jsonResponse({ error: "Word is required" }, 400);
    }

    // 4. Call Claude API
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
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: "user",
            content: `Generate a vocabulary entry for the word: "${word.trim()}"`,
          },
        ],
      }),
    });

    if (!claudeResponse.ok) {
      const errorText = await claudeResponse.text();
      console.error("Claude API error:", claudeResponse.status, errorText);
      return jsonResponse({ error: "AI service error" }, 502);
    }

    // 5. Extract text from Claude response
    const claudeData = await claudeResponse.json();
    const textContent = claudeData.content?.find(
      (block: { type: string }) => block.type === "text"
    );

    if (!textContent?.text) {
      console.error("No text in Claude response:", JSON.stringify(claudeData));
      return jsonResponse({ error: "AI returned empty response" }, 502);
    }

    // 6. Parse JSON from response
    let wordEntry: Record<string, unknown>;
    try {
      wordEntry = JSON.parse(textContent.text.trim());
    } catch {
      console.error("Failed to parse AI response as JSON:", textContent.text);
      return jsonResponse(
        { error: "AI returned invalid JSON", raw: textContent.text },
        502
      );
    }

    // 7. Validate meanings array
    if (
      !Array.isArray(wordEntry.meanings) ||
      wordEntry.meanings.length === 0
    ) {
      console.error("AI response missing meanings array:", JSON.stringify(wordEntry));
      return jsonResponse(
        { error: "AI returned entry without meanings" },
        502
      );
    }

    // 8. Increment generation count
    await supabase.from("user_daily_usage").upsert(
      {
        user_id: user.id,
        date: today,
        generation_count: currentGenerations + 1,
      },
      { onConflict: "user_id,date" }
    );

    // 9. Return the generated entry
    return jsonResponse({ data: wordEntry }, 200);
  } catch (error) {
    console.error("Edge function error:", error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

function jsonResponse(
  body: Record<string, unknown>,
  status: number
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
