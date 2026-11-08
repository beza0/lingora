// POST /functions/v1/ai-chat — akışlı AI sohbet (SSE). İş mantığı: _shared/handlers.ts
import { loadConfig } from "../_shared/config.ts";
import { CORS_HEADERS, errorResponse } from "../_shared/errors.ts";
import { handleChat } from "../_shared/handlers.ts";
import { createProvider } from "../_shared/ai/factory.ts";
import { authUser, clientIp, supabaseAiDb } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return errorResponse("invalid_request");
  const config = loadConfig((k) => Deno.env.get(k));
  const provider = createProvider(config);
  let body = {};
  try {
    body = await req.json();
  } catch {
    return errorResponse("invalid_request");
  }
  try {
    return await handleChat({ user: await authUser(req), ip: clientIp(req), body, signal: req.signal }, { config, provider, db: supabaseAiDb(), now: () => new Date() });
  } catch (e) {
    console.error("ai-chat:", (e as Error).name); // içerik günlüğe yazılmaz
    return errorResponse("server_error");
  }
});
