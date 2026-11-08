// Anthropic Messages API sağlayıcısı. SDK yerine fetch kullanılır: Deno ve Node'da aynı kod çalışır ve test edilebilir.
import { type AiProvider, type CompletionRequest, ProviderError, type StreamEvent } from "./provider.ts";

const API_URL = "https://api.anthropic.com/v1/messages";
const API_VERSION = "2023-06-01";

export class AnthropicProvider implements AiProvider {
  readonly name = "anthropic";
  constructor(private readonly apiKey: string, private readonly fetchFn: typeof fetch = fetch) {}

  private async post(req: CompletionRequest, stream: boolean): Promise<Response> {
    let res: Response;
    try {
      res = await this.fetchFn(API_URL, {
        method: "POST",
        signal: req.signal,
        headers: { "x-api-key": this.apiKey, "anthropic-version": API_VERSION, "content-type": "application/json" },
        body: JSON.stringify({ model: req.model, max_tokens: req.maxTokens, system: req.system, messages: req.messages, stream }),
      });
    } catch (e) {
      throw new ProviderError("Sağlayıcıya ulaşılamadı: " + (e as Error).message);
    }
    if (!res.ok) {
      // Gövde yalnız hata türünü anlamak için okunur; günlüğe kullanıcı içeriği yazılmaz.
      throw new ProviderError(`Sağlayıcı ${res.status} döndü`, res.status);
    }
    return res;
  }

  async complete(req: CompletionRequest) {
    const res = await this.post(req, false);
    const body = await res.json() as {
      content?: { type: string; text?: string }[];
      usage?: { input_tokens?: number; output_tokens?: number };
    };
    const text = (body.content ?? []).filter((c) => c.type === "text").map((c) => c.text ?? "").join("");
    return { text, inputTokens: body.usage?.input_tokens ?? 0, outputTokens: body.usage?.output_tokens ?? 0 };
  }

  async *streamChat(req: CompletionRequest): AsyncIterable<StreamEvent> {
    const res = await this.post(req, true);
    if (!res.body) throw new ProviderError("Akış gövdesi yok");
    let input = 0;
    let output = 0;
    for await (const data of sseData(res.body)) {
      let ev: Record<string, any>;
      try {
        ev = JSON.parse(data);
      } catch {
        continue;
      }
      if (ev.type === "message_start") input = ev.message?.usage?.input_tokens ?? 0;
      else if (ev.type === "content_block_delta" && ev.delta?.type === "text_delta") yield { type: "text", text: ev.delta.text ?? "" };
      else if (ev.type === "message_delta") output = ev.usage?.output_tokens ?? output;
      else if (ev.type === "error") throw new ProviderError("Akış hatası: " + (ev.error?.type ?? "bilinmiyor"));
    }
    yield { type: "usage", inputTokens: input, outputTokens: output };
  }
}

/** SSE akışından "data:" satırlarını çıkarır. */
export async function* sseData(body: ReadableStream<Uint8Array>): AsyncIterable<string> {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buf = "";
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buf += decoder.decode(value, { stream: true });
    let idx: number;
    while ((idx = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, idx).replace(/\r$/, "");
      buf = buf.slice(idx + 1);
      if (line.startsWith("data:")) yield line.slice(5).trim();
    }
  }
  if (buf.startsWith("data:")) yield buf.slice(5).trim();
}
