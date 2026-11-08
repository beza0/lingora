// Uygulamanın anlayacağı hata kodları. Mesajlar Türkçe ve kullanıcıya gösterilebilir.
export type ErrorCode =
  | "unauthorized"
  | "invalid_request"
  | "too_long"
  | "ai_not_configured"
  | "rate_limited"
  | "quota_exceeded"
  | "provider_error"
  | "invalid_output"
  | "not_found"
  | "forbidden"
  | "server_error";

const STATUS: Record<ErrorCode, number> = {
  unauthorized: 401,
  invalid_request: 400,
  too_long: 413,
  ai_not_configured: 503,
  rate_limited: 429,
  quota_exceeded: 429,
  provider_error: 502,
  invalid_output: 422,
  not_found: 404,
  forbidden: 403,
  server_error: 500,
};

export const MESSAGES: Record<ErrorCode, string> = {
  unauthorized: "Oturum doğrulanamadı. Uygulamayı yeniden açmayı dene.",
  invalid_request: "İstek eksik veya hatalı.",
  too_long: "Mesaj çok uzun. Daha kısa yazmayı dene.",
  ai_not_configured: "AI henüz yapılandırılmadı. Hazır içeriklerle çalışmaya devam edebilirsin.",
  rate_limited: "Çok hızlı istek gönderildi. Biraz bekleyip tekrar dene.",
  quota_exceeded: "Bugünkü AI hakkın doldu.",
  provider_error: "AI şu an yanıt veremiyor. Kotan düşmedi; biraz sonra tekrar dene.",
  invalid_output: "AI geçerli bir değerlendirme üretemedi. Seçenekli soruyla devam edebilirsin.",
  not_found: "Kayıt bulunamadı.",
  forbidden: "Bu işlem için yetkin yok.",
  server_error: "Beklenmeyen bir hata oluştu.",
};

export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function errorResponse(code: ErrorCode, extra: Record<string, unknown> = {}): Response {
  return new Response(JSON.stringify({ error: { code, message: MESSAGES[code], ...extra } }), {
    status: STATUS[code],
    headers: { ...CORS_HEADERS, "Content-Type": "application/json; charset=utf-8" },
  });
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json; charset=utf-8" },
  });
}
