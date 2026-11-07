// İçerik doğrulama kuralları. Sayılar, referanslar, cevap anahtarları, kimlik kararlılığı.
import { existsSync, readFileSync } from "node:fs";
import { type Bundle, type Issue, type LoadedPack, markedForm, split, stripMarks } from "./build.ts";
import type { Target } from "../../schema/authoring.ts";

export const PER_PACK = { targets: 20, patterns: 10, scenarios: 2, readings: 2, grammar: 2 } as const;
export const TOTAL = { packs: 12, targets: 240, patterns: 120, scenarios: 24, readings: 24, grammar: 24, writing: 12 } as const;

const norm = (s: string) => s.toLowerCase().replace(/[’']/g, "'").replace(/[.,!?;:]/g, "").replace(/\s+/g, " ").trim();

export type Report = {
  issues: Issue[];
  totals: Record<string, number>;
  uniqueWords: number;
  difficultyByPack: Record<string, Record<number, number>>;
};

export function validate(loaded: LoadedPack[], bundle: Bundle, issues: Issue[], opts: { lockFile?: string; requireTotals?: boolean } = {}): Report {
  const err = (file: string, path: string, message: string) => issues.push({ file, path, message, level: "error" });
  const warn = (file: string, path: string, message: string) => issues.push({ file, path, message, level: "warning" });
  const difficultyByPack: Report["difficultyByPack"] = {};

  for (const { file, pack } of loaded) {
    // sayılar
    if (pack.targets.length !== PER_PACK.targets) err(file, "targets", `${PER_PACK.targets} hedef kelime/ifade gerekli, ${pack.targets.length} var`);
    if (pack.patterns.length !== PER_PACK.patterns) err(file, "patterns", `${PER_PACK.patterns} kalıp gerekli, ${pack.patterns.length} var`);
    if (pack.scenarios.length !== PER_PACK.scenarios) err(file, "scenarios", `${PER_PACK.scenarios} senaryo gerekli, ${pack.scenarios.length} var`);
    if (pack.readings.length !== PER_PACK.readings) err(file, "readings", `${PER_PACK.readings} okuma metni gerekli, ${pack.readings.length} var`);
    if (pack.grammar.length !== PER_PACK.grammar) err(file, "grammar", `${PER_PACK.grammar} yapı açıklaması gerekli, ${pack.grammar.length} var`);
    if (!file.startsWith(pack.domain + "/")) err(file, "domain", `dosya ${pack.domain}/ klasöründe olmalı`);

    const own = pack.targets.filter((t): t is Target => !("use" in t));
    // anlam seçme ve eşleştirme için anlamlar ve çeviriler pakette tekil olmalı
    dupes(own.map((t) => norm(t.tr))).forEach((v) => err(file, "targets", `aynı Türkçe anlam iki hedefte: “${v}” (anlam sorusunda iki doğru olur)`));
    dupes(own.map((t) => norm(t.extr))).forEach((v) => err(file, "targets", `aynı örnek çevirisi iki hedefte: “${v}”`));
    dupes(own.map((t) => norm(t.w))).forEach((v) => err(file, "targets", `aynı sözcük pakette iki kez: “${v}”`));
    dupes(pack.patterns.map((p) => norm(p.extr))).forEach((v) => err(file, "patterns", `aynı kalıp çevirisi iki kez: “${v}”`));

    const dist: Record<number, number> = {};
    for (const t of own) {
      dist[t.d] = (dist[t.d] ?? 0) + 1;
      const form = markedForm(t.ex);
      const dis = t.dis.map((x) => split(x)[0]);
      const all = [form, ...dis].map(norm);
      if (new Set(all).size !== all.length) err(file, `targets.${t.id}.dis`, "çeldirici doğru cevapla veya birbiriyle aynı");
      if (dis.some((x) => norm(stripMarks(t.ex).replace(form, x)) === norm(stripMarks(t.ex)))) err(file, `targets.${t.id}.dis`, "çeldirici cümleyi değiştirmiyor");
      const stem = t.w.toLowerCase().split(" ")[0].slice(0, 4);
      if (!form.toLowerCase().includes(stem.slice(0, 3))) warn(file, `targets.${t.id}.ex`, `işaretli biçim “${form}” sözcükle (“${t.w}”) ilişkili görünmüyor`);
      if (t.tr.length > 70) warn(file, `targets.${t.id}.tr`, "Türkçe anlam uzun; seçenekte okunması zorlaşır");
    }
    for (const p of pack.patterns) {
      dist[p.d] = (dist[p.d] ?? 0) + 1;
      const key = markedForm(p.ex);
      const all = [key, ...p.dis.map((x) => split(x)[0])].map(norm);
      if (new Set(all).size !== all.length) err(file, `patterns.${p.id}.dis`, "çeldirici doğru cevapla veya birbiriyle aynı");
      if (new Set(p.slots.map((s) => norm(split(s)[0]))).size !== p.slots.length) err(file, `patterns.${p.id}.slots`, "değişen parçalar tekrar ediyor");
    }
    for (const r of pack.readings) {
      if (r.q.length < 2) err(file, `readings.${r.id}`, "en az 2 anlama sorusu gerekli");
    }
    difficultyByPack[pack.id] = dist;
  }

  // üretilen seçenekli soruların tutarlılığı
  for (const ex of bundle.exercises) {
    const prompt = ex.prompt as { options?: string[] };
    const answer = ex.answer as { index?: number };
    if (prompt.options) {
      const n = prompt.options.map(norm);
      if (new Set(n).size !== n.length) err("(üretilen)", String(ex.id), `${ex.type}: seçenekler tekrar ediyor: ${prompt.options.join(" / ")}`);
      if (answer.index === undefined || answer.index < 0 || answer.index >= prompt.options.length) err("(üretilen)", String(ex.id), `${ex.type}: geçersiz cevap indeksi`);
    }
    if (!String(ex.explanation_tr ?? "").trim()) err("(üretilen)", String(ex.id), `${ex.type}: açıklama boş`);
  }
  const perTarget = new Map<string, Set<string>>();
  const countPer = new Map<string, number>();
  for (const ex of bundle.exercises) {
    const id = String(ex.target_id);
    perTarget.set(id, (perTarget.get(id) ?? new Set()).add(String(ex.type)));
    countPer.set(id, (countPer.get(id) ?? 0) + 1);
  }
  for (const t of bundle.learning_targets) {
    const n = countPer.get(String(t.id)) ?? 0;
    const types = perTarget.get(String(t.id))?.size ?? 0;
    if (n < 3 || types < 2) err("(üretilen)", String(t.slug), `hedefin en az 3 alıştırması ve 2 türü olmalı (${n} alıştırma, ${types} tür)`);
  }

  // toplamlar
  const totals = {
    packs: loaded.length,
    targets: loaded.reduce((a, l) => a + l.pack.targets.length, 0),
    patterns: loaded.reduce((a, l) => a + l.pack.patterns.length, 0),
    scenarios: bundle.scenarios.length,
    readings: bundle.readings.length,
    grammar: bundle.grammar_notes.length,
    writing: bundle.writing_tasks.length,
    exercises: bundle.exercises.length,
    learning_targets: bundle.learning_targets.length,
  };
  if (opts.requireTotals !== false) {
    for (const [k, v] of Object.entries(TOTAL)) {
      if ((totals as Record<string, number>)[k] !== v) err("(toplam)", k, `${k}: ${v} bekleniyor, ${(totals as Record<string, number>)[k]} var`);
    }
  }

  // kimlik kararlılığı: daha önce kilitlenmiş hedefler silinemez
  if (opts.lockFile && existsSync(opts.lockFile)) {
    const locked: string[] = JSON.parse(readFileSync(opts.lockFile, "utf8")).targets;
    const now = new Set(bundle.learning_targets.map((t) => String(t.slug)));
    for (const s of locked) if (!now.has(s)) err("(kimlik)", s, "kilitli hedef kaldırılmış; hedefler silinmez, arşivlenir (ids.lock.json)");
  }

  const uniqueWords = new Set(bundle.lexemes.map((l) => String(l.lemma).toLowerCase())).size;
  return { issues, totals, uniqueWords, difficultyByPack };
}

function dupes(xs: string[]): string[] {
  const seen = new Set<string>();
  const d = new Set<string>();
  for (const x of xs) (seen.has(x) ? d : seen).add(x);
  return [...d];
}
