import { describe, expect, it } from "vitest";
import { loadConfig } from "../_shared/config.ts";
import { type AudioStore, handleTranscribe, handleTts, ttsKey } from "../_shared/speech.ts";
import type { QuotaResult } from "../_shared/handlers.ts";

const USER = { id: "u1", isAnonymous: false };
const GUEST = { id: "g1", isAnonymous: true };
const config = (extra: Record<string, string> = {}) => loadConfig((k) => ({ GROQ_API_KEY: "k", ...extra } as Record<string, string>)[k]);

class Db {
  calls: { kind: string; limit: number }[] = [];
  refunds: string[] = [];
  next: QuotaResult = { allowed: true, used: 1, limit: 60 };
  consumeQuota(a: { kind: string; limit: number }) {
    this.calls.push({ kind: a.kind, limit: a.limit });
    return Promise.resolve(this.next);
  }
  refundQuota(_u: string, kind: string) {
    this.refunds.push(kind);
    return Promise.resolve();
  }
}
class Store implements AudioStore {
  files = new Map<string, Uint8Array>();
  exists(k: string) { return Promise.resolve(this.files.has(k)); }
  upload(k: string, b: Uint8Array) { this.files.set(k, b); return Promise.resolve(); }
  publicUrl(k: string) { return `https://x/${k}`; }
}
const audio = btoa("x".repeat(600));

describe("konuşma → yazı", () => {
  it("kaydı Groq'a gönderir, beklenen cümleyi göndermez, metni döner", async () => {
    const db = new Db();
    let sent: FormData | null = null;
    const fetchFn = (async (_u: string, init: RequestInit) => {
      sent = init.body as FormData;
      return new Response(JSON.stringify({ text: " I fixed the bug. " }), { status: 200 });
    }) as unknown as typeof fetch;
    const r = await handleTranscribe({ user: USER, ip: null, body: { audio, mime: "audio/webm;codecs=opus" } }, { config: config(), db, fetchFn, now: () => new Date() });
    expect(r.status).toBe(200);
    expect((await r.json()).text).toBe("I fixed the bug.");
    expect(sent!.get("language")).toBe("en");
    expect(sent!.get("prompt")).toBeNull();
    expect(db.calls[0]).toEqual({ kind: "speech", limit: 60 });
  });

  it("geçersiz tür, anahtar yokluğu ve sağlayıcı hatası (kota iadesi)", async () => {
    const db = new Db();
    const ok = (async () => new Response("x", { status: 500 })) as unknown as typeof fetch;
    expect((await handleTranscribe({ user: GUEST, ip: null, body: { audio, mime: "video/mp4" } }, { config: config(), db, fetchFn: ok, now: () => new Date() })).status).toBe(400);
    expect((await handleTranscribe({ user: GUEST, ip: null, body: { audio, mime: "audio/webm" } }, { config: loadConfig(() => undefined), db, fetchFn: ok, now: () => new Date() })).status).toBe(503);
    const r = await handleTranscribe({ user: GUEST, ip: null, body: { audio, mime: "audio/webm" } }, { config: config(), db, fetchFn: ok, now: () => new Date() });
    expect(r.status).toBe(502);
    expect(db.refunds).toEqual(["speech"]);
    expect(db.calls.at(-1)!.limit).toBe(20);
  });
});

describe("seslendirme", () => {
  it("ilk istekte üretip saklar, ikincide önbellekten verir ve kota harcamaz", async () => {
    const db = new Db();
    const store = new Store();
    let calls = 0;
    const fetchFn = (async () => {
      calls++;
      return new Response(new Uint8Array(500), { status: 200 });
    }) as unknown as typeof fetch;
    const deps = { config: config(), db, store, fetchFn, now: () => new Date() };
    const a = await (await handleTts({ user: GUEST, body: { text: "  My only blocker  is the missing key. " } }, deps)).json();
    const b = await (await handleTts({ user: GUEST, body: { text: "My only blocker is the missing key." } }, deps)).json();
    expect(a.cached).toBe(false);
    expect(b.cached).toBe(true);
    expect(a.url).toBe(b.url);
    expect(calls).toBe(1);
    expect(db.calls).toEqual([{ kind: "tts", limit: 60 }]);
    expect(a.url).toBe(`https://x/${await ttsKey("canopylabs/orpheus-v1-english", "hannah", "My only blocker is the missing key.")}`);
  });

  it("uzun metni reddeder", async () => {
    const r = await handleTts({ user: USER, body: { text: "a".repeat(201) } }, { config: config(), db: new Db(), store: new Store(), fetchFn: fetch, now: () => new Date() });
    expect(r.status).toBe(400);
  });
});
