import { describe, expect, it } from "vitest";
import { planFromCsv, parseCsv, uid, validateBundle } from "./importer";
import { canPublish, nextActions } from "./status";

describe("JSON aktarım doğrulaması", () => {
  it("yayımlanmış satırı reddeder", () => {
    const plan = validateBundle({ lexemes: [{ id: uid("x"), lemma: "x", pos: "n", status: "published" }] });
    expect(plan.issues.some((i) => i.level === "error" && i.message.includes("taslak"))).toBe(true);
  });
  it("cevap indeksi dışarıdaysa hata verir", () => {
    const plan = validateBundle({ exercises: [{ id: uid("e"), target_id: uid("t"), type: "meaning_choice", skill: "vocab", prompt: { options: ["a", "b"] }, answer: { index: 5 }, explanation_tr: "x", difficulty: 1, status: "draft" }] });
    expect(plan.issues.some((i) => i.message.includes("cevap indeksi"))).toBe(true);
  });
  it("dosyada olmayan referansı uyarı olarak bildirir", () => {
    const plan = validateBundle({ exercises: [{ id: uid("e2"), target_id: uid("yok"), type: "meaning_choice", skill: "vocab", prompt: { options: ["a", "b"] }, answer: { index: 0 }, explanation_tr: "x", difficulty: 1, status: "draft" }] });
    expect(plan.issues.filter((i) => i.level === "error")).toEqual([]);
    expect(plan.issues.some((i) => i.level === "warning")).toBe(true);
  });
  it("içerik paketindeki kimliklerle aynı UUID'yi üretir", () => {
    expect(uid("target:software:blocker")).toMatch(/^[0-9a-f-]{36}$/);
  });
});

describe("CSV aktarımı", () => {
  const header = "slug,lemma,pos,meaning_tr,example_en,example_tr,difficulty,pack_slug";
  it("tırnaklı alanları ayrıştırır", () => {
    expect(parseCsv('a,"b, c","d ""e"""\n1,2,3')).toEqual([["a", "b, c", 'd "e"'], ["1", "2", "3"]]);
  });
  it("geçerli satırdan taslak hedef üretir", () => {
    const plan = planFromCsv(`${header}\nsoftware:deploy,deploy,v,dağıtmak,"We deploy on Fridays.",Cuma günleri dağıtım yaparız.,2,software-standup`);
    expect(plan.issues.filter((i) => i.level === "error")).toEqual([]);
    expect(plan.tables.learning_targets[0]).toMatchObject({ slug: "software:deploy", status: "draft", difficulty: 2 });
  });
  it("eksik sütunu ve hatalı satırı yakalar", () => {
    expect(planFromCsv("slug,lemma\nx,y").issues[0].message).toContain("eksik sütunlar");
    const bad = planFromCsv(`${header}\nwrong,deploy,verb,,,,9,`);
    expect(bad.issues.filter((i) => i.level === "error").length).toBeGreaterThan(0);
  });
});

describe("yayın akışı", () => {
  it("taslak doğrudan yayımlanamaz", () => {
    expect(nextActions("draft").map((a) => a.to)).not.toContain("published");
    expect(canPublish("draft")).toBe(false);
    expect(canPublish("reviewed")).toBe(true);
  });
});
