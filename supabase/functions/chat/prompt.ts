// CEFR level mapping: DB int → human-readable label
const CEFR_LABELS: Record<number, string> = {
  1: "A1",
  2: "A2",
  3: "B1",
  4: "B2",
  5: "C1",
};

/// Sanitize context_payload: truncate, strip control chars, escape delimiters
export function sanitizeContextPayload(
  payload: string | undefined | null
): string | undefined {
  if (!payload || typeof payload !== "string") return undefined;

  let sanitized = payload.slice(0, 500);

  // Strip ASCII control characters (0x00–0x1F) except newline (0x0A) and tab (0x09)
  sanitized = sanitized.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, "");

  // Escape prompt section delimiters
  sanitized = sanitized.replace(/^## /gm, "\\## ");
  sanitized = sanitized.replace(/^---$/gm, "\\---");

  return sanitized;
}

export function buildSystemPrompt(
  profile: Record<string, unknown> | null,
  contextPrompt?: string
): string {
  const cefrLevel = (profile?.cefr_level as number | null) ?? null;
  const cefrLabel = cefrLevel
    ? (CEFR_LABELS[cefrLevel] ?? "beginner")
    : "beginner";

  const lines = [
    'You are an AI English tutor called "AI Tutor" in the Langualio app.',
    "Your role is to help the user learn English in a friendly and encouraging way.",
    "",
    "## User Profile",
    `- Name: ${(profile?.nickname as string) ?? "Learner"}`,
    `- CEFR Level: ${cefrLabel}`,
    `- Level: ${(profile?.level as number) ?? 1}`,
    `- Current XP: ${(profile?.current_xp as number) ?? 0}/${(profile?.target_xp as number) ?? 500}`,
    `- Streak: ${(profile?.streak_days as number) ?? 0} days`,
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
