import { describe, expect, it } from "vitest";
import { loadConfig, nextIstanbulMidnight } from "../_shared/config.ts";
import { type AiDb, handleChat, handleEvaluate, type QuotaResult } from "../_shared/handlers.ts";
import { type AiProvider, type CompletionRequest, ProviderError, type StreamEvent } from "../_shared/ai/provider.ts";
import { AnthropicProvider } from "../_shared/ai/anthropic.ts";
import { localCheck, normalizeAnswer, parseEvaluation } from "../_shared/evaluation.ts";
import { type AccountDb, handleDeleteAccount, handleMerge, sha256Hex } from "../_shared/account.ts";

const USER = { id: "00000000-0000-0000-0000-0000000000a1", isAnonymous: false };
const GUEST = { id: "00000000-0000-0000-0000-0000000000b1", isAnonymous: true };
const THREAD = "11111111-1111-4111-8111-111111111111";

class FakeDb implements AiDb {
  used = 0;
  refunds = 0;
  tokens: number[] = [];
  messages: { threadId: string; role: string; content: string }[] = [];
  threads = new Map<string, { id: string; domain_id: string | null; user: string }>();
  quota: (limit: number) => QuotaResult = (limit) => (this.used < limit ? { allowed: true, used: ++this.used, limit } : { allowed: false, reason: "quota_exceeded" });
  lastLimit = 0;
  async consumeQuota(a: { limit: number }) { this.lastLimit = a.limit; return this.quota(a.limit); }
  async refundQuota() { this.refunds++; this.used = Math.max(0, this.used - 1); }
  async recordTokens(_u: string, _k: string, i: number, o: number) { this.tokens.push(i, o); }
  async findThread(id: string, user: string) { const t = this.threads.get(id); return t && t.user === user ? { id: t.id, domain_id: t.domain_id } : null; }
  async createThread(user: string, domain: string | null) { const id = crypto.randomUUID(); this.threads.set(id, { id, domain_id: domain, user }); return id; }
  async recentMessages(threadId: string, limit: number) {
    return this.messages.filter((m) => m.threadId === threadId).slice(-limit).map((m) => ({ role: m.role as "user" | "assistant", content: m.content }));
  }
  async insertMessage(m: { threadId: string; role: "user" | "assistant"; content: string }) { this.messages.push({ threadId: m.threadId, role: m.role, content: m.content }); }
}

class FakeProvider implements AiProvider {
  readonly name = "fake";
  lastRequest: CompletionRequest | null = null;
  constructor(private chunks: string[] = ["<en>Could you rename this variable?</en>", " Nazik bir istek."], private failAt = -1, private completions: string[] = []) {}
  async *streamChat(req: CompletionRequest): AsyncIterable<StreamEvent> {
    this.lastRequest = req;
    for (let i = 0; i < this.chunks.length; i++) {
      if (i === this.failAt) throw new ProviderError("kesildi");
      yield { type: "text", text: this.chunks[i] };
    }
    if (this.failAt === this.chunks.length) throw new ProviderError("kesildi");
    yield { type: "usage", inputTokens: 12, outputTokens: 34 };
  }
  async complete(req: CompletionRequest) {
    this.lastRequest = req;
    const t = this.completions.shift();
    if (t === undefined) throw new ProviderError("yok");
    return { text: t, inputTokens: 5, outputTokens: 7 };
  }
}

const config = (extra: Record<string, string> = {}) => loadConfig((k) => ({ GROQ_API_KEY: "test-key", ...extra } as Record<string, string>)[k]);
const deps = (db: FakeDb, provider: AiProvider | null, cfg = config()) => ({ config: cfg, provider, db, now: () => new Date("2026-11-08T10:00:00Z") });

async function readSse(res: Response) {
  const text = await res.text();
  return text.split("\n\n").filter(Boolean).map((block) => {
    const ev = /event: (.*)/.exec(block)![1];
    const data = JSON.parse(/data: (.*)/.exec(block)![1]);
    return { ev, data };
  });
}

describe("ai-chat", () => {
  it("oturum yoksa 401", async () => {
    const r = await handleChat({ user: null, ip: null, body: { message: "hi" } }, deps(new FakeDb(), new FakeProvider()));
    expect(r.status).toBe(401);
  });

  it("anahtar yoksa sahte yanıt üretmez: 503 ai_not_configured ve kota düşmez", async () => {
    const db = new FakeDb();
    const r = await handleChat({ user: USER, ip: null, body: { message: "hi" } }, deps(db, null, loadConfig(() => undefined)));
    expect(r.status).toBe(503);
    expect((await r.json()).error.code).toBe("ai_not_configured");
    expect(db.used).toBe(0);
  });

  it("uzun mesajı reddeder", async () => {
    const r = await handleChat({ user: USER, ip: null, body: { message: "a".repeat(1001) } }, deps(new FakeDb(), new FakeProvider()));
    expect(r.status).toBe(413);
  });

  it("akışı iletir, mesajları kaydeder, kullanımı yazar", async () => {
    const db = new FakeDb();
    const r = await handleChat({ user: USER, ip: "1.2.3.4", body: { message: "Kod incelemesinde nasıl derim?", domain_id: "software" } }, deps(db, new FakeProvider()));
    expect(r.headers.get("Content-Type")).toContain("text/event-stream");
    const events = await readSse(r);
    expect(events[0].ev).toBe("meta");
    expect(events.filter((e) => e.ev === "delta").map((e) => e.data.text).join("")).toContain("Could you rename");
    expect(events.at(-1)!.ev).toBe("done");
    expect(db.messages.map((m) => m.role)).toEqual(["user", "assistant"]);
    expect(db.tokens).toEqual([12, 34]);
    expect(db.lastLimit).toBe(20);
  });

  it("misafir için misafir kotası uygulanır ve dolunca 429 + sıfırlanma saati döner", async () => {
    const db = new FakeDb();
    const d = deps(db, new FakeProvider());
    for (let i = 0; i < 3; i++) await (await handleChat({ user: GUEST, ip: null, body: { message: "hi" } }, d)).text();
    const r = await handleChat({ user: GUEST, ip: null, body: { message: "hi" } }, d);
    expect(r.status).toBe(429);
    const body = await r.json();
    expect(body.error.code).toBe("quota_exceeded");
    expect(body.error.limit).toBe(3);
    expect(body.error.guest).toBe(true);
    expect(body.error.resets_at).toBe("2026-11-08T21:00:00.000Z");
  });

  it("dakika sınırında rate_limited döner", async () => {
    const db = new FakeDb();
    db.quota = () => ({ allowed: false, reason: "rate_limited" });
    const r = await handleChat({ user: USER, ip: null, body: { message: "hi" } }, deps(db, new FakeProvider()));
    expect((await r.json()).error.code).toBe("rate_limited");
  });

  it("sağlayıcı baştan hata verirse 502 döner, kota iade edilir, hiçbir mesaj kaydedilmez", async () => {
    const db = new FakeDb();
    const r = await handleChat({ user: USER, ip: null, body: { message: "hi" } }, deps(db, new FakeProvider(["x"], 0)));
    expect(r.status).toBe(502);
    expect(db.refunds).toBe(1);
    expect(db.messages).toEqual([]);
  });

  it("akış ortasında kesilirse hata olayı gönderir ve gelen kısmı kaydeder", async () => {
    const db = new FakeDb();
    const r = await handleChat({ user: USER, ip: null, body: { message: "hi" } }, deps(db, new FakeProvider(["Merhaba", " dünya"], 2)));
    const events = await readSse(r);
    expect(events.at(-1)!.ev).toBe("error");
    expect(db.messages.at(-1)!.content).toBe("Merhaba dünya");
    expect(db.refunds).toBe(0);
  });

  it("başkasının sohbetine yazılamaz", async () => {
    const db = new FakeDb();
    db.threads.set(THREAD, { id: THREAD, domain_id: null, user: "someone-else" });
    const r = await handleChat({ user: USER, ip: null, body: { message: "hi", thread_id: THREAD } }, deps(db, new FakeProvider()));
    expect(r.status).toBe(404);
  });

  it("geçmişin tamamı değil, son 10 mesaj gönderilir", async () => {
    const db = new FakeDb();
    db.threads.set(THREAD, { id: THREAD, domain_id: "general", user: USER.id });
    for (let i = 0; i < 30; i++) db.messages.push({ threadId: THREAD, role: i % 2 ? "assistant" : "user", content: "m" + i });
    const p = new FakeProvider();
    await (await handleChat({ user: USER, ip: null, body: { message: "yeni", thread_id: THREAD } }, deps(db, p))).text();
    expect(p.lastRequest!.messages.length).toBe(11);
    expect(p.lastRequest!.system).toContain("Genel İngilizce");
  });

  it("öğrenme ekranından gelen bağlam sistem yönergesine eklenir", async () => {
    const p = new FakeProvider();
    await (await handleChat({ user: USER, ip: null, body: { message: "bu ne demek?", domain_id: "software", context: { kind: "target", text: "reproduce", meaning_tr: "yeniden oluşturmak" } } }, deps(new FakeDb(), p))).text();
    expect(p.lastRequest!.system).toContain("reproduce");
    expect(p.lastRequest!.system).toContain("Yazılım");
  });
});

const VALID_EVAL = JSON.stringify({ verdict: "minor_error", meaning_ok: true, spelling_issues: [{ wrong: "logn", right: "login" }], corrected: "I'm working on the login page.", alternatives: [], explanation_tr: "Küçük bir yazım hatası var." });

describe("ai-evaluate", () => {
  const task = { skill: "writing" as const, prompt_tr: "Giriş sayfası üzerinde çalışıyorum.", expected: "I'm working on the login page.", accepted: ["I am working on the login page."] };

  it("birebir doğru cevapta AI çağrılmaz ve kota düşmez", async () => {
    const db = new FakeDb();
    const r = await handleEvaluate({ user: USER, ip: null, body: { task: { ...task, answer: "I am working on the login page" } } }, deps(db, new FakeProvider()));
    expect(await r.json()).toMatchObject({ source: "local", outcome: "correct" });
    expect(db.used).toBe(0);
  });

  it("küçük yazım hatası yerelde ayrı değerlendirilir", async () => {
    const r = await handleEvaluate({ user: USER, ip: null, body: { task: { ...task, answer: "I'm working on the logn page." } } }, deps(new FakeDb(), new FakeProvider()));
    expect(await r.json()).toMatchObject({ source: "local", outcome: "minor_spelling" });
  });

  it("yerelde karar verilemezse AI yapılandırılmış çıktısı doğrulanıp döner", async () => {
    const db = new FakeDb();
    const r = await handleEvaluate({ user: USER, ip: null, body: { task: { ...task, answer: "Currently I develop the page for login." } } }, deps(db, new FakeProvider([], -1, [VALID_EVAL])));
    const b = await r.json();
    expect(b.source).toBe("ai");
    expect(b.evaluation.verdict).toBe("minor_error");
    expect(db.used).toBe(1);
  });

  it("şema dışı çıktı iki kez gelirse 422 ve kota iadesi", async () => {
    const db = new FakeDb();
    const r = await handleEvaluate({ user: USER, ip: null, body: { task: { ...task, answer: "something else entirely" } } }, deps(db, new FakeProvider([], -1, ["olmaz", "{bozuk"])));
    expect(r.status).toBe(422);
    expect(db.refunds).toBe(1);
  });

  it("anahtar yokken ve yerel kontrol yetmezken 503", async () => {
    const r = await handleEvaluate({ user: USER, ip: null, body: { task: { ...task, answer: "something else" } } }, deps(new FakeDb(), null, loadConfig(() => undefined)));
    expect(r.status).toBe(503);
  });

  it("sağlayıcı hatasında 502 ve kota iadesi", async () => {
    const db = new FakeDb();
    const r = await handleEvaluate({ user: USER, ip: null, body: { task: { ...task, answer: "something else" } } }, deps(db, new FakeProvider([], -1, [])));
    expect(r.status).toBe(502);
    expect(db.refunds).toBe(1);
  });
});

describe("değerlendirme yardımcıları", () => {
  it("anlam yanlışken correct verdiği tutarsız çıktıyı reddeder", () => {
    expect(parseEvaluation(JSON.stringify({ verdict: "correct", meaning_ok: false, spelling_issues: [], corrected: "x", alternatives: [], explanation_tr: "x" }))).toBeNull();
  });
  it("metin içindeki JSON'u ayıklar", () => {
    expect(parseEvaluation("Sonuç: " + VALID_EVAL)!.verdict).toBe("minor_error");
  });
  it("kısaltmaları ve noktalamayı normalleştirir", () => {
    expect(normalizeAnswer("I am working on it.")).toBe(normalizeAnswer("I’m working on it"));
    expect(localCheck("i dont know", ["I don't know."]).outcome).toBe("minor_spelling");
  });
  it("İstanbul gece yarısını hesaplar", () => {
    expect(nextIstanbulMidnight(new Date("2026-11-08T22:30:00Z"))).toBe("2026-11-09T21:00:00.000Z");
  });
});

describe("rol yapma yönergesi", () => {
  it("rol yapma bağlamında karşı tarafı oynar ve geri bildirim ister", async () => {
    const { chatSystemPrompt } = await import("../_shared/prompts.ts");
    const p = chatSystemPrompt("software", { kind: "roleplay", text: "You are the team lead in a daily stand-up.", meaning_tr: "Dünkü işini anlat", pack_title: "Stand-up toplantısı" });
    expect(p).toContain("rol yapma");
    expect(p).toContain("You are the team lead");
    expect(p).toContain("Geri bildirim:");
    expect(p).toContain("Yazılım İngilizcesi");
    const normal = chatSystemPrompt("software", { kind: "target", text: "blocker" });
    expect(normal).not.toContain("Geri bildirim:");
  });
});

describe("Anthropic sağlayıcısı", () => {
  it("SSE akışını metin ve kullanım olaylarına çevirir", async () => {
    const sse = [
      'event: message_start\ndata: {"type":"message_start","message":{"usage":{"input_tokens":9}}}\n\n',
      'event: content_block_delta\ndata: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hel"}}\n\n',
      'event: content_block_delta\ndata: {"type":"content_block_delta","delta":{"type":"text_delta","text":"lo"}}\n\n',
      'event: message_delta\ndata: {"type":"message_delta","usage":{"output_tokens":4}}\n\n',
    ];
    let sentHeaders: Record<string, string> = {};
    const fakeFetch = (async (_url: string, init: RequestInit) => {
      sentHeaders = init.headers as Record<string, string>;
      return new Response(new ReadableStream({ start(c) { for (const s of sse) c.enqueue(new TextEncoder().encode(s)); c.close(); } }), { status: 200 });
    }) as unknown as typeof fetch;
    const p = new AnthropicProvider("k", fakeFetch);
    const out: StreamEvent[] = [];
    for await (const e of p.streamChat({ model: "m", system: "s", messages: [{ role: "user", content: "hi" }], maxTokens: 10 })) out.push(e);
    expect(out).toEqual([{ type: "text", text: "Hel" }, { type: "text", text: "lo" }, { type: "usage", inputTokens: 9, outputTokens: 4 }]);
    expect(sentHeaders["x-api-key"]).toBe("k");
  });
  it("HTTP hatasını ProviderError'a çevirir", async () => {
    const p = new AnthropicProvider("k", (async () => new Response("x", { status: 529 })) as unknown as typeof fetch);
    await expect(p.complete({ model: "m", system: "s", messages: [], maxTokens: 1 })).rejects.toBeInstanceOf(ProviderError);
  });
});

describe("misafir birleştirme ve hesap silme", () => {
  class FakeAccountDb implements AccountDb {
    tokens = new Map<string, { anon: string; exp: string }>();
    merged: [string, string][] = [];
    deleted: string[] = [];
    async saveMergeToken(anon: string, hash: string, exp: string) { this.tokens.set(hash, { anon, exp }); }
    async findMergeToken(hash: string, now: Date) { const t = this.tokens.get(hash); return t && new Date(t.exp) > now ? { anonUserId: t.anon } : null; }
    async mergeGuest(a: string, b: string) { this.merged.push([a, b]); return { events: 3 }; }
    async deleteAuthUser(id: string) { this.deleted.push(id); for (const [k, v] of this.tokens) if (v.anon === id) this.tokens.delete(k); }
  }
  let clock = new Date("2026-11-08T10:00:00Z");
  const accDeps = (db: FakeAccountDb) => ({ db, now: () => clock, randomToken: () => "a".repeat(64) });

  it("belirteci yalnız misafir alabilir", async () => {
    expect((await handleMerge({ user: USER, body: { action: "prepare" } }, accDeps(new FakeAccountDb()))).status).toBe(403);
  });

  it("misafir verisini hesaba birleştirir ve misafiri siler", async () => {
    const db = new FakeAccountDb();
    const prep = await (await handleMerge({ user: GUEST, body: { action: "prepare" } }, accDeps(db))).json();
    expect(db.tokens.has(await sha256Hex(prep.token))).toBe(true);
    const done = await (await handleMerge({ user: USER, body: { action: "complete", token: prep.token } }, accDeps(db))).json();
    expect(done).toMatchObject({ merged: true, counts: { events: 3 } });
    expect(db.merged).toEqual([[GUEST.id, USER.id]]);
    expect(db.deleted).toEqual([GUEST.id]);
    // aynı belirteç tekrar kullanılamaz
    expect((await handleMerge({ user: USER, body: { action: "complete", token: prep.token } }, accDeps(db))).status).toBe(404);
  });

  it("süresi geçmiş belirteci reddeder", async () => {
    const db = new FakeAccountDb();
    const prep = await (await handleMerge({ user: GUEST, body: { action: "prepare" } }, accDeps(db))).json();
    clock = new Date(clock.getTime() + 16 * 60 * 1000);
    expect((await handleMerge({ user: USER, body: { action: "complete", token: prep.token } }, accDeps(db))).status).toBe(404);
  });

  it("hesap silme açık onay ister", async () => {
    const db = new FakeAccountDb();
    expect((await handleDeleteAccount({ user: USER, body: {} }, { db })).status).toBe(400);
    expect((await handleDeleteAccount({ user: USER, body: { confirm: true } }, { db })).status).toBe(200);
    expect(db.deleted).toEqual([USER.id]);
  });
});
