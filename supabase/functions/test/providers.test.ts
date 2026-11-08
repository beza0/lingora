import { describe, expect, it } from "vitest";
import { loadConfig } from "../_shared/config.ts";
import { createProvider } from "../_shared/ai/factory.ts";
import { OpenAICompatProvider } from "../_shared/ai/openai_compat.ts";
import { ProviderError, type StreamEvent } from "../_shared/ai/provider.ts";

const streamOf = (chunks: string[]) =>
  new ReadableStream({ start(c) { for (const s of chunks) c.enqueue(new TextEncoder().encode(s)); c.close(); } });

describe("sağlayıcı seçimi", () => {
  it("varsayılan Groq'tur; anahtar yoksa sağlayıcı kurulmaz", () => {
    const c = loadConfig(() => undefined);
    expect(c.provider).toBe("groq");
    expect(c.apiKey).toBeNull();
    expect(createProvider(c)).toBeNull();
  });
  it("Groq anahtarıyla OpenAI uyumlu sağlayıcı ve hazır model gelir", () => {
    const c = loadConfig((k) => ({ GROQ_API_KEY: "g" } as Record<string, string>)[k]);
    expect(c.baseUrl).toBe("https://api.groq.com/openai/v1");
    expect(c.modelChat).toBe("openai/gpt-oss-120b");
    expect(createProvider(c)?.name).toBe("groq");
  });
  it("Anthropic seçilirse ANTHROPIC_API_KEY okunur, GROQ_API_KEY okunmaz", () => {
    const c = loadConfig((k) => ({ AI_PROVIDER: "anthropic", GROQ_API_KEY: "g" } as Record<string, string>)[k]);
    expect(c.apiKey).toBeNull();
    const d = loadConfig((k) => ({ AI_PROVIDER: "anthropic", ANTHROPIC_API_KEY: "a" } as Record<string, string>)[k]);
    expect(createProvider(d)?.name).toBe("anthropic");
  });
  it("adres verilmemiş genel sağlayıcı kurulmaz", () => {
    const c = loadConfig((k) => ({ AI_PROVIDER: "openai_compat", AI_API_KEY: "x" } as Record<string, string>)[k]);
    expect(createProvider(c)).toBeNull();
  });
});

describe("OpenAI uyumlu sağlayıcı", () => {
  it("akışı metin ve kullanım olaylarına çevirir, sistem yönergesini ilk mesaj yapar", async () => {
    let sent: { url: string; body: Record<string, unknown>; auth: string } | null = null;
    const fakeFetch = (async (url: string, init: RequestInit) => {
      sent = { url, body: JSON.parse(String(init.body)), auth: (init.headers as Record<string, string>).authorization };
      return new Response(streamOf([
        'data: {"choices":[{"delta":{"role":"assistant"}}]}\n\n',
        'data: {"choices":[{"delta":{"content":"Hel"}}]}\n\n',
        'data: {"choices":[{"delta":{"content":"lo"}}]}\n\n',
        'data: {"choices":[],"usage":{"prompt_tokens":12,"completion_tokens":3}}\n\n',
        "data: [DONE]\n\n",
      ]), { status: 200 });
    }) as unknown as typeof fetch;
    const p = new OpenAICompatProvider("groq", "https://api.groq.com/openai/v1/", "k", fakeFetch);
    const out: StreamEvent[] = [];
    for await (const e of p.streamChat({ model: "m", system: "sys", messages: [{ role: "user", content: "hi" }], maxTokens: 10 })) out.push(e);
    expect(out).toEqual([{ type: "text", text: "Hel" }, { type: "text", text: "lo" }, { type: "usage", inputTokens: 12, outputTokens: 3 }]);
    expect(sent!.url).toBe("https://api.groq.com/openai/v1/chat/completions");
    expect(sent!.auth).toBe("Bearer k");
    expect((sent!.body.messages as { role: string }[])[0]).toEqual({ role: "system", content: "sys" });
    expect(sent!.body.stream_options).toEqual({ include_usage: true });
    expect(sent!.body.reasoning_effort).toBeUndefined();
  });
  it("gpt-oss modellerinde düşünme payını düşük ister", async () => {
    let body: Record<string, unknown> = {};
    const fakeFetch = (async (_u: string, init: RequestInit) => { body = JSON.parse(String(init.body)); return Response.json({ choices: [{ message: { content: "x" } }] }); }) as unknown as typeof fetch;
    await new OpenAICompatProvider("groq", "https://x", "k", fakeFetch).complete({ model: "openai/gpt-oss-120b", system: "s", messages: [], maxTokens: 5 });
    expect(body.reasoning_effort).toBe("low");
  });
  it("tek seferlik yanıtı okur", async () => {
    const fakeFetch = (async () => Response.json({ choices: [{ message: { content: "{\"a\":1}" } }], usage: { prompt_tokens: 5, completion_tokens: 2 } })) as unknown as typeof fetch;
    const r = await new OpenAICompatProvider("groq", "https://x", "k", fakeFetch).complete({ model: "m", system: "s", messages: [], maxTokens: 5 });
    expect(r).toEqual({ text: "{\"a\":1}", inputTokens: 5, outputTokens: 2 });
  });
  it("HTTP hatası ve akış içi hata ProviderError olur", async () => {
    const http = new OpenAICompatProvider("groq", "https://x", "k", (async () => new Response("", { status: 429 })) as unknown as typeof fetch);
    await expect(http.complete({ model: "m", system: "s", messages: [], maxTokens: 1 })).rejects.toBeInstanceOf(ProviderError);
    const mid = new OpenAICompatProvider("groq", "https://x", "k", (async () => new Response(streamOf(['data: {"error":{"message":"boom"}}\n\n']), { status: 200 })) as unknown as typeof fetch);
    const it = mid.streamChat({ model: "m", system: "s", messages: [], maxTokens: 1 })[Symbol.asyncIterator]();
    await expect(it.next()).rejects.toBeInstanceOf(ProviderError);
  });
});
