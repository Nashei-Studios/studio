// Simulated rclone for the smoke test. State lives in FAKE_RCLONE_STATE; FAKE_RCLONE_ACCESS=no simulates a
// Google account that cannot see the shared folder (empty listing).
import { existsSync, writeFileSync, appendFileSync } from "node:fs";
import { join } from "node:path";

const state = process.env.FAKE_RCLONE_STATE;
const args = process.argv.slice(2);
const remoteFile = join(state, "remote.txt");
appendFileSync(join(state, "calls.log"), `${args.join(" ")}\n`);
if (args[0] === "--version") console.log("rclone v0.0-fake");
else if (args[0] === "listremotes") { if (existsSync(remoteFile)) console.log("nashei:"); }
else if (args[0] === "config" && args[1] === "create") writeFileSync(remoteFile, args.slice(2).join(" "));
else if (args[0] === "lsf" && args.includes("--dirs-only")) {
  if (process.env.FAKE_RCLONE_ACCESS !== "no") console.log("00-empieza-aqui/\n10-kits/\n50-arte/");
}
