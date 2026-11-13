import { test } from "node:test";
import assert from "node:assert/strict";
import { validate, loadConfig, getPath, checkInvariantes, responsables, checkLote, diffDrive, diffDriveRoot, diffNotion } from "./ecosistema.mjs";
import { readFileSync } from "node:fs";

const schema = JSON.parse(readFileSync(new URL("../config/ecosistema.schema.json", import.meta.url), "utf8"));

test("the committed config is valid", () => {
  assert.deepEqual(validate(loadConfig(), schema), []);
});

test("validator rejects a bad id, a missing base and a wrong type", () => {
  const bad = structuredClone(loadConfig());
  bad.notion.bases.reuniones.data_source_id = "no-es-uuid";
  delete bad.notion.bases.juegos;
  bad.roblox.grupo_id = "405835365";
  const errors = validate(bad, schema).join("\n");
  assert.match(errors, /reuniones\.data_source_id/);
  assert.match(errors, /juegos: falta/);
  assert.match(errors, /grupo_id/);
});

test("getPath reads nested values", () => {
  assert.equal(getPath(loadConfig(), "roblox.grupo_id"), 405835365);
  assert.equal(getPath(loadConfig(), "no.existe"), undefined);
});

test("diffDrive reports changed and missing folders", () => {
  const config = loadConfig();
  const listing = Object.values(config.drive.carpetas).map((c) => ({ Name: c.nombre, ID: c.id }));
  assert.deepEqual(diffDrive(config, listing), []);
  const drift = listing.filter((d) => d.Name !== "90-archivo").map((d) => (d.Name === "15-reuniones" ? { ...d, ID: "otro-id-distinto" } : d));
  const kinds = diffDrive(config, drift).map((f) => `${f.kind}:${f.key}`);
  assert.deepEqual(kinds.sort(), ["changed:drive.carpetas.reuniones", "missing:drive.carpetas.archivo"]);
});

test("diffNotion matches by name or alias and flags a moved id", () => {
  const config = loadConfig();
  const ds = Object.values(config.notion.bases).map((b) => ({
    id: b.data_source_id,
    title: [{ plain_text: b.nombre }],
    parent: { database_id: b.database_id },
  }));
  assert.deepEqual(diffNotion(config, ds), []);
  ds[0].id = "00000000-0000-0000-0000-000000000000";
  const f = diffNotion(config, ds);
  assert.equal(f.length, 1);
  assert.equal(f[0].kind, "changed");
});

test("diffDriveRoot flags an unreachable root, a wrong url and a root without the configured folders", () => {
  const config = loadConfig();
  const first = Object.values(config.drive.carpetas)[0].nombre;
  assert.deepEqual(diffDriveRoot(config, { ok: true, names: [first] }), []);
  assert.equal(diffDriveRoot(config, { ok: false, error: "404" })[0].kind, "missing");
  assert.equal(diffDriveRoot(config, { ok: true, names: ["otra"] })[0].kind, "changed");
  const bad = structuredClone(config);
  bad.drive.raiz.url = "https://drive.google.com/drive/folders/otro-id-distinto";
  assert.equal(diffDriveRoot(bad, { ok: true, names: [first] })[0].kind, "changed");
});

test("personas and planning caps pass the cross-checks", () => {
  assert.deepEqual(checkInvariantes(loadConfig()), []);
});

test("invariants reject a duplicated login, an unknown area and a role-less person that owns areas", () => {
  const bad = structuredClone(loadConfig());
  const keys = Object.keys(bad.personas);
  bad.personas[keys[0]].areas.push("inexistente");
  bad.personas[keys[1]].login = bad.personas[keys[0]].login;
  const undefinedKey = keys.find((k) => bad.personas[k].estado === "por-definir");
  bad.personas[undefinedKey].areas = ["ui"];
  const errors = checkInvariantes(bad).join(" | ");
  assert.match(errors, /login repetido/);
  assert.match(errors, /inexistente/);
  assert.match(errors, /por-definir/);
});

test("responsables never assumes an owner for an uncovered area", () => {
  const config = loadConfig();
  const r = responsables(config, ["arte", "código", "audio"]);
  assert.deepEqual(r.sinResponsable, ["audio"]);
  assert.equal(r.cruzaAreas, true);
  assert.equal(r.preguntar.length, 2);
  const undefinedLogins = Object.values(config.personas).filter((p) => p.estado === "por-definir").map((p) => p.login);
  for (const login of undefinedLogins) assert.ok(!r.preguntar.includes(login));
});

test("checkLote enforces the batch, detailed-task and sub-issue caps", () => {
  const config = loadConfig();
  const plan = config.planificacion;
  const ok = Array.from({ length: plan.tope_tareas_detalladas }, (_, i) => ({ id: `L-${i}`, nivel: "tarea", padre: `H-${i % 5}` }));
  assert.deepEqual(checkLote(config, ok), []);
  const tooMany = [...ok, { id: "L-x", nivel: "tarea", padre: "H-0" }];
  assert.match(checkLote(config, tooMany).join(" | "), /tareas detalladas/);
  const fat = Array.from({ length: plan.tope_sub_issues_por_padre + 1 }, (_, i) => ({ id: `S-${i}`, nivel: "historia", padre: "E-1" }));
  assert.match(checkLote(config, fat).join(" | "), /E-1 tiene/);
  const huge = Array.from({ length: plan.tope_issues_por_lote + 1 }, (_, i) => ({ id: `E-${i}`, nivel: "epica" }));
  assert.match(checkLote(config, huge).join(" | "), /tope es/);
});
