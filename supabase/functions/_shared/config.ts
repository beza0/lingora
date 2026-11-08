// Sunucu ayarları. Değerler Supabase Secrets'tan (ortam değişkeni) okunur; gizli anahtar asla istemciye gitmez.
export type AiConfig = {
  provider: string;
  apiKey: string | null;
  baseUrl: string | null;
  modelChat: string;
  modelEval: string;
  dailyChatGuest: number;
  dailyChatUser: number;
  dailyEvalGuest: number;
  dailyEvalUser: number;
  maxInputChars: number;
  maxOutputTokens: number;
  ratePerMinute: number;
  ipDailyLimit: number;
  ipHashSalt: string;
  historyLimit: number;
};

export function loadConfig(get: (k: string) => string | undefined): AiConfig {
  const int = (k: string, d: number) => {
    const v = Number.parseInt(get(k) ?? "", 10);
    return Number.isFinite(v) && v >= 0 ? v : d;
  };
  const provider = (get("AI_PROVIDER") ?? "groq").trim();
  const preset = PROVIDERS[provider];
  const keyName = preset?.keyEnv ?? "AI_API_KEY";
  const key = (get(keyName) ?? "").trim();
  return {
    provider,
    apiKey: key.length ? key : null,
    baseUrl: (get("AI_BASE_URL") ?? preset?.baseUrl ?? "").trim() || null,
    modelChat: get("AI_MODEL_CHAT") ?? preset?.model ?? "",
    modelEval: get("AI_MODEL_EVAL") ?? preset?.model ?? "",
    dailyChatGuest: int("AI_DAILY_CHAT_GUEST", 3),
    dailyChatUser: int("AI_DAILY_CHAT_USER", 20),
    dailyEvalGuest: int("AI_DAILY_EVAL_GUEST", 10),
    dailyEvalUser: int("AI_DAILY_EVAL_USER", 50),
    maxInputChars: int("AI_MAX_INPUT_CHARS", 1000),
    maxOutputTokens: int("AI_MAX_OUTPUT_TOKENS", 600),
    ratePerMinute: int("AI_RATE_PER_MINUTE", 6),
    ipDailyLimit: int("AI_IP_DAILY_LIMIT", 60),
    ipHashSalt: get("IP_HASH_SALT") ?? "lingora",
    historyLimit: 10,
  };
}

/**
 * Hazır sağlayıcılar. Varsayılan Groq'tur (ücretsiz plan). Başka bir OpenAI uyumlu servis için
 * AI_PROVIDER=openai_compat, AI_BASE_URL, AI_API_KEY ve AI_MODEL_CHAT/AI_MODEL_EVAL ayarlanır.
 */
export const PROVIDERS: Record<string, { keyEnv: string; baseUrl: string | null; model: string }> = {
  groq: { keyEnv: "GROQ_API_KEY", baseUrl: "https://api.groq.com/openai/v1", model: "openai/gpt-oss-120b" },
  anthropic: { keyEnv: "ANTHROPIC_API_KEY", baseUrl: null, model: "claude-haiku-5-5" },
  gemini: { keyEnv: "GEMINI_API_KEY", baseUrl: "https://generativelanguage.googleapis.com/v1beta/openai", model: "" }, // model adı AI Studio'dan seçilir: AI_MODEL_CHAT / AI_MODEL_EVAL
  openai_compat: { keyEnv: "AI_API_KEY", baseUrl: null, model: "" },
};

export const DOMAIN_NAMES: Record<string, string> = {
  general: "Genel İngilizce",
  software: "Yazılım İngilizcesi",
  engineering: "Mühendislik İngilizcesi",
  yds: "YDS/YÖKDİL (akademik İngilizce)",
};

/** İstanbul'da (UTC+3, yaz saati yok) bir sonraki gece yarısı. */
export function nextIstanbulMidnight(now: Date): string {
  const offsetMs = 3 * 60 * 60 * 1000;
  const local = new Date(now.getTime() + offsetMs);
  const next = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate() + 1) - offsetMs;
  return new Date(next).toISOString();
}

export async function hashIp(ip: string | null, salt: string): Promise<string | null> {
  if (!ip) return null;
  const data = new TextEncoder().encode(salt + ":" + ip);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
