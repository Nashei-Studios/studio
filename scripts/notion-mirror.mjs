// One-way mirror of GitHub issues into a Notion database (ADR 0065, narrowed by ADR 0008: pull requests are not mirrored).
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

/** Maps a webhook payload to the flat record we store, or null for anything that is not an issue (pull requests are not mirrored, ADR 0008). */
export function toRecord(payload, repository) {
  if (payload.pull_request) return null;
  const item = payload.issue;
  if (!item) return null;
  return {
    ref: `${repository}#${item.number}`,
    title: String(item.title ?? "").slice(0, 200),
    kind: "issue",
    state: item.state === "closed" ? "closed" : "open",
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
    throw new Error(`Notion ${method} ${path} failed with HTTP ${response.status}${await errorDetail(response)}`);
  }
  return response.json();
}

/** Notion's own `code` and `message` for a rejected call, or "" when the body is not its error JSON. Never echoes the request. */
export async function errorDetail(response) {
  try {
    const body = await response.json();
    const parts = [body?.code, body?.message].filter((part) => typeof part === "string" && part.length > 0);
    return parts.length > 0 ? ` (${parts.join(": ").slice(0, 400)})` : "";
  } catch {
    return "";
  }
}

/** Creates the page for `record`, or updates the one whose Ref matches. `extend` may add properties. Returns "created" or "updated". */
export async function upsert(fetchImpl, env, record, extend = (properties) => properties) {
  const token = env.NOTION_TOKEN;
  const databaseId = env.NOTION_DATABASE_ID;
  const found = await notion(fetchImpl, token, "POST", `/databases/${databaseId}/query`, {
    filter: { property: "Ref", rich_text: { equals: record.ref } },
    page_size: 1,
  });
  const properties = extend(toProperties(record));
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
    log("notion-mirror: event is not an issue, nothing to do");
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
