// Central mirror: every issue and pull request of every repo of the organization into one Notion
// database. Runs on a schedule in this repo, so a new repo is covered with no setup of its own.
//
// Env:
//   NOTION_TOKEN        Actions secret, internal Notion integration token
//   NOTION_DATABASE_ID  Actions variable, the target database id
//   GH_READ_TOKEN       Actions secret, read-only token for the org's private repos. Without it only
//                       public repos are read (the default GITHUB_TOKEN cannot see other private repos).
//   GITHUB_TOKEN        fallback when GH_READ_TOKEN is absent
//   SYNC_ORG            organization login (default: owner of GITHUB_REPOSITORY)
//   SYNC_SINCE_HOURS    look-back window (default 3). "all" syncs the full history.
//
// GitHub is the source of truth: Notion edits are overwritten on the next change.
import { isConfigured, toProperties, upsert } from "./notion-mirror.mjs";

const GITHUB = "https://api.github.com";

/** Maps one item of the REST "list repository issues" endpoint to the mirror record. */
export function toRecord(item, repository) {
  const isPr = Boolean(item.pull_request);
  const merged = isPr && Boolean(item.pull_request.merged_at);
  let state = item.state === "closed" ? "closed" : "open";
  if (merged) state = "merged";
  else if (isPr && item.draft === true && state === "open") state = "draft";
  return {
    ref: `${repository}#${item.number}`,
    repo: repository.split("/")[1],
    title: String(item.title ?? "").slice(0, 200),
    kind: isPr ? "pull request" : "issue",
    state,
    labels: (item.labels ?? []).map((label) => String(label.name).slice(0, 100)),
    assignees: (item.assignees ?? []).map((user) => user.login).join(", "),
    url: item.html_url,
    updated: item.updated_at,
  };
}

/** ISO timestamp for the look-back window, or null for the full history. */
export function sinceFrom(value, now = Date.now()) {
  if (value === "all") return null;
  const hours = Number(value ?? 3);
  if (!Number.isFinite(hours) || hours <= 0) throw new Error(`SYNC_SINCE_HOURS must be a positive number or "all", got ${value}`);
  return new Date(now - hours * 3600 * 1000).toISOString();
}

async function github(fetchImpl, token, path) {
  const out = [];
  let url = `${GITHUB}${path}`;
  while (url) {
    const response = await fetchImpl(url, {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28" },
    });
    if (!response.ok) throw new Error(`GitHub GET ${url.replace(GITHUB, "")} failed with HTTP ${response.status}`);
    out.push(...(await response.json()));
    const next = /<([^>]+)>;\s*rel="next"/.exec(response.headers.get("link") ?? "");
    url = next ? next[1] : null;
  }
  return out;
}

export async function main(env, fetchImpl, log) {
  if (!isConfigured(env)) {
    log("notion-sync: NOTION_TOKEN or NOTION_DATABASE_ID is not set, sync is inactive");
    return 0;
  }
  const token = env.GH_READ_TOKEN?.trim() || env.GITHUB_TOKEN;
  const org = env.SYNC_ORG || (env.GITHUB_REPOSITORY ?? "").split("/")[0];
  if (!token || !org) throw new Error("a GitHub token and an organization are required");
  if (!env.GH_READ_TOKEN?.trim()) log("notion-sync: GH_READ_TOKEN is not set, only public repos are read");

  const since = sinceFrom(env.SYNC_SINCE_HOURS);
  const repos = (await github(fetchImpl, token, `/orgs/${org}/repos?per_page=100&type=all`)).filter((r) => !r.archived && r.has_issues);
  let written = 0;
  for (const repo of repos) {
    const query = `state=all&per_page=100&sort=updated&direction=asc${since ? `&since=${since}` : ""}`;
    const items = await github(fetchImpl, token, `/repos/${repo.full_name}/issues?${query}`);
    for (const item of items) {
      const record = toRecord(item, repo.full_name);
      // The Repo column is extra to the per-repo mirror contract; it powers the "by repo" views.
      const withRepo = { ...record };
      await upsert(fetchImpl, env, withRepo, (properties) => ({ ...properties, Repo: { select: { name: record.repo } } }));
      written += 1;
      // Notion allows about three requests per second; one upsert is two.
      await new Promise((resolve) => setTimeout(resolve, 700));
    }
    if (items.length) log(`notion-sync: ${repo.name} ${items.length}`);
  }
  log(`notion-sync: ${written} records from ${repos.length} repos (since ${since ?? "the beginning"})`);
  return 0;
}

export { toProperties };

if (process.argv[1]?.endsWith("notion-sync.mjs")) {
  main(process.env, fetch, console.log)
    .then((code) => process.exit(code))
    .catch((error) => {
      console.error(`notion-sync: ${error.message}`);
      process.exit(1);
    });
}
