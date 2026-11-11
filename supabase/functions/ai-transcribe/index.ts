// POST /functions/v1/ai-transcribe — konuşma kaydını yazıya çevirir. İş mantığı: _shared/speech.ts
import { loadConfig } from "../_shared/config.ts";
import { CORS_HEADERS, errorResponse } from "../_shared/errors.ts";
import { handleTranscribe } from "../_shared/speech.ts";
import { authUser, clientIp, supabaseAiDb } from "../_shared/supabase.ts";

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
    return await handleTranscribe({ user: await authUser(req), ip: clientIp(req), body }, { config, db: supabaseAiDb(), fetchFn: fetch, now: () => new Date() });
  } catch (e) {
    console.error("ai-transcribe:", (e as Error).name);
    return errorResponse("server_error");
  }
});
