// AI değerlendirme çıktısının sunucu tarafı doğrulaması. Şemaya uymayan çıktı istemciye gönderilmez.
export type Verdict = "correct" | "acceptable" | "minor_error" | "incorrect";
export type Evaluation = {
  verdict: Verdict;
  meaning_ok: boolean;
  spelling_issues: { wrong: string; right: string }[];
  corrected: string;
  alternatives: string[];
  explanation_tr: string;
};

const VERDICTS: Verdict[] = ["correct", "acceptable", "minor_error", "incorrect"];

export function parseEvaluation(raw: string): Evaluation | null {
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  let o: Record<string, unknown>;
  try {
    o = JSON.parse(raw.slice(start, end + 1));
  } catch {
    return null;
  }
  if (!VERDICTS.includes(o.verdict as Verdict)) return null;
  if (typeof o.meaning_ok !== "boolean") return null;
  if (typeof o.corrected !== "string" || typeof o.explanation_tr !== "string") return null;
  if (!o.explanation_tr.trim() || o.explanation_tr.length > 400) return null;
  const issues = Array.isArray(o.spelling_issues) ? o.spelling_issues : [];
  if (!issues.every((i) => i && typeof (i as Record<string, unknown>).wrong === "string" && typeof (i as Record<string, unknown>).right === "string")) return null;
  const alts = Array.isArray(o.alternatives) ? o.alternatives.filter((a) => typeof a === "string").slice(0, 2) : [];
  // Tutarlılık: anlam yanlışsa "correct" olamaz
  if (!o.meaning_ok && o.verdict !== "incorrect") return null;
  return {
    verdict: o.verdict as Verdict,
    meaning_ok: o.meaning_ok,
    spelling_issues: (issues as { wrong: string; right: string }[]).slice(0, 5),
    corrected: o.corrected.slice(0, 500),
    alternatives: alts as string[],
    explanation_tr: o.explanation_tr,
  };
}

/** Cevap anahtarıyla yerel karşılaştırma (AI çağrısından önce). İstemcideki Dart sürümüyle aynı kuralları uygular. */
export function normalizeAnswer(s: string): string {
  return s
    .toLowerCase()
    .replace(/[’‘`]/g, "'")
    .replace(/\bi am\b/g, "i'm").replace(/\byou are\b/g, "you're").replace(/\bwe are\b/g, "we're")
    .replace(/\bit is\b/g, "it's").replace(/\bdo not\b/g, "don't").replace(/\bdoes not\b/g, "doesn't")
    .replace(/\bi have\b/g, "i've").replace(/\bi would\b/g, "i'd").replace(/\bi will\b/g, "i'll")
    .replace(/[.,!?;:"“”]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

export function levenshtein(a: string, b: string): number {
  const dp = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)]);
  for (let j = 1; j <= b.length; j++) dp[0][j] = j;
  for (let i = 1; i <= a.length; i++)
    for (let j = 1; j <= b.length; j++)
      dp[i][j] = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
  return dp[a.length][b.length];
}

export type LocalCheck = { outcome: "correct" | "minor_spelling" | "unknown"; matched?: string };

export function localCheck(answer: string, accepted: string[]): LocalCheck {
  const a = normalizeAnswer(answer);
  for (const acc of accepted) {
    const n = normalizeAnswer(acc);
    if (a === n) return { outcome: "correct", matched: acc };
  }
  for (const acc of accepted) {
    const n = normalizeAnswer(acc);
    const limit = n.length > 12 ? 2 : 1;
    if (levenshtein(a, n) <= limit) return { outcome: "minor_spelling", matched: acc };
  }
  return { outcome: "unknown" };
}
