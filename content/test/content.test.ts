import { describe, expect, it } from "vitest";
import { mkdtempSync, writeFileSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { buildBundle, loadPacks, uid, detOrder, type Issue } from "../scripts/lib/build.ts";
import { validate } from "../scripts/lib/validate.ts";
import { run, PACKS_DIR } from "../scripts/common.ts";

describe("gerçek içerik", () => {
  const { bundle, report } = run(true);

  it("doğrulamadan hatasız geçer", () => {
    expect(report.issues.filter((i) => i.level === "error")).toEqual([]);
  });

  it("istenen toplamları karşılar", () => {
    expect(report.totals).toMatchObject({ packs: 15, targets: 300, patterns: 150, scenarios: 30, readings: 30, grammar: 30, writing: 15 });
  });

  it("her seçenekli alıştırmada cevap indeksi doğru seçeneği gösterir", () => {
    for (const ex of bundle.exercises) {
      const p = ex.prompt as { options?: string[] };
      const a = ex.answer as { index?: number; text?: string };
      if (p.options && a.text) expect(p.options[a.index!]).toBe(a.text);
    }
  });

  it("kimlikler deterministiktir", () => {
    const again = run(true).bundle;
    expect(again.learning_targets.map((t) => t.id)).toEqual(bundle.learning_targets.map((t) => t.id));
    expect(again.content_version).toBe(bundle.content_version);
  });

  it("bütün içerik taslak olarak üretilir", () => {
    const tables = ["packs", "lexemes", "senses", "learning_targets", "exercises", "scenarios", "readings"] as const;
    for (const t of tables) for (const r of bundle[t]) expect(r.status).toBe("draft");
  });
});

describe("doğrulayıcı kuralları", () => {
  function tmpPack(yaml: string) {
    const dir = mkdtempSync(join(tmpdir(), "lingora-"));
    mkdirSync(join(dir, "software"));
    writeFileSync(join(dir, "software", "p.yaml"), yaml);
    const issues: Issue[] = [];
    const loaded = loadPacks(dir, issues);
    const bundle = buildBundle(loaded, issues);
    validate(loaded, bundle, issues, { requireTotals: false });
    return issues.filter((i) => i.level === "error").map((i) => i.message);
  }
  const target = (id: string, tr: string, extra = "") => `
  - id: ${id}
    w: ${id}
    pos: n
    tr: "${tr}"
    ex: "This is the [[${id}]] here."
    extr: "Örnek ${id}."
    d: 1
    tone: ["Test"]
    dis: ["aaa | x", "bbb | y", "ccc | z"]${extra}`;
  const base = (targets: string) => `id: test-pack
domain: software
title: T
desc: D
sort: 1
targets:${targets}
patterns: []
grammar: []
scenarios: []
readings: []
writing: { id: wr, p: "Bir şey yaz lütfen.", rubric: ["a", "b"], samples: ["x"], d: 1 }
`;

  it("aynı Türkçe anlamı iki hedefte yakalar", () => {
    const errs = tmpPack(base(target("alpha", "aynı anlam") + target("beta", "aynı anlam")));
    expect(errs.some((m) => m.includes("aynı Türkçe anlam"))).toBe(true);
  });

  it("çeldirici doğru cevapla aynıysa yakalar", () => {
    const errs = tmpPack(base(`
  - id: gamma
    w: gamma
    pos: n
    tr: "gamma anlamı"
    ex: "A [[gamma]] b."
    extr: "gamma örneği."
    d: 1
    tone: ["T"]
    dis: ["gamma | aynı", "bbb | y", "ccc | z"]`));
    expect(errs.some((m) => m.includes("çeldirici"))).toBe(true);
  });

  it("işaretsiz örnek cümleyi reddeder", () => {
    const errs = tmpPack(base(`
  - id: delta
    w: delta
    pos: n
    tr: "delta anlamı"
    ex: "No marker here."
    extr: "delta örneği."
    d: 1
    tone: ["T"]
    dis: ["aaa | x", "bbb | y", "ccc | z"]`));
    expect(errs.some((m) => m.includes("[[...]]"))).toBe(true);
  });

  it("paket sayılarını denetler", () => {
    const errs = tmpPack(base(target("eps", "eps anlamı")));
    expect(errs.some((m) => m.includes("20 hedef"))).toBe(true);
  });
});

describe("yardımcılar", () => {
  it("uuid v5 sabittir", () => {
    expect(uid("target:software:blocker")).toBe(uid("target:software:blocker"));
    expect(uid("a")).not.toBe(uid("b"));
  });
  it("karıştırma belirlenimcidir", () => {
    expect(detOrder([1, 2, 3, 4], "s")).toEqual(detOrder([1, 2, 3, 4], "s"));
  });
  it("paket klasörü var", () => {
    expect(PACKS_DIR.endsWith("packs")).toBe(true);
  });
});
