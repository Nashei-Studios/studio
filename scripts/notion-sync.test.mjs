import { test } from "node:test";
import assert from "node:assert/strict";
import { prunePullRequests, sinceFrom, toRecord } from "./notion-sync.mjs";

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

test("pull request rows are archived page by page until none is left", async () => {
  const env = { NOTION_TOKEN: "secret-token-value", NOTION_DATABASE_ID: "db" };
  const pages = [[{ id: "a" }, { id: "b" }], [{ id: "c" }], []];
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, method: init.method, body: JSON.parse(init.body) });
    const results = url.endsWith("/query") ? pages.shift() : undefined;
    return { ok: true, status: 200, json: async () => (results ? { results } : {}) };
  };
  const logged = [];
  const archived = await prunePullRequests(fetchImpl, env, (line) => logged.push(line), async () => {});
  assert.equal(archived, 3);
  const queries = calls.filter((call) => call.url.endsWith("/query"));
  assert.equal(queries.length, 3);
  assert.deepEqual(queries[0].body.filter, { property: "Kind", select: { equals: "pull request" } });
  const patches = calls.filter((call) => call.method === "PATCH");
  assert.deepEqual(patches.map((call) => call.url.split("/pages/")[1]), ["a", "b", "c"]);
  assert.ok(patches.every((call) => call.body.archived === true));
  assert.deepEqual(logged, ["notion-sync: archived 3 pull request rows"]);
});

test("nothing is archived or logged when there are no pull request rows", async () => {
  const env = { NOTION_TOKEN: "t", NOTION_DATABASE_ID: "db" };
  const fetchImpl = async () => ({ ok: true, status: 200, json: async () => ({ results: [] }) });
  const logged = [];
  assert.equal(await prunePullRequests(fetchImpl, env, (line) => logged.push(line), async () => {}), 0);
  assert.deepEqual(logged, []);
});
