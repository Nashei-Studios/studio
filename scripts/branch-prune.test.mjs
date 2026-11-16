import { test } from "node:test";
import assert from "node:assert/strict";
import { decide, main } from "./branch-prune.mjs";

const keep = ["main", "develop"];
const branch = (name, sha) => ({ name, commit: { sha } });
const pull = (state, sha, mergedAt = null) => ({ state, merged_at: mergedAt, head: { sha } });

test("main and develop are never touched", () => {
  assert.equal(decide(branch("develop", "a"), [pull("closed", "a", "t")], keep).action, "keep");
});

test("a branch merged at the same commit is deleted", () => {
  assert.equal(decide(branch("feat/x", "a"), [pull("closed", "a", "t")], keep).action, "delete");
});

test("commits after the merge, a closed pull request and no pull request are left for a person", () => {
  assert.equal(decide(branch("feat/x", "b"), [pull("closed", "a", "t")], keep).reason, "commits after the merge");
  assert.equal(decide(branch("feat/x", "a"), [pull("closed", "a")], keep).reason, "pull request closed without merge");
  assert.equal(decide(branch("feat/x", "a"), [], keep).reason, "no pull request");
});

test("an open pull request keeps the branch even if an older one was merged", () => {
  assert.equal(decide(branch("feat/x", "a"), [pull("closed", "a", "t"), pull("open", "a")], keep).action, "keep");
});

function fakeGithub(calls) {
  return async (url, init) => {
    calls.push(`${init.method} ${url.replace("https://api.github.com", "")}`);
    let body = [];
    if (url.includes("/orgs/")) body = [{ full_name: "o/live", name: "live", archived: false }, { full_name: "o/old", name: "old", archived: true }];
    else if (url.includes("/branches")) body = [branch("main", "m"), branch("feat/done", "a"), branch("feat/loose", "z")];
    else if (url.includes("feat%2Fdone")) body = [pull("closed", "a", "t")];
    return { ok: true, status: 200, json: async () => body, headers: { get: () => null } };
  };
}

test("with the prune token only the merged branch of a live repo is deleted", async () => {
  const calls = [];
  const lines = [];
  await main({ GH_PRUNE_TOKEN: "write-token-value", PRUNE_ORG: "o" }, fakeGithub(calls), (line) => lines.push(line));
  assert.deepEqual(calls.filter((call) => call.startsWith("DELETE")), ["DELETE /repos/o/live/git/refs/heads/feat/done"]);
  assert.ok(!calls.some((call) => call.includes("/o/old/")));
  assert.ok(lines.some((line) => line.includes("left live feat/loose (no pull request)")));
  assert.ok(!lines.join("\n").includes("write-token-value"));
});

test("without the prune token nothing is deleted", async () => {
  const calls = [];
  const lines = [];
  await main({ GH_READ_TOKEN: "read-token-value", PRUNE_ORG: "o" }, fakeGithub(calls), (line) => lines.push(line));
  assert.equal(calls.filter((call) => call.startsWith("DELETE")).length, 0);
  assert.ok(lines.some((line) => line.includes("would delete live feat/done")));
});
