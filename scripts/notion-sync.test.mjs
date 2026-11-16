import { test } from "node:test";
import assert from "node:assert/strict";
import { sinceFrom, toRecord } from "./notion-sync.mjs";

test("an issue maps to an open issue record with its repo", () => {
  const r = toRecord({ number: 7, title: "x", state: "open", labels: [{ name: "a" }], assignees: [{ login: "u" }], html_url: "h", updated_at: "t" }, "Org/repo");
  assert.deepEqual(r, { ref: "Org/repo#7", repo: "repo", title: "x", kind: "issue", state: "open", labels: ["a"], assignees: "u", url: "h", updated: "t" });
});

test("pull requests are not mirrored", () => {
  const base = { number: 1, title: "t", html_url: "h", updated_at: "t", state: "open" };
  assert.equal(toRecord({ ...base, pull_request: {} }, "o/r"), null);
  assert.equal(toRecord({ ...base, state: "closed", pull_request: { merged_at: "x" } }, "o/r"), null);
});

test("the look-back window is hours, all, or an error", () => {
  assert.equal(sinceFrom("all"), null);
  assert.equal(sinceFrom("2", Date.UTC(2026, 0, 1, 12)), "2026-01-01T10:00:00.000Z");
  assert.throws(() => sinceFrom("x"));
});
