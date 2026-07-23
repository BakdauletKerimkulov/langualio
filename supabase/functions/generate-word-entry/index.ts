import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { CLAUDE_API_URL, CLAUDE_MODEL } from "../_shared/constants.ts";
import { handleCors } from "../_shared/cors.ts";
import { verifyAuth, type AuthResult } from "../_shared/auth.ts";
import { jsonResponse } from "../_shared/response.ts";
import { requireEnv } from "../_shared/env.ts";

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
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // 1. Verify auth
    const authResult = await verifyAuth(req);
    if (authResult instanceof Response) return authResult;
    const { user, supabase } = authResult as AuthResult;

    // 2. Admin-only gate (only admins can generate word entries)
    const userRole = user.app_metadata?.role;
    if (userRole !== "admin") {
      return jsonResponse({ error: "Forbidden: admin only" }, 403);
    }

    // 3. Atomic quota check (consume before Claude call, prevents race conditions)
    const { data: quotaGranted, error: quotaError } = await supabase.rpc(
      "try_consume_quota",
      {
        p_user_id: user.id,
        p_kind: "generation",
        p_limit: DAILY_GENERATION_LIMIT,
      }
    );

    if (quotaError) {
      console.error("Quota RPC error:", quotaError);
      return jsonResponse({ error: "Internal server error" }, 500);
    }

    if (!quotaGranted) {
      return jsonResponse(
        {
          error: "Daily generation limit reached",
          remaining: 0,
          limit: DAILY_GENERATION_LIMIT,
        },
        429
      );
    }

    // 4. Parse and validate request
    const { word } = await req.json();
    if (!word || typeof word !== "string" || word.trim().length === 0) {
      return jsonResponse({ error: "Word is required" }, 400);
    }

    // 5. Call Claude API
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

    // 6. Extract text from Claude response
    const claudeData = await claudeResponse.json();
    const textContent = claudeData.content?.find(
      (block: { type: string }) => block.type === "text"
    );

    if (!textContent?.text) {
      console.error("No text in Claude response:", JSON.stringify(claudeData));
      return jsonResponse({ error: "AI returned empty response" }, 502);
    }

    // 7. Parse JSON from response
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

    // 8. Validate meanings array
    if (
      !Array.isArray(wordEntry.meanings) ||
      wordEntry.meanings.length === 0
    ) {
      console.error(
        "AI response missing meanings array:",
        JSON.stringify(wordEntry)
      );
      return jsonResponse(
        { error: "AI returned entry without meanings" },
        502
      );
    }

    // 9. Return the generated entry (quota already consumed atomically in step 3)
    return jsonResponse({ data: wordEntry }, 200);
  } catch (error) {
    console.error("Edge function error:", error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});
