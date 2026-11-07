import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildBundle, loadPacks, type Issue } from "./lib/build.ts";
import { validate } from "./lib/validate.ts";

export const CONTENT_ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
export const PACKS_DIR = join(CONTENT_ROOT, "packs");
export const LOCK_FILE = join(CONTENT_ROOT, "ids.lock.json");

export function run(requireTotals = true) {
  const issues: Issue[] = [];
  const loaded = loadPacks(PACKS_DIR, issues);
  const bundle = buildBundle(loaded, issues);
  const report = validate(loaded, bundle, issues, { lockFile: LOCK_FILE, requireTotals });
  return { loaded, bundle, report };
}

export function printIssues(issues: Issue[]) {
  for (const i of issues) console.log(`${i.level === "error" ? "HATA " : "UYARI"} ${i.file} ${i.path ? "· " + i.path : ""} — ${i.message}`);
}
