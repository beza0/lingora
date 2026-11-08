// POST /functions/v1/delete-account — { confirm: true } ile hesabı ve bütün kullanıcı verisini siler.
import { CORS_HEADERS, errorResponse } from "../_shared/errors.ts";
import { handleDeleteAccount } from "../_shared/account.ts";
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
    return await handleDeleteAccount({ user: await authUser(req), body }, { db: supabaseAccountDb() });
  } catch (e) {
    console.error("delete-account:", (e as Error).message);
    return errorResponse("server_error");
  }
});
