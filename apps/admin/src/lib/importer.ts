// Toplu aktarım doğrulaması. İki biçim desteklenir:
//  1. JSON: `pnpm content:bundle` çıktısı (content/dist-content.json) ya da onun tablolarından bir alt küme.
//  2. CSV: hedef kelime/ifade satırları (alıştırmalar YAML paketlerinde yazılır; CSV ile gelen hedefler alıştırmasız taslaktır).
// Her iki yol da yalnız TASLAK satır üretir; yayımlanmış içerik içe aktarılamaz.
import { v5 as uuidv5 } from "uuid";

export const NAMESPACE = "6f1d2b3c-8a4e-5f60-9b7c-2d3e4f5a6b7c"; // content/scripts/lib/build.ts ile aynı
export const uid = (key: string) => uuidv5(key, NAMESPACE);

export type ImportIssue = { level: "error" | "warning"; where: string; message: string };
export type Row = Record<string, unknown>;
export type ImportPlan = { tables: Record<string, Row[]>; issues: ImportIssue[]; counts: Record<string, number> };

export const TABLE_ORDER = [
  "domains", "packs", "lexemes", "senses", "sense_usages", "grammar_notes", "patterns", "pattern_slots", "learning_targets",
  "pack_targets", "pack_grammar_notes", "exercises", "scenarios", "readings", "writing_tasks", "situations", "situation_items",
] as const;

const REQUIRED: Record<string, string[]> = {
  packs: ["id", "domain_id", "slug", "title_tr", "description_tr"],
  lexemes: ["id", "lemma", "pos"],
  senses: ["id", "lexeme_id", "meaning_tr"],
  sense_usages: ["id", "sense_id", "domain_id", "example_en", "example_tr"],
  grammar_notes: ["id", "slug", "title_tr", "short_tr", "long_tr"],
  patterns: ["id", "template_en", "slot_key", "example_en", "example_tr"],
  pattern_slots: ["id", "pattern_id", "text_en", "text_tr"],
  learning_targets: ["id", "slug", "kind", "difficulty"],
  pack_targets: ["pack_id", "target_id"],
  pack_grammar_notes: ["pack_id", "grammar_note_id"],
  exercises: ["id", "target_id", "type", "skill", "prompt", "answer", "explanation_tr", "difficulty"],
  scenarios: ["id", "pack_id", "title_tr", "situation_tr", "turns", "difficulty"],
  readings: ["id", "pack_id", "title", "kind", "sentences", "questions", "difficulty"],
  writing_tasks: ["id", "pack_id", "prompt_tr", "rubric", "sample_answers", "difficulty"],
  situations: ["id", "domain_id", "name_tr"],
  situation_items: ["situation_id", "target_id"],
  domains: ["id", "name_tr"],
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DOMAINS = new Set(["general", "software", "engineering", "yds", "health", "tourism", "law"]);

export function validateBundle(input: unknown): ImportPlan {
  const issues: ImportIssue[] = [];
  const tables: Record<string, Row[]> = {};
  const err = (where: string, message: string) => issues.push({ level: "error", where, message });
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    err("dosya", "JSON nesnesi bekleniyor (tablo adı → satır listesi).");
    return { tables, issues, counts: {} };
  }
  const obj = input as Record<string, unknown>;
  const unknownKeys = Object.keys(obj).filter((k) => k !== "content_version" && !(TABLE_ORDER as readonly string[]).includes(k));
  if (unknownKeys.length) issues.push({ level: "warning", where: "dosya", message: `Tanınmayan alanlar yok sayıldı: ${unknownKeys.join(", ")}` });

  for (const t of TABLE_ORDER) {
    const rows = obj[t];
    if (rows === undefined) continue;
    if (!Array.isArray(rows)) {
      err(t, "satır listesi olmalı");
      continue;
    }
    tables[t] = rows as Row[];
    rows.forEach((r, i) => {
      const where = `${t}[${i}]`;
      if (!r || typeof r !== "object") return err(where, "satır nesne olmalı");
      const row = r as Row;
      for (const f of REQUIRED[t] ?? []) {
        if (row[f] === undefined || row[f] === null || row[f] === "") err(where, `zorunlu alan eksik: ${f}`);
      }
      if ("id" in row && t !== "domains" && typeof row.id === "string" && !UUID.test(row.id)) err(where, "id geçerli bir UUID değil");
      if ("status" in row && row.status !== "draft") err(where, `içe aktarılan içerik taslak olmalı (status: ${String(row.status)})`);
      if ("domain_id" in row && !DOMAINS.has(String(row.domain_id))) err(where, `bilinmeyen alan: ${String(row.domain_id)}`);
      if ("difficulty" in row && !(Number(row.difficulty) >= 1 && Number(row.difficulty) <= 5)) err(where, "zorluk 1–5 arasında olmalı");
    });
  }

  // Seçenekli alıştırmalarda cevap indeksi ve tekrarlanan seçenek kontrolü
  (tables.exercises ?? []).forEach((ex, i) => {
    const p = ex.prompt as { options?: string[] } | undefined;
    const a = ex.answer as { index?: number } | undefined;
    if (p?.options) {
      const norm = p.options.map((o) => o.trim().toLowerCase());
      if (new Set(norm).size !== norm.length) err(`exercises[${i}]`, "seçenekler tekrar ediyor");
      if (a?.index === undefined || a.index < 0 || a.index >= p.options.length) err(`exercises[${i}]`, "cevap indeksi seçeneklerin dışında");
    }
  });

  // Dosya içi referanslar (dosyada olmayan kimliklerin veritabanında olması gerekir: uyarı)
  const ids = (t: string) => new Set((tables[t] ?? []).map((r) => String(r.id)));
  const targets = ids("learning_targets");
  const senses = ids("senses");
  const patterns = ids("patterns");
  const checkRef = (t: string, field: string, pool: Set<string>, label: string) => {
    (tables[t] ?? []).forEach((r, i) => {
      const v = r[field];
      if (v && !pool.has(String(v))) issues.push({ level: "warning", where: `${t}[${i}]`, message: `${label} dosyada yok (${String(v).slice(0, 8)}…); veritabanında bulunmalı` });
    });
  };
  if (tables.exercises) checkRef("exercises", "target_id", targets, "hedef");
  if (tables.learning_targets) {
    checkRef("learning_targets", "sense_id", senses, "anlam");
    checkRef("learning_targets", "pattern_id", patterns, "kalıp");
  }
  // Alıştırması olmayan hedefler
  if (tables.learning_targets && tables.exercises) {
    const withEx = new Set(tables.exercises.map((e) => String(e.target_id)));
    const missing = tables.learning_targets.filter((t) => !withEx.has(String(t.id))).length;
    if (missing) issues.push({ level: "warning", where: "learning_targets", message: `${missing} hedefin alıştırması yok; öğrenme oturumlarında gösterilmez` });
  }

  const counts = Object.fromEntries(Object.entries(tables).map(([k, v]) => [k, v.length]));
  return { tables, issues, counts };
}

// ------------------------------------------------------------------ CSV
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') { cell += '"'; i++; }
      else if (ch === '"') quoted = false;
      else cell += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ",") { row.push(cell); cell = ""; }
    else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && text[i + 1] === "\n") i++;
      row.push(cell); cell = "";
      if (row.some((c) => c.trim() !== "")) rows.push(row);
      row = [];
    } else cell += ch;
  }
  row.push(cell);
  if (row.some((c) => c.trim() !== "")) rows.push(row);
  return rows;
}

export const CSV_COLUMNS = ["slug", "lemma", "pos", "meaning_tr", "example_en", "example_tr", "difficulty", "pack_slug"] as const;
const POS = new Set(["n", "v", "adj", "adv", "phrase", "phrasal", "conj", "prep"]);

export function planFromCsv(text: string): ImportPlan {
  const issues: ImportIssue[] = [];
  const rows = parseCsv(text.replace(/^\uFEFF/, ""));
  const tables: Record<string, Row[]> = { lexemes: [], senses: [], sense_usages: [], learning_targets: [] };
  if (!rows.length) {
    issues.push({ level: "error", where: "dosya", message: "CSV boş" });
    return { tables, issues, counts: {} };
  }
  const header = rows[0].map((h) => h.trim());
  const missing = CSV_COLUMNS.filter((c) => !header.includes(c));
  if (missing.length) {
    issues.push({ level: "error", where: "başlık", message: `eksik sütunlar: ${missing.join(", ")}` });
    return { tables, issues, counts: {} };
  }
  const col = (r: string[], c: string) => (r[header.indexOf(c)] ?? "").trim();
  const seen = new Set<string>();
  rows.slice(1).forEach((r, i) => {
    const where = `satır ${i + 2}`;
    const slug = col(r, "slug");
    const m = /^(general|software|engineering|yds|health|tourism|law):([a-z0-9][a-z0-9-]{1,60})$/.exec(slug);
    if (!m) return issues.push({ level: "error", where, message: "slug “alan:kimlik” biçiminde olmalı (ör. software:blocker)" });
    if (seen.has(slug)) return issues.push({ level: "error", where, message: `tekrarlanan slug: ${slug}` });
    seen.add(slug);
    const pos = col(r, "pos");
    if (!POS.has(pos)) issues.push({ level: "error", where, message: `geçersiz tür: ${pos}` });
    const d = Number(col(r, "difficulty"));
    if (!(d >= 1 && d <= 5)) issues.push({ level: "error", where, message: "zorluk 1–5 arasında olmalı" });
    for (const c of ["lemma", "meaning_tr", "example_en", "example_tr"]) if (!col(r, c)) issues.push({ level: "error", where, message: `boş alan: ${c}` });
    const lemma = col(r, "lemma");
    const lexId = uid(`lexeme:${lemma.toLowerCase()}|${pos}`);
    const senseId = uid("sense:" + slug);
    tables.lexemes.push({ id: lexId, lemma, pos, is_phrase: pos === "phrase" || lemma.includes(" "), status: "draft" });
    tables.senses.push({ id: senseId, lexeme_id: lexId, meaning_tr: col(r, "meaning_tr"), status: "draft" });
    tables.sense_usages.push({ id: uid("usage:" + slug), sense_id: senseId, domain_id: m[1], example_en: col(r, "example_en"), example_tr: col(r, "example_tr"), status: "draft" });
    tables.learning_targets.push({ id: uid("target:" + slug), slug, kind: "sense", sense_id: senseId, pattern_id: null, difficulty: d, status: "draft" });
  });
  const lexSeen = new Set<string>();
  tables.lexemes = tables.lexemes.filter((l) => (lexSeen.has(String(l.id)) ? false : (lexSeen.add(String(l.id)), true)));
  if (tables.learning_targets.length) {
    issues.push({ level: "warning", where: "hedefler", message: "CSV ile gelen hedeflerin alıştırması yok; alıştırmalar eklenene kadar oturumlarda gösterilmez." });
  }
  const counts = Object.fromEntries(Object.entries(tables).map(([k, v]) => [k, v.length]));
  return { tables, issues, counts };
}
