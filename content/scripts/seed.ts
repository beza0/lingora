// pnpm content:seed — içeriği Supabase'e TASLAK olarak yükler (idempotent upsert).
// Gerekenler (yerel .env): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY. Bu anahtar asla uygulamaya girmez.
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { createClient } from "@supabase/supabase-js";
import { CONTENT_ROOT, printIssues, run } from "./common.ts";

function loadEnv() {
  const p = join(CONTENT_ROOT, "..", ".env");
  if (!existsSync(p)) return;
  for (const line of readFileSync(p, "utf8").split("\n")) {
    const m = /^([A-Z0-9_]+)=(.*)$/.exec(line.trim());
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
  }
}
loadEnv();
const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error("SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY gerekli (.env). Yükleme yapılmadı.");
  process.exit(1);
}
const { bundle, report } = run();
const errors = report.issues.filter((i) => i.level === "error");
if (errors.length) {
  printIssues(errors);
  process.exit(1);
}
const db = createClient(url, key, { auth: { persistSession: false } });

// Var olan satırların durumunu (incelendi/yayımlandı) ezmemek için status yalnız yeni satırlarda 'draft' olur.
async function upsert(table: string, rows: Record<string, unknown>[], onConflict = "id") {
  for (let i = 0; i < rows.length; i += 500) {
    const chunk = rows.slice(i, i + 500);
    const ids = chunk.map((r) => r.id).filter(Boolean);
    let existing = new Map<string, string>();
    if (ids.length && "status" in chunk[0]) {
      const { data, error } = await db.from(table).select("id,status").in("id", ids);
      if (error) throw new Error(`${table}: ${error.message}`);
      existing = new Map((data ?? []).map((r: { id: string; status: string }) => [r.id, r.status]));
    }
    const payload = chunk.map((r) => (existing.has(String(r.id)) ? { ...r, status: existing.get(String(r.id)) } : r));
    const { error } = await db.from(table).upsert(payload, { onConflict });
    if (error) throw new Error(`${table}: ${error.message}`);
  }
  console.log(`${table.padEnd(20)} ${rows.length}`);
}

const order: [keyof typeof bundle, string?][] = [
  ["domains"], ["packs"], ["lexemes"], ["senses"], ["sense_usages"], ["grammar_notes"], ["patterns"], ["pattern_slots"],
  ["learning_targets"], ["pack_targets", "pack_id,target_id"], ["pack_grammar_notes", "pack_id,grammar_note_id"],
  ["exercises"], ["scenarios"], ["readings"], ["writing_tasks"], ["situations"], ["situation_items", "situation_id,target_id"],
];
for (const [table, conflict] of order) await upsert(table, bundle[table] as Record<string, unknown>[], conflict);
const { error } = await db.from("app_config").upsert({ key: "content_version", value: bundle.content_version });
if (error) throw new Error(error.message);
console.log(`Tamam. İçerik sürümü ${bundle.content_version}; bütün yeni satırlar taslak (draft).`);
