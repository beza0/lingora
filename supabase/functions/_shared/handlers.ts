// AI uç noktalarının iş mantığı. Deno giriş dosyaları yalnız gerçek bağımlılıkları kurup buraya verir;
// testler aynı fonksiyonları sahte bağımlılıklarla çalıştırır.
import { type AiConfig, hashIp, nextIstanbulMidnight } from "./config.ts";
import { CORS_HEADERS, errorResponse, jsonResponse } from "./errors.ts";
import { type AiProvider, type ChatMessage, ProviderError, type StreamEvent } from "./ai/provider.ts";
import { chatSystemPrompt, type ContextRef, evalSystemPrompt, type EvalTask, evalUserMessage } from "./prompts.ts";
import { localCheck, parseEvaluation } from "./evaluation.ts";

export type AuthUser = { id: string; isAnonymous: boolean };
export type QuotaKind = "chat" | "eval" | "speech" | "tts";
export type QuotaResult = { allowed: boolean; reason?: "rate_limited" | "quota_exceeded"; used?: number; limit?: number };

export interface AiDb {
  consumeQuota(a: { userId: string; kind: QuotaKind; limit: number; ipHash: string | null; ipLimit: number; perMinute: number }): Promise<QuotaResult>;
  refundQuota(userId: string, kind: QuotaKind, ipHash: string | null): Promise<void>;
  recordTokens(userId: string, kind: QuotaKind, input: number, output: number): Promise<void>;
  findThread(threadId: string, userId: string): Promise<{ id: string; domain_id: string | null } | null>;
  createThread(userId: string, domainId: string | null, title: string): Promise<string>;
  recentMessages(threadId: string, limit: number): Promise<ChatMessage[]>;
  insertMessage(m: { threadId: string; userId: string; role: "user" | "assistant"; content: string; contextRef: ContextRef | null; model: string | null }): Promise<void>;
}

export type Deps = { config: AiConfig; provider: AiProvider | null; db: AiDb; now: () => Date };

const DOMAINS = new Set(["general", "software", "engineering", "yds", "health", "tourism", "law", "a1", "a2", "b1", "b2", "c1", "c2"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function takeQuota(kind: QuotaKind, user: AuthUser, ip: string | null, deps: Deps) {
  const c = deps.config;
  const limit = kind === "chat" ? (user.isAnonymous ? c.dailyChatGuest : c.dailyChatUser) : (user.isAnonymous ? c.dailyEvalGuest : c.dailyEvalUser);
  const ipHash = await hashIp(ip, c.ipHashSalt);
  const q = await deps.db.consumeQuota({ userId: user.id, kind, limit, ipHash, ipLimit: c.ipDailyLimit, perMinute: c.ratePerMinute });
  return { q, ipHash, limit };
}

function quotaError(q: QuotaResult, limit: number, deps: Deps, user: AuthUser): Response {
  if (q.reason === "rate_limited") return errorResponse("rate_limited");
  return errorResponse("quota_exceeded", { limit, resets_at: nextIstanbulMidnight(deps.now()), guest: user.isAnonymous });
}

// ------------------------------------------------------------------ ai-chat
export type ChatBody = { thread_id?: string; message?: unknown; domain_id?: string | null; context?: ContextRef | null };

export async function handleChat(input: { user: AuthUser | null; ip: string | null; body: ChatBody; signal?: AbortSignal }, deps: Deps): Promise<Response> {
  const { user, body } = input;
  if (!user) return errorResponse("unauthorized");
  if (!deps.provider || !deps.config.apiKey) return errorResponse("ai_not_configured");
  if (typeof body.message !== "string" || !body.message.trim()) return errorResponse("invalid_request");
  const message = body.message.trim();
  if (message.length > deps.config.maxInputChars) return errorResponse("too_long", { max: deps.config.maxInputChars });
  if (body.domain_id && !DOMAINS.has(body.domain_id)) return errorResponse("invalid_request");
  if (body.thread_id && !UUID.test(body.thread_id)) return errorResponse("invalid_request");
  const context: ContextRef | null = body.context && typeof body.context === "object"
    ? { kind: body.context.kind, text: String(body.context.text ?? "").slice(0, 500), meaning_tr: body.context.meaning_tr ? String(body.context.meaning_tr).slice(0, 200) : undefined, pack_title: body.context.pack_title ? String(body.context.pack_title).slice(0, 120) : undefined }
    : null;

  let threadId = body.thread_id ?? null;
  let domainId = body.domain_id ?? null;
  if (threadId) {
    const t = await deps.db.findThread(threadId, user.id);
    if (!t) return errorResponse("not_found");
    domainId = body.domain_id ?? t.domain_id;
  }

  const { q, ipHash, limit } = await takeQuota("chat", user, input.ip, deps);
  if (!q.allowed) return quotaError(q, limit, deps, user);

  const history = threadId ? await deps.db.recentMessages(threadId, deps.config.historyLimit) : [];
  const messages: ChatMessage[] = [...history, { role: "user", content: message }];
  const controller = new AbortController();
  input.signal?.addEventListener("abort", () => controller.abort());

  let iterator: AsyncIterator<StreamEvent>;
  let first: IteratorResult<StreamEvent>;
  try {
    iterator = deps.provider.streamChat({
      model: deps.config.modelChat, system: chatSystemPrompt(domainId, context), messages,
      maxTokens: deps.config.maxOutputTokens, signal: controller.signal,
    })[Symbol.asyncIterator]();
    first = await iterator.next();
  } catch (e) {
    await deps.db.refundQuota(user.id, "chat", ipHash);
    if (e instanceof ProviderError || (e as Error).name === "AbortError") return errorResponse("provider_error");
    throw e;
  }

  // Sağlayıcı yanıt vermeye başladı: sohbeti ve kullanıcı mesajını şimdi kaydet
  const title = context?.kind === "roleplay" && context.pack_title ? `Rol yapma: ${context.pack_title}`.slice(0, 60) : message.slice(0, 60);
  if (!threadId) threadId = await deps.db.createThread(user.id, domainId, title);
  await deps.db.insertMessage({ threadId, userId: user.id, role: "user", content: message, contextRef: context, model: null });

  const enc = new TextEncoder();
  const send = (c: ReadableStreamDefaultController<Uint8Array>, event: string, data: unknown) =>
    c.enqueue(enc.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
  const tid = threadId;
  let text = "";
  let usage = { inputTokens: 0, outputTokens: 0 };

  const stream = new ReadableStream<Uint8Array>({
    async start(c) {
      send(c, "meta", { thread_id: tid, used: q.used, limit });
      try {
        let r = first;
        while (!r.done) {
          const ev = r.value;
          if (ev.type === "text") {
            text += ev.text;
            send(c, "delta", { text: ev.text });
          } else usage = { inputTokens: ev.inputTokens, outputTokens: ev.outputTokens };
          r = await iterator.next();
        }
        send(c, "done", { usage: { input: usage.inputTokens, output: usage.outputTokens } });
      } catch {
        const aborted = controller.signal.aborted;
        if (!aborted) send(c, "error", { code: "provider_error", message: "Yanıt yarıda kesildi. Yeniden deneyebilirsin." });
        if (!text) await deps.db.refundQuota(user.id, "chat", ipHash);
      } finally {
        if (text.trim()) {
          await deps.db.insertMessage({ threadId: tid, userId: user.id, role: "assistant", content: text, contextRef: null, model: deps.config.modelChat });
        }
        await deps.db.recordTokens(user.id, "chat", usage.inputTokens, usage.outputTokens);
        try { c.close(); } catch { /* kapalı */ }
      }
    },
    cancel() {
      controller.abort();
    },
  });

  return new Response(stream, {
    headers: { ...CORS_HEADERS, "Content-Type": "text/event-stream; charset=utf-8", "Cache-Control": "no-cache" },
  });
}

// ------------------------------------------------------------------ ai-evaluate
export type EvalBody = { task?: Partial<EvalTask> };

export async function handleEvaluate(input: { user: AuthUser | null; ip: string | null; body: EvalBody }, deps: Deps): Promise<Response> {
  const { user } = input;
  if (!user) return errorResponse("unauthorized");
  const t = input.body.task;
  if (!t || typeof t.answer !== "string" || typeof t.expected !== "string" || typeof t.prompt_tr !== "string") return errorResponse("invalid_request");
  if (t.answer.length > deps.config.maxInputChars) return errorResponse("too_long", { max: deps.config.maxInputChars });
  const task: EvalTask = {
    skill: t.skill === "writing" ? "writing" : "vocab",
    prompt_tr: t.prompt_tr.slice(0, 500),
    expected: t.expected.slice(0, 500),
    accepted: Array.isArray(t.accepted) ? t.accepted.filter((x): x is string => typeof x === "string").slice(0, 10) : [],
    answer: t.answer.trim(),
    rubric: Array.isArray(t.rubric) ? t.rubric.filter((x): x is string => typeof x === "string").slice(0, 6) : undefined,
  };
  if (!task.answer) return errorResponse("invalid_request");

  // Önce yerel kontrol: AI'a gerek yoksa kota da düşmez
  const local = localCheck(task.answer, [task.expected, ...task.accepted]);
  if (local.outcome !== "unknown") {
    return jsonResponse({ source: "local", outcome: local.outcome, matched: local.matched });
  }

  if (!deps.provider || !deps.config.apiKey) return errorResponse("ai_not_configured");
  const { q, ipHash, limit } = await takeQuota("eval", user, input.ip, deps);
  if (!q.allowed) return quotaError(q, limit, deps, user);

  let inTok = 0;
  let outTok = 0;
  try {
    for (let attempt = 0; attempt < 2; attempt++) {
      const r = await deps.provider.complete({
        model: deps.config.modelEval, system: evalSystemPrompt(),
        messages: [{ role: "user", content: evalUserMessage(task) }], maxTokens: 400,
      });
      inTok += r.inputTokens;
      outTok += r.outputTokens;
      const parsed = parseEvaluation(r.text);
      if (parsed) {
        await deps.db.recordTokens(user.id, "eval", inTok, outTok);
        return jsonResponse({ source: "ai", evaluation: parsed, used: q.used, limit });
      }
    }
  } catch (e) {
    await deps.db.refundQuota(user.id, "eval", ipHash);
    if (e instanceof ProviderError) return errorResponse("provider_error");
    throw e;
  }
  await deps.db.refundQuota(user.id, "eval", ipHash);
  await deps.db.recordTokens(user.id, "eval", inTok, outTok);
  return errorResponse("invalid_output");
}
