import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  buildSystemPrompt,
  sanitizeContextPayload,
} from "./prompt.ts";

// ── sanitizeContextPayload ──

Deno.test("sanitizeContextPayload returns undefined for null input", () => {
  assertEquals(sanitizeContextPayload(null), undefined);
});

Deno.test("sanitizeContextPayload returns undefined for empty string", () => {
  assertEquals(sanitizeContextPayload(""), undefined);
});

Deno.test("sanitizeContextPayload truncates to 500 chars", () => {
  const long = "a".repeat(600);
  const result = sanitizeContextPayload(long)!;
  assertEquals(result.length, 500);
});

Deno.test("sanitizeContextPayload strips control characters but keeps newlines", () => {
  const input = "hello\x00world\nline2\x01end";
  const result = sanitizeContextPayload(input)!;
  assertEquals(result, "helloworld\nline2end");
});

Deno.test("sanitizeContextPayload escapes markdown section markers", () => {
  const input = "## Injected heading\n---\nnormal text";
  const result = sanitizeContextPayload(input)!;
  assertEquals(result.includes("\\## Injected heading"), true);
  assertEquals(result.includes("\\---"), true);
});

// ── buildSystemPrompt ──

Deno.test("buildSystemPrompt includes user nickname", () => {
  const prompt = buildSystemPrompt({ nickname: "Daulet", cefr_level: 3 });
  assertEquals(prompt.includes("Daulet"), true);
});

Deno.test("buildSystemPrompt maps cefr_level to label", () => {
  const prompt = buildSystemPrompt({ cefr_level: 4 });
  assertEquals(prompt.includes("B2"), true);
});

Deno.test("buildSystemPrompt defaults to beginner for null level", () => {
  const prompt = buildSystemPrompt({ cefr_level: null });
  assertEquals(prompt.includes("beginner"), true);
});

Deno.test("buildSystemPrompt includes context when provided", () => {
  const prompt = buildSystemPrompt({ cefr_level: 1 }, "quiz screen");
  assertEquals(prompt.includes("Current Context"), true);
  assertEquals(prompt.includes("quiz screen"), true);
});

Deno.test("buildSystemPrompt omits context section when no context", () => {
  const prompt = buildSystemPrompt({ cefr_level: 1 });
  assertEquals(prompt.includes("Current Context"), false);
});
