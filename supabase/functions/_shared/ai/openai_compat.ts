// OpenAI uyumlu Chat Completions sağlayıcısı (Groq, OpenRouter, Gemini'nin OpenAI uyumlu ucu vb.).
// Anthropic sağlayıcısıyla aynı arayüzü uygular; hangisinin kullanılacağı AI_PROVIDER ile seçilir.
import { type AiProvider, type CompletionRequest, ProviderError, type StreamEvent } from "./provider.ts";
import { sseData } from "./anthropic.ts";

type Choice = { message?: { content?: string | null }; delta?: { content?: string | null } };
type Usage = { prompt_tokens?: number; completion_tokens?: number };
type Chunk = { choices?: Choice[]; usage?: Usage | null; error?: { message?: string } };

export class OpenAICompatProvider implements AiProvider {
  constructor(
    readonly name: string,
    private readonly baseUrl: string,
    private readonly apiKey: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  private async post(req: CompletionRequest, stream: boolean): Promise<Response> {
    const body: Record<string, unknown> = {
      model: req.model,
      max_tokens: req.maxTokens,
      messages: [{ role: "system", content: req.system }, ...req.messages],
      stream,
    };
    if (stream) body.stream_options = { include_usage: true };
    // gpt-oss akıl yürütme modelidir; düşünme payı çıktı sınırını yemesin diye kısa tutulur.
    if (req.model.includes("gpt-oss")) body.reasoning_effort = "low";
    let res: Response;
    try {
      res = await this.fetchFn(this.baseUrl.replace(/\/$/, "") + "/chat/completions", {
        method: "POST",
        signal: req.signal,
        headers: { authorization: `Bearer ${this.apiKey}`, "content-type": "application/json" },
        body: JSON.stringify(body),
      });
    } catch (e) {
      throw new ProviderError("Sağlayıcıya ulaşılamadı: " + (e as Error).message);
    }
    if (!res.ok) throw new ProviderError(`Sağlayıcı ${res.status} döndü`, res.status);
    return res;
  }

  async complete(req: CompletionRequest) {
    const res = await this.post(req, false);
    const body = await res.json() as Chunk;
    const text = body.choices?.[0]?.message?.content ?? "";
    return { text, inputTokens: body.usage?.prompt_tokens ?? 0, outputTokens: body.usage?.completion_tokens ?? 0 };
  }

  async *streamChat(req: CompletionRequest): AsyncIterable<StreamEvent> {
    const res = await this.post(req, true);
    if (!res.body) throw new ProviderError("Akış gövdesi yok");
    let input = 0;
    let output = 0;
    for await (const data of sseData(res.body)) {
      if (data === "[DONE]") break;
      let ev: Chunk;
      try {
        ev = JSON.parse(data);
      } catch {
        continue;
      }
      if (ev.error) throw new ProviderError("Akış hatası: " + (ev.error.message ?? "bilinmiyor"));
      const text = ev.choices?.[0]?.delta?.content;
      if (text) yield { type: "text", text };
      if (ev.usage) {
        input = ev.usage.prompt_tokens ?? input;
        output = ev.usage.completion_tokens ?? output;
      }
    }
    yield { type: "usage", inputTokens: input, outputTokens: output };
  }
}
