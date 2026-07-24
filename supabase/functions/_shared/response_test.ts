import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { jsonResponse } from "./response.ts";

Deno.test("jsonResponse returns correct status code", () => {
  const resp = jsonResponse({ error: "not found" }, 404);
  assertEquals(resp.status, 404);
});

Deno.test("jsonResponse returns JSON content type", () => {
  const resp = jsonResponse({ ok: true }, 200);
  assertEquals(resp.headers.get("Content-Type"), "application/json");
});

Deno.test("jsonResponse includes CORS header", () => {
  const resp = jsonResponse({ ok: true }, 200);
  assertEquals(resp.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("jsonResponse body is valid JSON", async () => {
  const body = { text: "hello", count: 42 };
  const resp = jsonResponse(body, 200);
  const parsed = await resp.json();
  assertEquals(parsed.text, "hello");
  assertEquals(parsed.count, 42);
});
