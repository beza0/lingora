// Hesap işlemleri: misafir verisini var olan hesaba birleştirme ve hesap silme.
import { errorResponse, jsonResponse } from "./errors.ts";
import type { AuthUser } from "./handlers.ts";

export interface AccountDb {
  saveMergeToken(anonUserId: string, tokenHash: string, expiresAt: string): Promise<void>;
  findMergeToken(tokenHash: string, now: Date): Promise<{ anonUserId: string } | null>;
  mergeGuest(fromUserId: string, toUserId: string): Promise<Record<string, number>>;
  deleteAuthUser(userId: string): Promise<void>;
}

export type AccountDeps = { db: AccountDb; now: () => Date; randomToken: () => string };

export async function sha256Hex(s: string): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(d)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function randomTokenHex(): string {
  const b = new Uint8Array(32);
  crypto.getRandomValues(b);
  return Array.from(b).map((x) => x.toString(16).padStart(2, "0")).join("");
}

const TOKEN_TTL_MS = 15 * 60 * 1000;

/**
 * 1. prepare: misafir oturumuyla çağrılır; tek kullanımlık, 15 dakikalık belirteç döner.
 * 2. complete: var olan hesapla giriş yapıldıktan sonra belirteçle çağrılır; veriler birleştirilir ve misafir kullanıcı silinir.
 * Birleştirme SQL tarafında idempotenttir; misafir silinince belirteç de silinir.
 */
export async function handleMerge(input: { user: AuthUser | null; body: { action?: string; token?: string } }, deps: AccountDeps): Promise<Response> {
  const { user, body } = input;
  if (!user) return errorResponse("unauthorized");

  if (body.action === "prepare") {
    if (!user.isAnonymous) return errorResponse("forbidden");
    const token = deps.randomToken();
    const expires = new Date(deps.now().getTime() + TOKEN_TTL_MS).toISOString();
    await deps.db.saveMergeToken(user.id, await sha256Hex(token), expires);
    return jsonResponse({ token, expires_at: expires });
  }

  if (body.action === "complete") {
    if (user.isAnonymous) return errorResponse("forbidden");
    if (typeof body.token !== "string" || !/^[0-9a-f]{64}$/.test(body.token)) return errorResponse("invalid_request");
    const found = await deps.db.findMergeToken(await sha256Hex(body.token), deps.now());
    if (!found) return errorResponse("not_found");
    if (found.anonUserId === user.id) return errorResponse("invalid_request");
    const counts = await deps.db.mergeGuest(found.anonUserId, user.id);
    await deps.db.deleteAuthUser(found.anonUserId);
    return jsonResponse({ merged: true, counts });
  }

  return errorResponse("invalid_request");
}

export async function handleDeleteAccount(input: { user: AuthUser | null; body: { confirm?: boolean } }, deps: { db: Pick<AccountDb, "deleteAuthUser"> }): Promise<Response> {
  if (!input.user) return errorResponse("unauthorized");
  if (input.body.confirm !== true) return errorResponse("invalid_request");
  // auth.users satırı silinince bütün kullanıcı tabloları cascade ile silinir; hata bildirimleri anonimleşir.
  await deps.db.deleteAuthUser(input.user.id);
  return jsonResponse({ deleted: true });
}
