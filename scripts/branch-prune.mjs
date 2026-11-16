// Weekly prune: every repo of the organization keeps `main`, `develop` and the branches still in use
// (docs/plan-ci-y-visibilidad.md, ADR 0009). Private repos on the Free plan cannot switch on
// "delete branch on merge" safely, so this job removes what a merge left behind.
//
// A branch is removed only when a pull request from it is MERGED and the branch still points at the
// commit that pull request merged. Anything else is reported and left alone: a branch with commits
// after the merge, a closed pull request, an open one, or no pull request at all.
//
// Env:
//   GH_PRUNE_TOKEN   Actions secret with write access to the org's repos. Without it nothing is deleted.
//   GH_READ_TOKEN    read-only token for private repos, used for the report when there is no prune token
//   GITHUB_TOKEN     fallback: public repos only
//   PRUNE_ORG        organization login (default: owner of GITHUB_REPOSITORY)
//   PRUNE_DRY_RUN    "true" reports and deletes nothing
//   PRUNE_PROTECTED  comma-separated branch names never touched (default: main,develop)

const GITHUB = "https://api.github.com";

/** What to do with one branch, given the pull requests opened from it (REST "list pull requests" items). */
export function decide(branch, pulls, protectedNames) {
  if (protectedNames.includes(branch.name)) return { action: "keep", reason: "protected" };
  if (pulls.length === 0) return { action: "report", reason: "no pull request" };
  if (pulls.some((pull) => pull.state === "open")) return { action: "keep", reason: "open pull request" };
  const merged = pulls.filter((pull) => pull.merged_at);
  if (merged.length === 0) return { action: "report", reason: "pull request closed without merge" };
  if (merged.some((pull) => pull.head.sha === branch.commit.sha)) return { action: "delete", reason: "merged at the same commit" };
  return { action: "report", reason: "commits after the merge" };
}

/** A branch name as URL path segments: each one encoded, so `#`, `?` or `%` in a name cannot change the request. */
export function refPath(name) {
  return name.split("/").map(encodeURIComponent).join("/");
}

async function github(fetchImpl, token, method, path) {
  const out = [];
  let url = `${GITHUB}${path}`;
  while (url) {
    const response = await fetchImpl(url, {
      method,
      headers: { Authorization: `Bearer ${token}`, Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28" },
    });
    if (!response.ok) throw new Error(`GitHub ${method} ${url.replace(GITHUB, "")} failed with HTTP ${response.status}`);
    if (method !== "GET") return out;
    out.push(...(await response.json()));
    const next = /<([^>]+)>;\s*rel="next"/.exec(response.headers.get("link") ?? "");
    url = next ? next[1] : null;
  }
  return out;
}

export async function main(env, fetchImpl, log) {
  const pruneToken = env.GH_PRUNE_TOKEN?.trim();
  const token = pruneToken || env.GH_READ_TOKEN?.trim() || env.GITHUB_TOKEN;
  const org = env.PRUNE_ORG || (env.GITHUB_REPOSITORY ?? "").split("/")[0];
  if (!token || !org) throw new Error("a GitHub token and an organization are required");
  const dryRun = env.PRUNE_DRY_RUN === "true" || !pruneToken;
  if (!pruneToken) log("branch-prune: GH_PRUNE_TOKEN is not set, reporting only");
  const protectedNames = (env.PRUNE_PROTECTED || "main,develop").split(",").map((name) => name.trim()).filter(Boolean);

  const repos = (await github(fetchImpl, token, "GET", `/orgs/${org}/repos?per_page=100&type=all`)).filter((repo) => !repo.archived);
  const totals = { deleted: 0, reported: 0 };
  for (const repo of repos) {
    const branches = await github(fetchImpl, token, "GET", `/repos/${repo.full_name}/branches?per_page=100`);
    for (const branch of branches) {
      if (protectedNames.includes(branch.name)) continue;
      const head = encodeURIComponent(`${org}:${branch.name}`);
      const pulls = await github(fetchImpl, token, "GET", `/repos/${repo.full_name}/pulls?state=all&per_page=100&head=${head}`);
      const verdict = decide(branch, pulls, protectedNames);
      if (verdict.action === "delete") {
        if (!dryRun) await github(fetchImpl, token, "DELETE", `/repos/${repo.full_name}/git/refs/heads/${refPath(branch.name)}`);
        totals.deleted += 1;
        log(`branch-prune: ${dryRun ? "would delete" : "deleted"} ${repo.name} ${branch.name}`);
      } else if (verdict.action === "report") {
        totals.reported += 1;
        log(`branch-prune: left ${repo.name} ${branch.name} (${verdict.reason})`);
      }
    }
  }
  log(`branch-prune: ${totals.deleted} ${dryRun ? "to delete" : "deleted"}, ${totals.reported} left for a person, ${repos.length} repos`);
  return 0;
}

if (process.argv[1]?.endsWith("branch-prune.mjs")) {
  main(process.env, fetch, console.log)
    .then((code) => process.exit(code))
    .catch((error) => {
      console.error(`branch-prune: ${error.message}`);
      process.exit(1);
    });
}
