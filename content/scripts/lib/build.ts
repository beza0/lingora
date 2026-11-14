// YAML paketlerini okur, doğrular ve veritabanı/uygulama biçimine (normalize) dönüştürür.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { createHash } from "node:crypto";
import { parse } from "yaml";
import { v5 as uuidv5 } from "uuid";
import { PackSchema, type Pack, type Target, type Pattern, type DomainId } from "../../schema/authoring.ts";

export const NAMESPACE = "6f1d2b3c-8a4e-5f60-9b7c-2d3e4f5a6b7c";
export const uid = (key: string) => uuidv5(key, NAMESPACE);

export const POS_TR: Record<string, string> = {
  n: "isim", v: "fiil", adj: "sıfat", adv: "zarf", phrase: "ifade", phrasal: "öbek fiil", conj: "bağlaç", prep: "edat",
};

export const DOMAIN_ROWS = [
  { id: "general", name_tr: "Genel İngilizce", description_tr: "Günlük konuşma, istekler, planlar ve sorunlar.", color_key: "general", sort: 1 },
  { id: "software", name_tr: "Yazılım İngilizcesi", description_tr: "Toplantı, hata kaydı ve kod incelemesinde kullanılan İngilizce.", color_key: "software", sort: 2 },
  { id: "engineering", name_tr: "Mühendislik İngilizcesi", description_tr: "Ölçüm, test, teknik sorun ve çözüm önerisi.", color_key: "engineering", sort: 3 },
  { id: "yds", name_tr: "YDS/YÖKDİL", description_tr: "Akademik cümle yorumlama, paragraf ilişkileri ve çıkarım.", color_key: "yds", sort: 4 },
  { id: "health", name_tr: "Sağlık İngilizcesi", description_tr: "Muayene, belirtiler, hasta öyküsü ve ilaç talimatı.", color_key: "health", sort: 5 },
  { id: "tourism", name_tr: "Turizm İngilizcesi", description_tr: "Otel, resepsiyon, rezervasyon ve misafir karşılama.", color_key: "tourism", sort: 6 },
  { id: "law", name_tr: "Hukuk İngilizcesi", description_tr: "Sözleşme dili, haklar ve yükümlülükler, hukuki yazışma.", color_key: "law", sort: 7 },
  { id: "a1", name_tr: "A1 · Başlangıç", description_tr: "am/is/are, present simple, there is/are; kendini, aileni ve gününü anlatma.", color_key: "a1", sort: 11 },
  { id: "a2", name_tr: "A2 · Temel", description_tr: "Past simple, gelecek planları, karşılaştırma; geçmişi ve planları anlatma.", color_key: "a2", sort: 12 },
  { id: "b1", name_tr: "B1 · Orta", description_tr: "Present perfect, if cümleleri, -ing/to; deneyim, tavsiye ve görüş.", color_key: "b1", sort: 13 },
  { id: "b2", name_tr: "B2 · Orta üstü", description_tr: "Relative clauses, bağlaçlar, 3. tip if, wish; tartışma ve pişmanlık.", color_key: "b2", sort: 14 },
  { id: "c1", name_tr: "C1 · İleri", description_tr: "Devrik yapı, cleft cümleler, akademik ve resmî dil.", color_key: "c1", sort: 15 },
  { id: "c2", name_tr: "C2 · Ustalık", description_tr: "Subjunctive, karma if, deyimler ve üslup inceliği.", color_key: "c2", sort: 16 },
];

export type Issue = { file: string; path: string; message: string; level: "error" | "warning" };

export const split = (p: string) => {
  const i = p.indexOf("|");
  return [p.slice(0, i).trim(), p.slice(i + 1).trim()] as const;
};
export const markedForm = (s: string) => /\[\[([^\]]+)\]\]/.exec(s)![1];
export const stripMarks = (s: string) => s.replace(/\[\[([^\]]+)\]\]/g, "$1");
export const blankOut = (s: string) => s.replace(/\[\[[^\]]+\]\]/, "____");
const norm = (s: string) => s.toLowerCase().replace(/[’']/g, "'").replace(/\s+/g, " ").trim();

// Belirlenimci karıştırma: aynı girdi her zaman aynı sırayı verir
export function detOrder<T>(items: T[], seed: string): T[] {
  return items
    .map((it, i) => ({ it, k: createHash("sha1").update(seed + ":" + i).digest("hex") }))
    .sort((a, b) => (a.k < b.k ? -1 : 1))
    .map((x) => x.it);
}

export type LoadedPack = { file: string; pack: Pack };

export function loadPacks(root: string, issues: Issue[]): LoadedPack[] {
  const out: LoadedPack[] = [];
  const walk = (dir: string): string[] =>
    readdirSync(dir).flatMap((f) => {
      const p = join(dir, f);
      return statSync(p).isDirectory() ? walk(p) : f.endsWith(".yaml") ? [p] : [];
    });
  for (const file of walk(root).sort()) {
    const rel = relative(root, file);
    let raw: unknown;
    try {
      raw = parse(readFileSync(file, "utf8"));
    } catch (e) {
      issues.push({ file: rel, path: "", message: "YAML okunamadı: " + (e as Error).message, level: "error" });
      continue;
    }
    const r = PackSchema.safeParse(raw);
    if (!r.success) {
      for (const iss of r.error.issues) issues.push({ file: rel, path: iss.path.join("."), message: iss.message, level: "error" });
      continue;
    }
    out.push({ file: rel, pack: r.data });
  }
  return out;
}

type Row = Record<string, unknown>;
export type Bundle = {
  content_version: string;
  domains: Row[]; packs: Row[]; lexemes: Row[]; senses: Row[]; sense_usages: Row[]; grammar_notes: Row[];
  patterns: Row[]; pattern_slots: Row[]; learning_targets: Row[]; pack_targets: Row[]; pack_grammar_notes: Row[];
  exercises: Row[]; scenarios: Row[]; readings: Row[]; writing_tasks: Row[]; situations: Row[]; situation_items: Row[];
};

type TargetInfo = { domain: DomainId; slug: string; uuid: string; kind: "sense" | "pattern"; label: string; tr: string; exTr: string; pos: string };

export function buildBundle(loaded: LoadedPack[], issues: Issue[]): Bundle {
  const b: Bundle = {
    content_version: "", domains: DOMAIN_ROWS.map((d) => ({ ...d, status: "draft" })), packs: [], lexemes: [], senses: [],
    sense_usages: [], grammar_notes: [], patterns: [], pattern_slots: [], learning_targets: [], pack_targets: [],
    pack_grammar_notes: [], exercises: [], scenarios: [], readings: [], writing_tasks: [], situations: [], situation_items: [],
  };
  const err = (file: string, path: string, message: string) => issues.push({ file, path, message, level: "error" });
  const targets = new Map<string, TargetInfo>(); // "domain:id" → bilgi
  const lexemes = new Map<string, Row>();
  const grammar = new Map<string, string>(); // id → uuid
  const packIds = new Set<string>();

  // 1. tur: tanımları topla (referanslar her sırada çözülebilsin)
  for (const { file, pack } of loaded) {
    if (packIds.has(pack.id)) err(file, "id", `paket kimliği tekrar ediyor: ${pack.id}`);
    packIds.add(pack.id);
    for (const g of pack.grammar) {
      if (grammar.has(g.id)) err(file, `grammar.${g.id}`, "gramer notu kimliği tekrar ediyor");
      grammar.set(g.id, uid("grammar:" + g.id));
    }
    for (const t of pack.targets) {
      if ("use" in t) continue;
      const key = `${pack.domain}:${t.id}`;
      if (targets.has(key)) err(file, `targets.${t.id}`, `hedef kimliği alanda tekrar ediyor: ${key}`);
      targets.set(key, { domain: pack.domain, slug: key, uuid: uid("target:" + key), kind: "sense", label: t.w, tr: t.tr, exTr: t.extr, pos: t.pos });
    }
    for (const p of pack.patterns) {
      const key = `${pack.domain}:${p.id}`;
      if (targets.has(key)) err(file, `patterns.${p.id}`, `kimlik tekrar ediyor: ${key}`);
      targets.set(key, { domain: pack.domain, slug: key, uuid: uid("target:" + key), kind: "pattern", label: p.t, tr: p.extr, exTr: p.extr, pos: "pattern" });
    }
  }

  const resolve = (domain: string, ref: string) => targets.get(ref.includes(":") ? ref : `${domain}:${ref}`);

  // 2. tur: satırları üret
  for (const { file, pack } of loaded) {
    const packUuid = uid("pack:" + pack.id);
    b.packs.push({ id: packUuid, domain_id: pack.domain, slug: pack.id, title_tr: pack.title, description_tr: pack.desc, sort: pack.sort, status: "draft" });

    const own = pack.targets.filter((t): t is Target => !("use" in t));
    own.forEach((t, i) => {
      const key = `${pack.domain}:${t.id}`;
      const lexKey = `${t.w.toLowerCase()}|${t.pos}`;
      if (!lexemes.has(lexKey)) {
        const row = { id: uid("lexeme:" + lexKey), lemma: t.w, pos: t.pos, is_phrase: t.pos === "phrase" || t.w.includes(" "), status: "draft" };
        lexemes.set(lexKey, row);
        b.lexemes.push(row);
      }
      const lexId = lexemes.get(lexKey)!.id as string;
      const senseId = uid("sense:" + key);
      b.senses.push({ id: senseId, lexeme_id: lexId, meaning_tr: t.tr, definition_en: null, register: t.tone.join(", "), notes_tr: null, status: "draft" });
      b.sense_usages.push({
        id: uid("usage:" + key), sense_id: senseId, domain_id: pack.domain, example_en: stripMarks(t.ex), example_tr: t.extr,
        collocations: t.col, family: t.fam, synonyms: t.syn, antonyms: t.ant,
        confusables: t.conf.map((c) => ({ word: split(c)[0], note_tr: split(c)[1] })), other_meanings_tr: t.other ?? null,
        tone_tags: t.tone, status: "draft",
      });
      const tUuid = uid("target:" + key);
      b.learning_targets.push({ id: tUuid, slug: key, kind: "sense", sense_id: senseId, pattern_id: null, difficulty: t.d, status: "draft" });
      b.pack_targets.push({ pack_id: packUuid, target_id: tUuid, sort: i, is_core: true });
    });
    pack.targets.forEach((t, i) => {
      if (!("use" in t)) return;
      const info = targets.get(t.use);
      if (!info) return err(file, `targets[${i}]`, `bulunamayan hedef referansı: ${t.use}`);
      b.pack_targets.push({ pack_id: packUuid, target_id: info.uuid, sort: i, is_core: true });
    });

    pack.patterns.forEach((p, i) => {
      const key = `${pack.domain}:${p.id}`;
      const pid = uid("pattern:" + key);
      const gid = grammar.get(p.g);
      if (!gid) err(file, `patterns.${p.id}.g`, `bulunamayan gramer notu: ${p.g}`);
      b.patterns.push({
        id: pid, template_en: p.t, slot_key: markedForm(p.ex), example_en: stripMarks(p.ex), example_tr: p.extr,
        chunks: p.chunks.map((c) => ({ en: split(c)[0], tr: split(c)[1] })), grammar_note_id: gid ?? null,
        context_tags: p.ctx, tone_tags: p.tone, template_tr: p.ttr, status: "draft",
      });
      p.slots.forEach((s, j) => {
        const [en, tr] = split(s);
        b.pattern_slots.push({ id: uid(`slot:${key}:${j}`), pattern_id: pid, text_en: en, text_tr: tr, sentence_tr: slotSentence(p.ttr, tr), sort: j });
      });
      const tUuid = uid("target:" + key);
      b.learning_targets.push({ id: tUuid, slug: key, kind: "pattern", sense_id: null, pattern_id: pid, difficulty: p.d, status: "draft" });
      b.pack_targets.push({ pack_id: packUuid, target_id: tUuid, sort: 100 + i, is_core: true });
    });

    pack.grammar.forEach((g, i) => {
      b.grammar_notes.push({
        id: grammar.get(g.id), slug: g.id, title_tr: g.title, short_tr: g.short, long_tr: g.long,
        examples: g.ex.map((e) => ({ en: split(e)[0], tr: split(e)[1] })), status: "draft",
      });
      b.pack_grammar_notes.push({ pack_id: packUuid, grammar_note_id: grammar.get(g.id), sort: i });
    });

    // ---- alıştırmalar
    b.exercises.push(...targetExercises(pack, own, file, err), ...patternExercises(pack, file, err));

    // ---- senaryolar (seçim adımları ayrıca diyalog alıştırması olur)
    pack.scenarios.forEach((s) => {
      const key = `${pack.domain}:${s.id}`;
      const tIds = s.targets.map((r) => {
        const info = resolve(pack.domain, r);
        if (!info) err(file, `scenarios.${s.id}.targets`, `bulunamayan hedef: ${r}`);
        return info?.uuid;
      }).filter(Boolean) as string[];
      const turns: Row[] = [];
      let choiceNo = 0;
      s.turns.forEach((tu, ti) => {
        if (Array.isArray(tu)) return turns.push({ speaker: tu[0], en: tu[1], tr: tu[2] });
        const correct = tu.choose.filter((o) => o[1]).length;
        if (correct !== 1) err(file, `scenarios.${s.id}.turns[${ti}]`, `seçim adımında tam bir doğru seçenek olmalı (${correct} var)`);
        const texts = tu.choose.map((o) => norm(o[0]));
        if (new Set(texts).size !== texts.length) err(file, `scenarios.${s.id}.turns[${ti}]`, "seçenekler tekrar ediyor");
        const order = detOrder(tu.choose, key + ":" + ti);
        turns.push({ choose: order.map((o) => ({ en: o[0], correct: o[1], why_tr: o[2] })), q: tu.q ?? "En uygun yanıt hangisi?" });
        if (tIds[0]) {
          b.exercises.push({
            id: uid(`ex:${key}:dialogue:${choiceNo++}`), target_id: tIds[0], type: "dialogue_choice", skill: "reading",
            prompt: { instruction_tr: tu.q ?? "Diyalogda en uygun yanıtı seç.", context: s.turns.slice(0, ti).filter(Array.isArray).map((x) => ({ speaker: x[0], en: x[1] })), options: order.map((o) => o[0]), scenario_id: uid("scenario:" + key) },
            answer: { index: order.findIndex((o) => o[1]) }, accepted_answers: [],
            distractor_notes: Object.fromEntries(order.filter((o) => !o[1]).map((o) => [o[0], o[2]])),
            explanation_tr: order.find((o) => o[1])?.[2] ?? "", difficulty: s.d, status: "draft",
          });
        }
      });
      if (!s.turns.some((tu) => !Array.isArray(tu))) err(file, `scenarios.${s.id}`, "senaryoda en az bir seçim adımı olmalı");
      b.scenarios.push({ id: uid("scenario:" + key), pack_id: packUuid, title_tr: s.title, situation_tr: s.sit, turns, target_ids: tIds, mode: "choice", difficulty: s.d, status: "draft" });
    });

    pack.readings.forEach((r) => {
      const key = `${pack.domain}:${r.id}`;
      r.q.forEach((q, qi) => {
        if (q.a >= q.o.length) err(file, `readings.${r.id}.q[${qi}]`, "cevap indeksi seçenek sayısını aşıyor");
        if (new Set(q.o.map(norm)).size !== q.o.length) err(file, `readings.${r.id}.q[${qi}]`, "seçenekler tekrar ediyor");
      });
      b.readings.push({
        id: uid("reading:" + key), pack_id: packUuid, title: r.title, kind: r.kind, sentences: r.s.map(([en, tr]) => ({ en, tr })),
        glossary: r.gloss.map((g) => ({ term: split(g)[0], tr: split(g)[1] })),
        questions: r.q.map((q) => ({ q_tr: q.q, options: q.o, answer: q.a, why_tr: q.why })), difficulty: r.d, status: "draft",
      });
    });

    const w = pack.writing;
    b.writing_tasks.push({ id: uid(`writing:${pack.domain}:${w.id}`), pack_id: packUuid, prompt_tr: w.p, rubric: w.rubric, sample_answers: w.samples, difficulty: w.d, status: "draft" });

    // ---- Cümle Rehberi
    const parents = new Map<string, string>();
    pack.situations.forEach((st, si) => {
      const parentKey = `${pack.domain}:${st.parent}`;
      if (!parents.has(parentKey)) {
        const pidS = uid("situation:" + parentKey);
        parents.set(parentKey, pidS);
        if (!b.situations.some((x) => x.id === pidS)) b.situations.push({ id: pidS, domain_id: pack.domain, parent_id: null, name_tr: st.parent, sort: si, status: "draft" });
      }
      const sid = uid(`situation:${parentKey}:${st.name}`);
      b.situations.push({ id: sid, domain_id: pack.domain, parent_id: parents.get(parentKey), name_tr: st.name, sort: si, status: "draft" });
      st.items.forEach((it, k) => {
        const info = resolve(pack.domain, it);
        if (!info) return err(file, `situations[${si}].items`, `bulunamayan hedef: ${it}`);
        b.situation_items.push({ situation_id: sid, target_id: info.uuid, sort: k });
      });
    });
  }

  b.content_version = createHash("sha256").update(JSON.stringify({ ...b, content_version: "" })).digest("hex").slice(0, 16);
  return b;
}

function pickOthers<T extends { pos?: string }>(all: T[], i: number, n: number, pos?: string): T[] {
  const others = all.map((x, j) => ({ x, j })).filter((o) => o.j !== i);
  others.sort((a, b) => {
    const sa = pos && a.x.pos === pos ? 0 : 1;
    const sb = pos && b.x.pos === pos ? 0 : 1;
    if (sa !== sb) return sa - sb;
    const da = (a.j - i + all.length) % all.length;
    const db = (b.j - i + all.length) % all.length;
    return da - db;
  });
  return others.slice(0, n).map((o) => o.x);
}

function mcq(seed: string, correct: string, wrong: string[]) {
  const opts = detOrder([correct, ...wrong], seed);
  return { options: opts, index: opts.indexOf(correct) };
}

function targetExercises(pack: Pack, own: Target[], file: string, err: (f: string, p: string, m: string) => void): Row[] {
  const rows: Row[] = [];
  const d = pack.domain;
  const kind = (t: Target) => (t.pos === "phrase" || t.w.includes(" ") ? "ifade" : "kelime");
  own.forEach((t, i) => {
    const key = `${d}:${t.id}`;
    const tid = uid("target:" + key);
    const form = markedForm(t.ex);
    const sentence = stripMarks(t.ex);

    // 1. anlam seçme
    const o1 = pickOthers(own, i, 3, t.pos);
    const m1 = mcq(key + ":meaning", t.tr, o1.map((x) => x.tr));
    rows.push({
      id: uid(`ex:${key}:meaning`), target_id: tid, type: "meaning_choice", skill: "vocab",
      prompt: { instruction_tr: `Bu ${kind(t)} bu cümlede ne anlama geliyor?`, text: t.w, sentence, options: m1.options },
      answer: { index: m1.index }, accepted_answers: [],
      distractor_notes: Object.fromEntries(o1.map((x) => [x.tr, `Bu anlam “${x.w}” için geçerli.`])),
      explanation_tr: `${t.w} = ${t.tr}.`, difficulty: t.d, status: "draft",
    });

    // 2. bağlama uygun boşluk doldurma
    const dis = t.dis.map(split);
    const m2 = mcq(key + ":cloze", form, dis.map((x) => x[0]));
    rows.push({
      id: uid(`ex:${key}:cloze`), target_id: tid, type: "cloze_choice", skill: "vocab",
      prompt: { instruction_tr: "Boşluğa en uygun seçeneği seç.", sentence: blankOut(t.ex), sentence_tr: t.extr, options: m2.options, hints_tr: [hintFor(t), `İlk harf: ${form[0]}`] },
      answer: { index: m2.index, text: form }, accepted_answers: [],
      distractor_notes: Object.fromEntries(dis.map(([w, why]) => [w, why])),
      explanation_tr: `“${form}” bu cümleye uyar: ${t.tr}.`, difficulty: t.d, status: "draft",
    });

    // 3. yazarak hatırlama
    const accepted = [...new Set([form, ...t.alt].map((s) => s.trim()))];
    rows.push({
      id: uid(`ex:${key}:recall`), target_id: tid, type: "recall_typing", skill: "vocab",
      prompt: { instruction_tr: `Boşluğa uygun İngilizce ${kind(t)}yi yaz.`, sentence: blankOut(t.ex), sentence_tr: t.extr, hints_tr: [t.tr, `${form[0]}${"_".repeat(Math.max(form.length - 1, 1))} (${form.length} karakter)`] },
      answer: { text: form }, accepted_answers: accepted, distractor_notes: {},
      explanation_tr: `Doğru cevap: ${form}. ${t.w} = ${t.tr}.`, difficulty: Math.min(t.d + 1, 5), status: "draft",
    });

    // 4. dinleyip anlam bulma
    const m4 = mcq(key + ":listen", t.extr, o1.map((x) => x.extr));
    rows.push({
      id: uid(`ex:${key}:listen`), target_id: tid, type: "listen_choice", skill: "listening",
      prompt: { instruction_tr: "Cümleyi dinle. Anlamı hangisi?", audio_text: sentence, options: m4.options },
      answer: { index: m4.index }, accepted_answers: [],
      distractor_notes: Object.fromEntries(o1.map((x) => [x.extr, `Bu, “${x.w}” örneğinin çevirisi.`])),
      explanation_tr: `“${sentence}” = ${t.extr}`, difficulty: t.d, status: "draft",
    });
  });

  // 5. eşleştirme: dörtlü gruplar
  for (let g = 0; g + 4 <= own.length; g += 4) {
    const group = own.slice(g, g + 4);
    const key = `${d}:${group[0].id}`;
    rows.push({
      id: uid(`ex:${key}:match`), target_id: uid("target:" + key), type: "matching", skill: "vocab",
      prompt: { instruction_tr: "Kelimeleri anlamlarıyla eşleştir.", left: group.map((x) => x.w), right: detOrder(group.map((x) => x.tr), key + ":match") },
      answer: { pairs: group.map((x) => [x.w, x.tr]) }, accepted_answers: [], distractor_notes: {},
      explanation_tr: group.map((x) => `${x.w} = ${x.tr}`).join(" · "), difficulty: Math.max(...group.map((x) => x.d)),
      status: "draft", group_target_ids: group.map((x) => uid(`target:${d}:${x.id}`)),
    });
  }
  return rows;
}

function hintFor(t: Target) {
  return t.col.length ? `Sık birlikte: ${t.col.slice(0, 2).join(", ")}` : `Anlamı: ${t.tr}`;
}

function patternExercises(pack: Pack, file: string, err: (f: string, p: string, m: string) => void): Row[] {
  const rows: Row[] = [];
  const d = pack.domain;
  pack.patterns.forEach((p: Pattern, i) => {
    const key = `${d}:${p.id}`;
    const tid = uid("target:" + key);
    const keyPart = markedForm(p.ex);
    const full = stripMarks(p.ex);
    const dis = p.dis.map(split);
    const m1 = mcq(key + ":cloze", keyPart, dis.map((x) => x[0]));
    rows.push({
      id: uid(`ex:${key}:cloze`), target_id: tid, type: "cloze_choice", skill: "vocab",
      prompt: { instruction_tr: "Kalıbı tamamla.", sentence: blankOut(p.ex), sentence_tr: p.extr, options: m1.options, hints_tr: [`Kalıp: ${p.t}`] },
      answer: { index: m1.index, text: keyPart }, accepted_answers: [],
      distractor_notes: Object.fromEntries(dis.map(([w, why]) => [w, why])),
      explanation_tr: `Kalıp: ${p.t} — ${p.extr}`, difficulty: p.d, status: "draft",
    });
    rows.push({
      id: uid(`ex:${key}:tr2en`), target_id: tid, type: "tr_to_en", skill: "writing",
      prompt: { instruction_tr: "İngilizcesini yaz.", text_tr: p.extr, hints_tr: [`Kalıp: ${p.t}`, `Başlangıç: ${full.split(" ").slice(0, 2).join(" ")} …`] },
      answer: { text: full }, accepted_answers: [...new Set([full, ...p.alt])], distractor_notes: {},
      explanation_tr: `Örnek cevap: ${full}`, difficulty: Math.min(p.d + 1, 5), status: "draft",
    });
    const others = pickOthers(pack.patterns, i, 3);
    const m3 = mcq(key + ":meaning", p.extr, others.map((x) => x.extr));
    rows.push({
      id: uid(`ex:${key}:meaning`), target_id: tid, type: "meaning_choice", skill: "reading",
      prompt: { instruction_tr: "Bu cümlenin anlamı hangisi?", text: full, options: m3.options },
      answer: { index: m3.index }, accepted_answers: [],
      distractor_notes: Object.fromEntries(others.map((x) => [x.extr, `Bu, “${stripMarks(x.ex)}” cümlesinin anlamı.`])),
      explanation_tr: `${full} = ${p.extr}`, difficulty: p.d, status: "draft",
    });
  });
  return rows;
}

/**
 * Kalıbın Türkçe şablonuna parçayı yerleştirir. Şablonda tek bir boşluk yoksa ya da ek işareti
 * (“-ecektir”, “(-e)”) varsa düzgün cümle kurulamaz; o zaman cümle üretilmez (null).
 */
export function slotSentence(ttr: string, tr: string): string | null {
  const gaps = ttr.split("…").length - 1;
  if (gaps !== 1 || /\(-|… -|…-/.test(ttr)) return null;
  // Soru eki ünlü uyumu: “… mi?” şablonunda parçanın son ünlüsüne göre mı/mi/mu/mü
  const s = ttr.replace(/… m[ıiuü](?=[?\s.!,]|$)/u, `… m${questionVowel(tr)}`).replace("…", tr);
  const first = s.charAt(0);
  const up = first === "i" ? "İ" : first === "ı" ? "I" : first.toLocaleUpperCase("tr");
  const out = (up + s.slice(1)).trimEnd();
  // Şablon “…” ile bitiyorsa cümle sonu noktası eksik kalır
  return /[.!?…:;)”"]$/.test(out) ? out : out + ".";
}

function questionVowel(word: string): string {
  const v = [...word.toLocaleLowerCase("tr")].reverse().find((c) => "aıoueiöü".includes(c));
  if (!v) return "i";
  return "aı".includes(v) ? "ı" : "ei".includes(v) ? "i" : "ou".includes(v) ? "u" : "ü";
}
