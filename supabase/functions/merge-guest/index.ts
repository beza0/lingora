// POST /functions/v1/merge-guest — { action: "prepare" } (misafir) / { action: "complete", token } (var olan hesap)
import { CORS_HEADERS, errorResponse } from "../_shared/errors.ts";
import { handleMerge, randomTokenHex } from "../_shared/account.ts";
import { authUser, supabaseAccountDb } from "../_shared/supabase.ts";

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
    return await handleMerge({ user: await authUser(req), body }, { db: supabaseAccountDb(), now: () => new Date(), randomToken: randomTokenHex });
  } catch (e) {
    console.error("merge-guest:", (e as Error).message);
    return errorResponse("server_error");
  }
});
