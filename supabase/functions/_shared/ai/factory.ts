// Ayarlara göre AI sağlayıcısını kurar. Anahtar yoksa null döner ve uç noktalar `ai_not_configured` verir.
import type { AiConfig } from "../config.ts";
import type { AiProvider } from "./provider.ts";
import { AnthropicProvider } from "./anthropic.ts";
import { OpenAICompatProvider } from "./openai_compat.ts";

export function createProvider(config: AiConfig, fetchFn: typeof fetch = fetch): AiProvider | null {
  if (!config.apiKey) return null;
  if (config.provider === "anthropic") return new AnthropicProvider(config.apiKey, fetchFn);
  if (config.baseUrl) return new OpenAICompatProvider(config.provider, config.baseUrl, config.apiKey, fetchFn);
  return null;
}
