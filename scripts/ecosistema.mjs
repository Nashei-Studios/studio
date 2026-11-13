// Ecosystem config: single source of ids for Notion, Drive, repos and the Roblox group.
//
// Usage (Node 20+, no dependencies):
//   node scripts/ecosistema.mjs validate            check config/ecosistema.json against its schema
//   node scripts/ecosistema.mjs get <ruta.con.puntos>  print one value (e.g. notion.bases.reuniones.data_source_id)
//   node scripts/ecosistema.mjs responsables <area>...  who must be asked about an item (personas + planificacion)
//   node scripts/ecosistema.mjs lote <items.json>       check a draft batch against the caps
//   node scripts/ecosistema.mjs discover [--write]  look every id up by name (rclone, Notion) and report drift
//
// Exit code: 0 clean, 1 invalid config or drift found, 2 usage error. Discovery of a service that is
// not reachable (no NOTION_TOKEN, no rclone) is reported as "omitido", never as a pass.
import { readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
export const CONFIG_PATH = join(ROOT, "config", "ecosistema.json");
export const SCHEMA_PATH = join(ROOT, "config", "ecosistema.schema.json");

const typeOf = (v) => (v === null ? "null" : Array.isArray(v) ? "array" : Number.isInteger(v) ? "integer" : typeof v);
const matchesType = (v, t) => t === typeOf(v) || (t === "number" && typeof v === "number") || (t === "integer" && Number.isInteger(v));

/** Validates `value` against the JSON Schema subset used by config/ecosistema.schema.json. */
export function validate(value, schema, path = "$") {
  const errors = [];
  const types = schema.type === undefined ? null : [].concat(schema.type);
  if (types && !types.some((t) => matchesType(value, t))) {
    return [`${path}: se esperaba ${types.join(" o ")} y llegó ${typeOf(value)}`];
  }
  if (schema.enum && !schema.enum.includes(value)) errors.push(`${path}: debe ser uno de ${schema.enum.join(", ")}`);
  if (typeof value === "string") {
    if (schema.minLength !== undefined && value.length < schema.minLength) errors.push(`${path}: vacío o muy corto`);
    if (schema.pattern && !new RegExp(schema.pattern).test(value)) errors.push(`${path}: no cumple ${schema.pattern}`);
  }
  if (Array.isArray(value)) {
    if (schema.minItems !== undefined && value.length < schema.minItems) errors.push(`${path}: faltan elementos`);
    if (schema.maxItems !== undefined && value.length > schema.maxItems) errors.push(`${path}: sobran elementos`);
    if (schema.items) value.forEach((item, i) => errors.push(...validate(item, schema.items, `${path}[${i}]`)));
  }
  if (typeOf(value) === "object") {
    for (const key of schema.required ?? []) if (!(key in value)) errors.push(`${path}.${key}: falta`);
    if (schema.minProperties !== undefined && Object.keys(value).length < schema.minProperties) errors.push(`${path}: vacío`);
    for (const [key, sub] of Object.entries(schema.properties ?? {})) {
      if (key in value) errors.push(...validate(value[key], sub, `${path}.${key}`));
    }
    if (schema.additionalProperties && typeof schema.additionalProperties === "object") {
      for (const [key, v] of Object.entries(value)) {
        if (!(key in (schema.properties ?? {}))) errors.push(...validate(v, schema.additionalProperties, `${path}.${key}`));
      }
    }
  }
  return errors;
}

export const loadConfig = () => JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
const loadSchema = () => JSON.parse(readFileSync(SCHEMA_PATH, "utf8"));

/** Returns the value at a dotted path, or undefined. */
export function getPath(config, dotted) {
  return dotted.split(".").reduce((acc, key) => (acc && typeof acc === "object" ? acc[key] : undefined), config);
}

/** Cross-checks that the schema cannot express: unique logins, owned areas that exist, sane caps. */
export function checkInvariantes(config) {
  const errors = [];
  const { personas, planificacion: plan } = config;
  const logins = Object.values(personas).map((p) => p.login.toLowerCase());
  if (new Set(logins).size !== logins.length) errors.push("personas: login repetido");
  for (const [key, p] of Object.entries(personas)) {
    for (const area of p.areas) if (!plan.areas.includes(area)) errors.push(`personas.${key}.areas: "${area}" no está en planificacion.areas`);
    if (p.estado === "por-definir" && (p.areas.length || p.foco.length)) errors.push(`personas.${key}: con estado por-definir no puede traer areas ni foco`);
    if (p.estado === "definido" && !p.areas.length) errors.push(`personas.${key}: definida pero sin areas`);
  }
  const [min, max] = plan.preguntas_por_responsable;
  if (min < 1 || min > max) errors.push("planificacion.preguntas_por_responsable: rango invalido");
  if (plan.tope_tareas_detalladas > plan.tope_issues_por_lote) errors.push("planificacion: tope_tareas_detalladas supera tope_issues_por_lote");
  if (plan.tope_sub_issues_por_padre > 100) errors.push("planificacion: GitHub admite 100 sub-issues por padre");
  return errors;
}

/**
 * Who must be asked about an item that touches `areas`. Never assumes a role:
 * an area nobody covers is returned in `sinResponsable` and the question goes to the whole team.
 */
export function responsables(config, areas) {
  const porArea = {};
  const sinResponsable = [];
  for (const area of areas) {
    const owners = Object.values(config.personas).filter((p) => p.estado === "definido" && p.areas.includes(area)).map((p) => p.login);
    if (owners.length) porArea[area] = owners; else sinResponsable.push(area);
  }
  const preguntar = [...new Set(Object.values(porArea).flat())];
  return { porArea, sinResponsable, preguntar, cruzaAreas: preguntar.length > 1 };
}

/** Checks a draft batch against the caps. Items: { id, nivel: "epica"|"historia"|"tarea", padre?: string }. */
export function checkLote(config, items) {
  const { tope_issues_por_lote: total, tope_tareas_detalladas: tareas, tope_sub_issues_por_padre: porPadre } = config.planificacion;
  const errors = [];
  if (items.length > total) errors.push(`el lote trae ${items.length} issues y el tope es ${total}`);
  const nTareas = items.filter((i) => i.nivel === "tarea").length;
  if (nTareas > tareas) errors.push(`el lote trae ${nTareas} tareas detalladas y el tope es ${tareas}`);
  const hijos = new Map();
  for (const i of items) if (i.padre) hijos.set(i.padre, (hijos.get(i.padre) ?? 0) + 1);
  for (const [padre, n] of hijos) if (n > porPadre) errors.push(`${padre} tiene ${n} sub-issues y el tope es ${porPadre}`);
  return errors;
}

/** Compares configured Drive folders with an `rclone lsjson --dirs-only` listing. */
export function diffDrive(config, listing) {
  const byName = new Map(listing.map((d) => [d.Name, d.ID]));
  const findings = [];
  for (const [key, folder] of Object.entries(config.drive.carpetas)) {
    const id = byName.get(folder.nombre);
    if (!id) findings.push({ key: `drive.carpetas.${key}`, kind: "missing", detail: `no existe la carpeta "${folder.nombre}"` });
    else if (id !== folder.id) findings.push({ key: `drive.carpetas.${key}`, kind: "changed", detail: `id ${folder.id} -> ${id}`, path: `drive.carpetas.${key}.id`, value: id });
  }
  return findings;
}

/** Checks drive.raiz: its url must end in its id, and listing it must work and show the configured folders. */
export function diffDriveRoot(config, run) {
  const { raiz } = config.drive;
  const findings = [];
  if (!raiz.url.endsWith(`/${raiz.id}`)) findings.push({ key: "drive.raiz", kind: "changed", detail: "la url no termina en el id" });
  if (!run.ok) findings.push({ key: "drive.raiz", kind: "missing", detail: `rclone no puede listar la carpeta ${raiz.id}: ${run.error}` });
  else if (!run.names.includes(Object.values(config.drive.carpetas)[0].nombre)) findings.push({ key: "drive.raiz", kind: "changed", detail: "esa carpeta no contiene las subcarpetas configuradas" });
  return findings;
}

/** Compares configured Notion bases with search results of the 2025-09-03 API (data_source objects). */
export function diffNotion(config, dataSources) {
  const titleOf = (o) => (o.title ?? []).map((t) => t.plain_text).join("");
  const findings = [];
  for (const [key, base] of Object.entries(config.notion.bases)) {
    const names = [base.nombre, ...(base.alias ?? [])];
    const hit = dataSources.find((o) => names.includes(titleOf(o)));
    if (!hit) {
      findings.push({ key: `notion.bases.${key}`, kind: "missing", detail: `ninguna base se llama ${names.map((n) => `"${n}"`).join(" ni ")}` });
      continue;
    }
    if (hit.id !== base.data_source_id) findings.push({ key: `notion.bases.${key}`, kind: "changed", detail: `data_source_id ${base.data_source_id} -> ${hit.id}`, path: `notion.bases.${key}.data_source_id`, value: hit.id });
    const dbId = hit.parent?.database_id;
    if (dbId && dbId !== base.database_id) findings.push({ key: `notion.bases.${key}`, kind: "changed", detail: `database_id ${base.database_id} -> ${dbId}`, path: `notion.bases.${key}.database_id`, value: dbId });
  }
  return findings;
}

function setPath(obj, dotted, value) {
  const keys = dotted.split(".");
  const last = keys.pop();
  const target = keys.reduce((acc, k) => acc[k], obj);
  target[last] = value;
}

function discoverDrive(config) {
  const run = spawnSync("rclone", ["lsjson", `${config.drive.remoto}:`, "--dirs-only"], { encoding: "utf8", windowsHide: true });
  if (run.error || run.status !== 0) return { skipped: "rclone no responde (revisa `rclone lsf " + config.drive.remoto + ":`)" };
  // The root is listed by its configured id, whatever root_folder_id the person's remote has.
  const root = spawnSync("rclone", ["lsjson", `${config.drive.remoto},root_folder_id=${config.drive.raiz.id}:`, "--dirs-only"], { encoding: "utf8", windowsHide: true });
  const rootRun = root.status === 0 ? { ok: true, names: JSON.parse(root.stdout).map((d) => d.Name) } : { ok: false, error: (root.stderr || "").trim().split(/\r?\n/).pop() };
  return { findings: [...diffDriveRoot(config, rootRun), ...diffDrive(config, JSON.parse(run.stdout))] };
}

async function discoverNotion(config) {
  const token = process.env.NOTION_TOKEN;
  if (!token) return { skipped: "sin NOTION_TOKEN; la skill reunion lo resuelve con el MCP notion-studio" };
  const results = [];
  for (const base of Object.values(config.notion.bases)) {
    for (const name of [base.nombre, ...(base.alias ?? [])]) {
      const res = await fetch("https://api.notion.com/v1/search", {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Notion-Version": "2025-09-03", "Content-Type": "application/json" },
        body: JSON.stringify({ query: name, filter: { property: "object", value: "data_source" }, page_size: 25 }),
      });
      if (!res.ok) return { skipped: `Notion respondió ${res.status}; el token no sirve para este workspace` };
      results.push(...(await res.json()).results);
    }
  }
  return { findings: diffNotion(config, results) };
}

async function main(argv) {
  const [cmd, arg] = argv;
  if (cmd === "validate") {
    const errors = validate(loadConfig(), loadSchema());
    if (errors.length) { console.error(errors.join("\n")); return 1; }
    console.log("config/ecosistema.json: valida");
    return 0;
  }
  if (cmd === "get") {
    const value = arg ? getPath(loadConfig(), arg) : undefined;
    if (value === undefined) { console.error(`sin valor en ${arg ?? "(ruta vacía)"}`); return 1; }
    console.log(typeof value === "object" ? JSON.stringify(value, null, 2) : String(value));
    return 0;
  }
  if (cmd === "responsables") {
    const areas = argv.slice(1);
    if (!areas.length) { console.error("uso: ecosistema.mjs responsables <area> [<area>...]"); return 2; }
    console.log(JSON.stringify(responsables(loadConfig(), areas), null, 2));
    return 0;
  }
  if (cmd === "lote") {
    if (!arg) { console.error("uso: ecosistema.mjs lote <items.json>"); return 2; }
    const errors = checkLote(loadConfig(), JSON.parse(readFileSync(arg, "utf8")));
    if (errors.length) { console.error(errors.join(String.fromCharCode(10))); return 1; }
    console.log("lote dentro de los topes");
    return 0;
  }
  if (cmd === "discover") {
    const config = loadConfig();
    const write = argv.includes("--write");
    const parts = { drive: discoverDrive(config), notion: await discoverNotion(config) };
    let drift = 0;
    for (const [name, part] of Object.entries(parts)) {
      if (part.skipped) { console.log(`${name}: omitido (${part.skipped})`); continue; }
      if (!part.findings.length) { console.log(`${name}: sin cambios`); continue; }
      for (const f of part.findings) {
        drift += 1;
        console.log(`${name}: ${f.kind} ${f.key}: ${f.detail}`);
        if (write && f.path) setPath(config, f.path, f.value);
      }
    }
    if (write && drift) { config.actualizado = new Date().toISOString().slice(0, 10); writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2) + "\n"); console.log("config actualizada; revisa el diff y abre la PR"); }
    return drift ? 1 : 0;
  }
  console.error("uso: ecosistema.mjs validate | get <ruta> | responsables <area>... | lote <items.json> | discover [--write]");
  return 2;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  process.exitCode = await main(process.argv.slice(2));
}
