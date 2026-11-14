// Paket yazım biçimi (content/packs/<alan>/<paket>.yaml) için şema.
// Kısa anahtarlar bilinçli: 12 paket elle yazılıyor, okunabilir ve kısa kalmalı.
import { z } from "zod";

export const DOMAINS = ["general", "software", "engineering", "yds", "health", "tourism", "law", "a1", "a2", "b1", "b2", "c1", "c2"] as const;
export type DomainId = (typeof DOMAINS)[number];

const id = z.string().regex(/^[a-z0-9][a-z0-9-]{1,60}$/, "kimlik: küçük harf, rakam ve tire");
const difficulty = z.number().int().min(1).max(5);
// "metin | açıklama" biçimindeki çift
const pair = z.string().regex(/^[^|]+\|[^|]+$/, "“metin | açıklama” biçimi bekleniyor");
// [[...]] işaretinden tam bir tane içeren İngilizce cümle
const marked = z.string().refine((s) => (s.match(/\[\[[^\]]+\]\]/g) ?? []).length === 1, "cümlede tam bir [[...]] işareti olmalı");

export const POS = ["n", "v", "adj", "adv", "phrase", "phrasal", "conj", "prep"] as const;

export const TargetSchema = z
  .object({
    id,
    w: z.string().min(1), // sözcük veya ifade (lemma)
    pos: z.enum(POS),
    tr: z.string().min(2), // Türkçe anlam
    ex: marked, // alana uygun örnek, hedef biçim [[...]] içinde
    extr: z.string().min(2), // örneğin Türkçesi
    d: difficulty,
    col: z.array(z.string()).default([]), // sık birliktelikler
    syn: z.array(z.string()).default([]),
    ant: z.array(z.string()).default([]),
    fam: z.array(z.string()).default([]), // kelime ailesi: "block (f.) engellemek"
    conf: z.array(pair).default([]), // karıştırılan: "kelime | not"
    other: z.string().optional(), // diğer anlamlar
    tone: z.array(z.string()).min(1),
    dis: z.array(pair).length(3), // boşluk doldurma çeldiricileri: "metin | neden yanlış"
    alt: z.array(z.string()).default([]), // yazarak cevapta kabul edilen ek biçimler
  })
  .strict();

// Başka paketteki hedefi yeniden kullanma: { use: "general:schedule" }
export const TargetRefSchema = z.object({ use: z.string().regex(/^(general|software|engineering|yds|health|tourism|law|a1|a2|b1|b2|c1|c2):[a-z0-9-]+$/) }).strict();

export const PatternSchema = z
  .object({
    id,
    t: z.string().min(3), // kalıp: "I'm working on …"
    ex: marked, // örnek, [[...]] = boşluk doldurmada sorulan anahtar parça
    extr: z.string().min(2),
    ttr: z.string().includes("…"), // Türkçe şablon, … yerine parça çevirisi gelir
    slots: z.array(pair).min(3), // "the login page | giriş sayfası"
    chunks: z.array(pair).min(2), // yapı parçaları
    g: id, // gramer notu kimliği
    ctx: z.array(z.string()).min(1), // kullanım bağlamı
    tone: z.array(z.string()).min(1),
    d: difficulty,
    dis: z.array(pair).length(3),
    alt: z.array(z.string()).default([]),
  })
  .strict();

export const GrammarSchema = z
  .object({
    id,
    title: z.string(),
    short: z.string().min(20),
    long: z.string().min(40),
    ex: z.array(pair).min(2), // "English sentence | Türkçesi"
  })
  .strict();

const turn = z.tuple([z.string(), z.string(), z.string()]); // [konuşan, en, tr]
const option = z.tuple([z.string(), z.boolean(), z.string()]); // [en, doğru mu, neden]
export const ScenarioSchema = z
  .object({
    id,
    title: z.string(),
    sit: z.string().min(10),
    d: difficulty,
    targets: z.array(z.string()).min(1),
    turns: z.array(z.union([turn, z.object({ choose: z.array(option).min(3).max(4), q: z.string().optional() }).strict()])).min(3),
  })
  .strict();

const question = z
  .object({ q: z.string(), o: z.array(z.string()).min(3).max(4), a: z.number().int().min(0), why: z.string().min(5) })
  .strict();
export const ReadingSchema = z
  .object({
    id,
    title: z.string(),
    kind: z.string(),
    d: difficulty,
    s: z.array(z.tuple([z.string(), z.string()])).min(3), // [en, tr] cümleler
    gloss: z.array(pair).min(2),
    q: z.array(question).min(2),
  })
  .strict();

export const WritingSchema = z
  .object({ id, p: z.string().min(10), rubric: z.array(z.string()).min(2), samples: z.array(z.string()).min(1), d: difficulty })
  .strict();

export const SituationSchema = z.object({ name: z.string(), parent: z.string(), items: z.array(z.string()).min(1) }).strict();

export const PackSchema = z
  .object({
    id,
    domain: z.enum(DOMAINS),
    title: z.string(),
    desc: z.string(),
    sort: z.number().int(),
    targets: z.array(z.union([TargetSchema, TargetRefSchema])),
    patterns: z.array(PatternSchema),
    grammar: z.array(GrammarSchema),
    scenarios: z.array(ScenarioSchema),
    readings: z.array(ReadingSchema),
    writing: WritingSchema,
    situations: z.array(SituationSchema).default([]),
  })
  .strict();

export type Pack = z.infer<typeof PackSchema>;
export type Target = z.infer<typeof TargetSchema>;
export type Pattern = z.infer<typeof PatternSchema>;
