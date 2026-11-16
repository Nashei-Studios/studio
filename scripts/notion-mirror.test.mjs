import { test } from "node:test";
import assert from "node:assert/strict";
import { errorDetail, upsert } from "./notion-mirror.mjs";

const env = { NOTION_TOKEN: "secret-token-value", NOTION_DATABASE_ID: "db" };
const record = {
  ref: "owner/repo#1",
  title: "t",
  kind: "pull request",
  state: "open",
  labels: [],
  assignees: "",
  url: "https://example.com",
  updated: "2026-11-16T00:00:00Z",
};

function reply(status, body) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => {
      if (body === undefined) throw new SyntaxError("not json");
      return body;
    },
  };
}

test("errorDetail carries Notion's code and message", async () => {
  const detail = await errorDetail(reply(403, { code: "restricted_resource", message: "Insufficient permissions." }));
  assert.equal(detail, " (restricted_resource: Insufficient permissions.)");
});

test("errorDetail is empty when the body is not Notion's error JSON", async () => {
  assert.equal(await errorDetail(reply(502, undefined)), "");
  assert.equal(await errorDetail(reply(500, { unexpected: true })), "");
});

test("a rejected page creation says why and never leaks the token", async () => {
  const fetchImpl = async (url) =>
    url.endsWith("/query")
      ? reply(200, { results: [] })
      : reply(403, { code: "restricted_resource", message: "Insufficient permissions." });
  await assert.rejects(
    () => upsert(fetchImpl, env, record),
    (error) => {
      assert.match(error.message, /POST \/pages failed with HTTP 403 \(restricted_resource: Insufficient permissions\.\)/);
      assert.ok(!error.message.includes(env.NOTION_TOKEN));
      return true;
    },
  );
});
