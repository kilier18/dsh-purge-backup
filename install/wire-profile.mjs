#!/usr/bin/env node
// wire-profile.mjs - idempotently wire dsh-preset-kit into a DSH profile without the plugin installer.
//
//   node wire-profile.mjs --profile desktop --spec "github:YuJunZhiXue/dsh-preset-kit#v1.1.90"
//   node wire-profile.mjs --profile desktop --spec "file:<REPO_DIR>/dist/dsh-preset-kit-1.1.90.tgz"
//
// What it does (each step skipped when already satisfied):
//   1. package.json  dependencies["dsh-preset-kit"] = <spec>
//   2. package.json  dsh.profile.bundles  += "dsh-preset-kit"
//   3. cordis.patch.yml  ensure an `- id: dsh-preset-kit` insert entry exists
//   4. optional: report whether allowBuilds has an entry for dsh-preset-kit
//
// ASCII only on purpose: runs under cmd.exe / PowerShell without code page games.
import { readFileSync, writeFileSync, existsSync, copyFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  if (i === -1) return fallback;
  const v = process.argv[i + 1];
  if (!v || v.startsWith("--")) return fallback;
  return v;
}

const profile = arg("profile", "desktop");
const spec = arg("spec", "github:YuJunZhiXue/dsh-preset-kit#v1.1.90");
const home = process.env.DSH_HOME || join(homedir(), ".dsh");
const dir = join(home, "profiles", profile);
const pkgFile = join(dir, "package.json");
const patchFile = join(dir, "cordis.patch.yml");

if (!existsSync(pkgFile)) {
  console.error(`[!] profile not found: ${pkgFile}`);
  process.exit(2);
}

const changes = [];
const json = JSON.parse(readFileSync(pkgFile, "utf8"));
json.dependencies ??= {};
if (json.dependencies["dsh-preset-kit"] !== spec) {
  const before = json.dependencies["dsh-preset-kit"];
  json.dependencies["dsh-preset-kit"] = spec;
  changes.push(`package.json dependencies.dsh-preset-kit: ${before ?? "(absent)"} -> ${spec}`);
}
json.dsh ??= {};
json.dsh.profile ??= {};
json.dsh.profile.bundles ??= [];
if (!json.dsh.profile.bundles.includes("dsh-preset-kit")) {
  json.dsh.profile.bundles.push("dsh-preset-kit");
  changes.push("package.json dsh.profile.bundles += dsh-preset-kit");
}
if (changes.length) writeFileSync(pkgFile, JSON.stringify(json, null, 2) + "\n");

if (existsSync(patchFile)) {
  const yml = readFileSync(patchFile, "utf8");
  if (!/^\s*-\s*id:\s*dsh-preset-kit\s*$/m.test(yml)) {
    copyFileSync(patchFile, patchFile + ".wire-bak");
    const block = [
      "",
      "  - id: dsh-preset-kit",
      "    enabled: true",
      "",
    ].join("\n");
    const hasInsert = /^insert:\s*$/m.test(yml);
    const next = hasInsert ? yml.replace(/^insert:\s*$/m, (m) => m + block) : yml + "\ninsert:" + block;
    writeFileSync(patchFile, next);
    changes.push("cordis.patch.yml: appended `- id: dsh-preset-kit` insert entry (backup: .wire-bak)");
  }
} else {
  console.log(`[i] no cordis.patch.yml in ${dir} (web-less profile?); skipped`);
}

const hasBuildKey = existsSync(patchFile) && /allowBuilds:/.test(readFileSync(patchFile, "utf8"));
console.log(`[i] profile = ${dir}`);
console.log(`[i] allowBuilds map present in cordis.patch.yml = ${hasBuildKey}`);
if (!changes.length) console.log("[=] already wired, nothing to do");
else for (const c of changes) console.log("[+] " + c);
console.log("[ok] next: pnpm install (or `pnpm install --ignore-scripts`), then restart DSH desktop");