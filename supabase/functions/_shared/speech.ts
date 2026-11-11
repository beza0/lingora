// Konuşma pratiği: ses kaydını yazıya çevirir (Whisper) ve içerik cümlelerini seslendirir (önbellekli).
// Anahtar yalnız sunucuda; istemci yalnız sonucu ve herkese açık ses dosyası adresini görür.
import { type AiConfig, hashIp, nextIstanbulMidnight } from "./config.ts";
import { errorResponse, jsonResponse } from "./errors.ts";
import type { AiDb, AuthUser, QuotaKind } from "./handlers.ts";

const GROQ = "https://api.groq.com/openai/v1";
const MAX_AUDIO_BYTES = 1_500_000; // ~1 dakikalık sıkıştırılmış kayıt
const AUDIO_TYPES: Record<string, string> = {
  "audio/webm": "webm",
  "audio/ogg": "ogg",
  "audio/mp4": "m4a",
  "audio/m4a": "m4a",
  "audio/x-m4a": "m4a",
  "audio/aac": "m4a",
  "audio/mpeg": "mp3",
  "audio/wav": "wav",
  "audio/x-wav": "wav",
};

export interface AudioStore {
  exists(key: string): Promise<boolean>;
  upload(key: string, bytes: Uint8Array, contentType: string): Promise<void>;
  publicUrl(key: string): string;
}

export type SpeechDeps = { config: AiConfig; db: Pick<AiDb, "consumeQuota" | "refundQuota">; fetchFn: typeof fetch; now: () => Date };

async function quota(kind: QuotaKind, user: AuthUser, ip: string | null, deps: SpeechDeps) {
  const c = deps.config;
  const limit = kind === "speech" ? (user.isAnonymous ? c.dailySpeechGuest : c.dailySpeechUser) : (user.isAnonymous ? c.dailyTtsGuest : c.dailyTtsUser);
  // Seslendirme IP sınırını tüketmez (önbellekten sonra nadiren üretilir)
  const ipHash = kind === "speech" ? await hashIp(ip, c.ipHashSalt) : null;
  const q = await deps.db.consumeQuota({ userId: user.id, kind, limit, ipHash, ipLimit: c.ipDailyLimit, perMinute: kind === "tts" ? 30 : c.ratePerMinute });
  return { q, ipHash, limit };
}

function decodeBase64(s: string): Uint8Array | null {
  try {
    const bin = atob(s.replace(/^data:[^,]*,/, ""));
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  } catch {
    return null;
  }
}

// ------------------------------------------------------------------ ai-transcribe
export type TranscribeBody = { audio?: unknown; mime?: unknown };

export async function handleTranscribe(input: { user: AuthUser | null; ip: string | null; body: TranscribeBody }, deps: SpeechDeps): Promise<Response> {
  const { user, body } = input;
  if (!user) return errorResponse("unauthorized");
  if (!deps.config.groqKey) return errorResponse("ai_not_configured");
  const mime = typeof body.mime === "string" ? body.mime.split(";")[0].trim().toLowerCase() : "";
  const ext = AUDIO_TYPES[mime];
  if (!ext || typeof body.audio !== "string") return errorResponse("invalid_request");
  const bytes = decodeBase64(body.audio);
  if (!bytes || bytes.length < 200) return errorResponse("invalid_request");
  if (bytes.length > MAX_AUDIO_BYTES) return errorResponse("too_long", { max_bytes: MAX_AUDIO_BYTES });

  const { q, ipHash, limit } = await quota("speech", user, input.ip, deps);
  if (!q.allowed) {
    if (q.reason === "rate_limited") return errorResponse("rate_limited");
    return errorResponse("quota_exceeded", { limit, resets_at: nextIstanbulMidnight(deps.now()), guest: user.isAnonymous });
  }

  const form = new FormData();
  form.append("file", new Blob([bytes.buffer as ArrayBuffer], { type: mime }), `speech.${ext}`);
  form.append("model", deps.config.sttModel);
  form.append("language", "en");
  form.append("temperature", "0");
  form.append("response_format", "json");
  // Beklenen cümle bilerek gönderilmez: model duyduğunu yazmalı, doğru cevabı tahmin etmemeli.
  try {
    const res = await deps.fetchFn(`${GROQ}/audio/transcriptions`, { method: "POST", headers: { authorization: `Bearer ${deps.config.groqKey}` }, body: form });
    if (!res.ok) throw new Error(`stt ${res.status}`);
    const data = await res.json() as { text?: string };
    return jsonResponse({ text: (data.text ?? "").trim(), used: q.used, limit });
  } catch (e) {
    console.error("ai-transcribe:", (e as Error).message);
    await deps.db.refundQuota(user.id, "speech", ipHash);
    return errorResponse("provider_error");
  }
}

// ------------------------------------------------------------------ ai-tts
export type TtsBody = { text?: unknown };

export async function ttsKey(model: string, voice: string, text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${model}|${voice}|${text}`));
  const hex = Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
  return `v1/${hex.slice(0, 2)}/${hex}.wav`;
}

export async function handleTts(input: { user: AuthUser | null; body: TtsBody }, deps: SpeechDeps & { store: AudioStore }): Promise<Response> {
  const { user, body } = input;
  if (!user) return errorResponse("unauthorized");
  const text = typeof body.text === "string" ? body.text.replace(/\s+/g, " ").trim() : "";
  if (!text || text.length > 200) return errorResponse("invalid_request");
  const key = await ttsKey(deps.config.ttsModel, deps.config.ttsVoice, text);
  if (await deps.store.exists(key)) return jsonResponse({ url: deps.store.publicUrl(key), cached: true });
  if (!deps.config.groqKey) return errorResponse("ai_not_configured");

  const { q, limit } = await quota("tts", user, null, deps);
  if (!q.allowed) {
    if (q.reason === "rate_limited") return errorResponse("rate_limited");
    return errorResponse("quota_exceeded", { limit, resets_at: nextIstanbulMidnight(deps.now()), guest: user.isAnonymous });
  }
  try {
    const res = await deps.fetchFn(`${GROQ}/audio/speech`, {
      method: "POST",
      headers: { authorization: `Bearer ${deps.config.groqKey}`, "content-type": "application/json" },
      body: JSON.stringify({ model: deps.config.ttsModel, voice: deps.config.ttsVoice, input: text, response_format: "wav" }),
    });
    if (!res.ok) throw new Error(`tts ${res.status} ${(await res.text()).slice(0, 200)}`);
    const bytes = new Uint8Array(await res.arrayBuffer());
    if (bytes.length < 100) throw new Error("tts empty");
    await deps.store.upload(key, bytes, "audio/wav");
    return jsonResponse({ url: deps.store.publicUrl(key), cached: false });
  } catch (e) {
    console.error("ai-tts:", (e as Error).message);
    await deps.db.refundQuota(user.id, "tts", null);
    return errorResponse("provider_error");
  }
}
