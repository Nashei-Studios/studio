import { test } from "node:test";
import assert from "node:assert/strict";
import { validate, loadConfig, getPath, diffDrive, diffNotion } from "./ecosistema.mjs";
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
