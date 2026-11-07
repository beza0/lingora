// pnpm content:bundle — uygulamaya gömülen çevrimdışı içerik paketini yazar.
// --update-lock: yayımlanan hedef kimliklerini ids.lock.json'a ekler (kimlikler bir daha silinemez).
import { mkdirSync, writeFileSync, existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { CONTENT_ROOT, LOCK_FILE, printIssues, run } from "./common.ts";

const { bundle, report } = run(!process.argv.includes("--partial"));
const errors = report.issues.filter((i) => i.level === "error");
if (errors.length) {
  printIssues(errors);
  console.error(`\n${errors.length} hata: paket yazılmadı. Önce pnpm content:validate.`);
  process.exit(1);
}
const outDir = join(CONTENT_ROOT, "..", "apps", "mobile", "assets", "content");
mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, "content.json"), JSON.stringify(bundle));
writeFileSync(join(outDir, "version.json"), JSON.stringify({ content_version: bundle.content_version, totals: report.totals }, null, 2));
writeFileSync(join(CONTENT_ROOT, "dist-content.json"), JSON.stringify(bundle, null, 1));
if (process.argv.includes("--update-lock")) {
  const prev: string[] = existsSync(LOCK_FILE) ? JSON.parse(readFileSync(LOCK_FILE, "utf8")).targets : [];
  const all = [...new Set([...prev, ...bundle.learning_targets.map((t) => String(t.slug))])].sort();
  writeFileSync(LOCK_FILE, JSON.stringify({ note: "Bu listedeki hedef kimlikleri kalıcıdır; silinmez, arşivlenir.", targets: all }, null, 2) + "\n");
  console.log(`ids.lock.json: ${all.length} hedef`);
}
console.log(`Yazıldı: apps/mobile/assets/content/content.json · sürüm ${bundle.content_version} · ${report.totals.exercises} alıştırma`);
