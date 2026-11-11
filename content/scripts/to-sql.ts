// Derlenen içeriği SQL INSERT komutlarına çevirir (yerel şema testi ve canlı yükleme). Var olan satırlara dokunmaz (on conflict do nothing).
import { run } from "./common.ts";

const { bundle, report } = run();
if (report.issues.some((i) => i.level === "error")) {
  console.error("İçerik doğrulamadan geçmiyor.");
  process.exit(1);
}
const ARRAY_COLS = new Set(["collocations", "synonyms", "antonyms", "tone_tags", "context_tags", "accepted_answers", "target_ids", "sample_answers", "group_target_ids"]);
const lit = (col: string, v: unknown): string => {
  if (v === null || v === undefined) return "null";
  if (ARRAY_COLS.has(col) && Array.isArray(v)) return `array[${v.map((x) => `'${String(x).replace(/'/g, "''")}'`).join(",")}]::${col === "target_ids" || col === "group_target_ids" ? "uuid[]" : "text[]"}`;
  if (typeof v === "object") return `'${JSON.stringify(v).replace(/'/g, "''")}'::jsonb`;
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  return `'${String(v).replace(/'/g, "''")}'`;
};
const order = ["packs", "lexemes", "senses", "sense_usages", "grammar_notes", "patterns", "pattern_slots", "learning_targets", "pack_targets",
  "pack_grammar_notes", "exercises", "scenarios", "readings", "writing_tasks", "situations", "situation_items"] as const;
const out: string[] = ["begin;"];
for (const d of bundle.domains as Record<string, unknown>[]) {
  const cols = Object.keys(d);
  out.push(`insert into public.domains (${cols.join(",")}) values (${cols.map((c) => lit(c, d[c])).join(",")}) on conflict (id) do update set name_tr = excluded.name_tr, description_tr = excluded.description_tr, sort = excluded.sort;`);
}
for (const t of order) {
  for (const r of bundle[t] as Record<string, unknown>[]) {
    const cols = Object.keys(r);
    out.push(`insert into public.${t} (${cols.join(",")}) values (${cols.map((c) => lit(c, r[c])).join(",")}) on conflict do nothing;`);
  }
}
out.push("commit;");
process.stdout.write(out.join("\n") + "\n");
