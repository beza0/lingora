// POST /functions/v1/ai-tts — İngilizce metni seslendirir; aynı metin bir kez üretilir, sonra önbellekten gelir.
import { loadConfig } from "../_shared/config.ts";
import { CORS_HEADERS, errorResponse } from "../_shared/errors.ts";
import { handleTts } from "../_shared/speech.ts";
import { authUser, supabaseAiDb, supabaseAudioStore } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return errorResponse("invalid_request");
  let body = {};
  try {
    body = await req.json();
  } catch {
    return errorResponse("invalid_request");
  }
  try {
    const config = loadConfig((k) => Deno.env.get(k));
    return await handleTts({ user: await authUser(req), body }, { config, db: supabaseAiDb(), store: supabaseAudioStore(), fetchFn: fetch, now: () => new Date() });
  } catch (e) {
    console.error("ai-tts:", (e as Error).name);
    return errorResponse("server_error");
  }
});
