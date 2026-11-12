// One-way mirror of GitHub issues and pull requests into a Notion database (ADR 0065).
// GitHub stays the source of truth: a Notion edit never flows back and the next event overwrites it.
//
// Inactive by design: without NOTION_TOKEN or NOTION_DATABASE_ID it prints one line and exits 0.
// Env (all from the workflow, never typed here):
//   NOTION_TOKEN        Actions secret, an internal Notion integration token
//   NOTION_DATABASE_ID  Actions variable, the target database id
//   GITHUB_EVENT_PATH   set by Actions, the event payload
//   GITHUB_REPOSITORY   set by Actions, "owner/name"
//
// The database must have these properties (names are a contract, see docs/notion-mirror.md):
//   Name (title), Ref (rich text, "owner/name#12"), Kind (select), State (select),
//   Labels (multi-select), Assignees (rich text), URL (url), Updated (date)

const NOTION_VERSION = "2022-06-28";
const API = "https://api.notion.com/v1";

/** Maps a webhook payload to the flat record we store, or null when the event has no issue or PR. */
export function toRecord(payload, repository) {
  const item = payload.pull_request ?? payload.issue;
  if (!item) return null;
  const isPr = Boolean(payload.pull_request);
  const merged = isPr && item.merged === true;
  let state = item.state === "closed" ? "closed" : "open";
  if (merged) state = "merged";
  else if (isPr && item.draft === true && state === "open") state = "draft";
  return {
    ref: `${repository}#${item.number}`,
    title: String(item.title ?? "").slice(0, 200),
    kind: isPr ? "pull request" : "issue",
    state,
    labels: (item.labels ?? []).map((label) => String(label.name).slice(0, 100)),
    assignees: (item.assignees ?? []).map((user) => user.login).join(", "),
    url: item.html_url,
    updated: item.updated_at,
  };
}

/** Notion page properties for a record. */
export function toProperties(record) {
  return {
    Name: { title: [{ text: { content: record.title || "(untitled)" } }] },
    Ref: { rich_text: [{ text: { content: record.ref } }] },
    Kind: { select: { name: record.kind } },
    State: { select: { name: record.state } },
    Labels: { multi_select: record.labels.map((name) => ({ name: name.replaceAll(",", " ") })) },
    Assignees: { rich_text: [{ text: { content: record.assignees } }] },
    URL: { url: record.url },
    Updated: { date: { start: record.updated } },
  };
}

/** The decision to run: both values present and non-blank. */
export function isConfigured(env) {
  return Boolean(env.NOTION_TOKEN?.trim()) && Boolean(env.NOTION_DATABASE_ID?.trim());
}

async function notion(fetchImpl, token, method, path, body) {
  const response = await fetchImpl(`${API}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Notion-Version": NOTION_VERSION,
      "Content-Type": "application/json",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`Notion ${method} ${path} failed with HTTP ${response.status}`);
  }
  return response.json();
}

/** Creates the page for `record`, or updates the one whose Ref matches. Returns "created" or "updated". */
export async function upsert(fetchImpl, env, record) {
  const token = env.NOTION_TOKEN;
  const databaseId = env.NOTION_DATABASE_ID;
  const found = await notion(fetchImpl, token, "POST", `/databases/${databaseId}/query`, {
    filter: { property: "Ref", rich_text: { equals: record.ref } },
    page_size: 1,
  });
  const properties = toProperties(record);
  if (found.results.length > 0) {
    await notion(fetchImpl, token, "PATCH", `/pages/${found.results[0].id}`, { properties });
    return "updated";
  }
  await notion(fetchImpl, token, "POST", "/pages", {
    parent: { database_id: databaseId },
    properties,
  });
  return "created";
}

export async function main(env, readPayload, fetchImpl, log) {
  if (!isConfigured(env)) {
    log("notion-mirror: NOTION_TOKEN or NOTION_DATABASE_ID is not set, mirror is inactive");
    return 0;
  }
  const record = toRecord(readPayload(), env.GITHUB_REPOSITORY ?? "unknown/unknown");
  if (record === null) {
    log("notion-mirror: event has no issue or pull request, nothing to do");
    return 0;
  }
  const result = await upsert(fetchImpl, env, record);
  log(`notion-mirror: ${result} ${record.ref}`);
  return 0;
}

if (import.meta.url === `file://${process.argv[1].replaceAll("\\", "/")}` || process.argv[1]?.endsWith("notion-mirror.mjs")) {
  const { readFileSync } = await import("node:fs");
  main(process.env, () => JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, "utf8")), fetch, console.log)
    .then((code) => process.exit(code))
    .catch((error) => {
      console.error(`notion-mirror: ${error.message}`);
      process.exit(1);
    });
}
