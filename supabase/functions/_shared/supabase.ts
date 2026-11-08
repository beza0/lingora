// Gerçek Supabase bağımlılıkları (yalnız Deno giriş dosyaları kullanır). Service-role anahtarı yalnız burada, sunucuda.
// deno-lint-ignore-file no-explicit-any
import { createClient } from "npm:@supabase/supabase-js@2";
import type { AiDb, AuthUser } from "./handlers.ts";
import type { AccountDb } from "./account.ts";

const env = (k: string) => Deno.env.get(k);

export function serviceClient() {
  const url = env("SUPABASE_URL");
  const key = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY eksik");
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}

/** İsteğin JWT'sini doğrular. Anonim (misafir) kullanıcılar da geçerlidir. */
export async function authUser(req: Request): Promise<AuthUser | null> {
  const header = req.headers.get("Authorization") ?? "";
  const jwt = header.replace(/^Bearer\s+/i, "");
  if (!jwt) return null;
  const { data, error } = await serviceClient().auth.getUser(jwt);
  if (error || !data?.user) return null;
  return { id: data.user.id, isAnonymous: Boolean((data.user as any).is_anonymous) };
}

export function clientIp(req: Request): string | null {
  return req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || req.headers.get("cf-connecting-ip") || null;
}

export function supabaseAiDb(): AiDb {
  const db = serviceClient();
  const must = <T>(r: { data: T; error: any }) => {
    if (r.error) throw new Error(r.error.message);
    return r.data;
  };
  return {
    async consumeQuota(a) {
      const data = must(await db.rpc("consume_ai_quota", {
        p_user: a.userId, p_kind: a.kind, p_limit: a.limit, p_ip_hash: a.ipHash, p_ip_limit: a.ipLimit, p_per_minute: a.perMinute,
      })) as any;
      return { allowed: Boolean(data?.allowed), reason: data?.reason, used: data?.used, limit: data?.limit };
    },
    async refundQuota(userId, kind, ipHash) {
      must(await db.rpc("refund_ai_quota", { p_user: userId, p_kind: kind, p_ip_hash: ipHash }));
    },
    async recordTokens(userId, kind, input, output) {
      must(await db.rpc("record_ai_tokens", { p_user: userId, p_kind: kind, p_in: input, p_out: output }));
    },
    async findThread(threadId, userId) {
      const data = must(await db.from("chat_threads").select("id,domain_id").eq("id", threadId).eq("user_id", userId).maybeSingle());
      return (data as any) ?? null;
    },
    async createThread(userId, domainId, title) {
      const id = crypto.randomUUID();
      must(await db.from("chat_threads").insert({ id, user_id: userId, domain_id: domainId, title }));
      return id;
    },
    async recentMessages(threadId, limit) {
      const data = must(await db.from("chat_messages").select("role,content").eq("thread_id", threadId)
        .order("created_at", { ascending: false }).limit(limit)) as any[];
      return data.reverse().map((m) => ({ role: m.role, content: m.content }));
    },
    async insertMessage(m) {
      must(await db.from("chat_messages").insert({
        thread_id: m.threadId, user_id: m.userId, role: m.role, content: m.content, context_ref: m.contextRef, model: m.model,
      }));
      must(await db.from("chat_threads").update({ updated_at: new Date().toISOString() }).eq("id", m.threadId));
    },
  };
}

export function supabaseAccountDb(): AccountDb {
  const db = serviceClient();
  const must = <T>(r: { data: T; error: any }) => {
    if (r.error) throw new Error(r.error.message);
    return r.data;
  };
  return {
    async saveMergeToken(anonUserId, tokenHash, expiresAt) {
      must(await db.from("merge_tokens").insert({ token_hash: tokenHash, anon_user_id: anonUserId, expires_at: expiresAt }));
    },
    async findMergeToken(tokenHash, now) {
      const data = must(await db.from("merge_tokens").select("anon_user_id,expires_at").eq("token_hash", tokenHash).maybeSingle()) as any;
      if (!data || new Date(data.expires_at) < now) return null;
      return { anonUserId: data.anon_user_id };
    },
    async mergeGuest(from, to) {
      return must(await db.rpc("merge_guest_data", { p_from: from, p_to: to })) as Record<string, number>;
    },
    async deleteAuthUser(userId) {
      const { error } = await db.auth.admin.deleteUser(userId);
      if (error) throw new Error(error.message);
    },
  };
}
