import { assertEquals, assertThrows } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { requireEnv } from "./env.ts";

Deno.test("requireEnv returns value when env var is set", () => {
  Deno.env.set("TEST_REQUIRE_ENV", "hello");
  const result = requireEnv("TEST_REQUIRE_ENV");
  assertEquals(result, "hello");
  Deno.env.delete("TEST_REQUIRE_ENV");
});

Deno.test("requireEnv throws when env var is missing", () => {
  Deno.env.delete("TEST_MISSING_VAR");
  assertThrows(
    () => requireEnv("TEST_MISSING_VAR"),
    Error,
    "Missing required environment variable: TEST_MISSING_VAR"
  );
});

Deno.test("requireEnv throws when env var is empty string", () => {
  Deno.env.set("TEST_EMPTY_VAR", "");
  assertThrows(
    () => requireEnv("TEST_EMPTY_VAR"),
    Error,
    "Missing required environment variable: TEST_EMPTY_VAR"
  );
  Deno.env.delete("TEST_EMPTY_VAR");
});
