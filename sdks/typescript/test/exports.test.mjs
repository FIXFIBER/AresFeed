import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

test("all declared ESM and CommonJS entry points are importable", async () => {
  const esm = await import("@AresFeed/sdk");
  const require = createRequire(import.meta.url);
  const commonjs = require("@AresFeed/sdk");

  assert.equal(typeof esm.AresFeedClient, "function");
  assert.equal(typeof esm.default, "function");
  assert.equal(typeof commonjs.AresFeedClient, "function");
  assert.equal(typeof commonjs.default, "function");
});
