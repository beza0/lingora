// Değiştirilebilir AI sağlayıcı katmanı. Yeni bir sağlayıcı eklemek için bu arayüzü uygulayan bir sınıf yeterli.
export type ChatMessage = { role: "user" | "assistant"; content: string };

export type StreamEvent =
  | { type: "text"; text: string }
  | { type: "usage"; inputTokens: number; outputTokens: number };

export type CompletionRequest = {
  model: string;
  system: string;
  messages: ChatMessage[];
  maxTokens: number;
  signal?: AbortSignal;
};

export interface AiProvider {
  readonly name: string;
  streamChat(req: CompletionRequest): AsyncIterable<StreamEvent>;
  complete(req: CompletionRequest): Promise<{ text: string; inputTokens: number; outputTokens: number }>;
}

/** Sağlayıcı kaynaklı hata (ağ, 5xx, geçersiz yanıt). Kota iade edilir. */
export class ProviderError extends Error {
  constructor(message: string, readonly status?: number) {
    super(message);
    this.name = "ProviderError";
  }
}
