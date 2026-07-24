import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { handleCors, corsHeaders } from "./cors.ts";

Deno.test("handleCors returns Response for OPTIONS request", () => {
  const req = new Request("https://example.com", { method: "OPTIONS" });
  const result = handleCors(req);
  assertEquals(result instanceof Response, true);
  assertEquals(result!.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("handleCors returns null for non-OPTIONS request", () => {
  const req = new Request("https://example.com", { method: "POST" });
  const result = handleCors(req);
  assertEquals(result, null);
});

Deno.test("corsHeaders includes required headers", () => {
  assertEquals(corsHeaders["Access-Control-Allow-Origin"], "*");
  assertEquals(
    corsHeaders["Access-Control-Allow-Headers"]?.includes("authorization"),
    true
  );
});
