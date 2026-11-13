// Panel veri erişimi. Bütün yazma işlemleri RLS ve is_admin() ile sunucuda denetlenir.
import { db } from "./supabase";
import type { ContentStatus } from "./status";
import { TABLE_ORDER, type ImportPlan, type Row } from "./importer";

export const PAGE_SIZE = 50;

export type TargetRow = {
  id: string;
  slug: string;
  kind: "sense" | "pattern";
  difficulty: number;
  status: ContentStatus;
  updated_at: string;
  senses: { meaning_tr: string; lexemes: { lemma: string; pos: string } | null } | null;
  patterns: { template_en: string; example_tr: string } | null;
  pack_targets: { packs: { slug: string; title_tr: string } | null }[];
};

export type TargetFilter = { domain?: string; status?: string; kind?: string; search?: string; page: number };

function must<T>(r: { data: T; error: { message: string } | null }): T {
  if (r.error) throw new Error(r.error.message);
  return r.data;
}

export async function listTargets(f: TargetFilter): Promise<{ rows: TargetRow[]; total: number }> {
  let q = db()
    .from("learning_targets")
    .select("id,slug,kind,difficulty,status,updated_at,senses(meaning_tr,lexemes(lemma,pos)),patterns(template_en,example_tr),pack_targets(packs(slug,title_tr))", { count: "exact" })
    .order("slug")
    .range(f.page * PAGE_SIZE, f.page * PAGE_SIZE + PAGE_SIZE - 1);
  if (f.domain) q = q.like("slug", `${f.domain}:%`);
  if (f.status) q = q.eq("status", f.status);
  if (f.kind) q = q.eq("kind", f.kind);
  if (f.search) q = q.ilike("slug", `%${f.search.replace(/[%_]/g, "")}%`);
  const r = await q;
  if (r.error) throw new Error(r.error.message);
  return { rows: (r.data ?? []) as unknown as TargetRow[], total: r.count ?? 0 };
}

export async function getTarget(id: string) {
  const target = must(await db().from("learning_targets").select("*").eq("id", id).single()) as Row;
  const exercises = must(await db().from("exercises").select("*").eq("target_id", id).order("type")) as Row[];
  const packs = must(await db().from("pack_targets").select("packs(id,slug,title_tr)").eq("target_id", id)) as unknown as { packs: Row }[];
  let sense: Row | null = null, lexeme: Row | null = null, usages: Row[] = [], pattern: Row | null = null, slots: Row[] = [];
  if (target.sense_id) {
    sense = must(await db().from("senses").select("*").eq("id", target.sense_id).single()) as Row;
    lexeme = must(await db().from("lexemes").select("*").eq("id", sense.lexeme_id).single()) as Row;
    usages = must(await db().from("sense_usages").select("*").eq("sense_id", sense.id)) as Row[];
  }
  if (target.pattern_id) {
    pattern = must(await db().from("patterns").select("*").eq("id", target.pattern_id).single()) as Row;
    slots = must(await db().from("pattern_slots").select("*").eq("pattern_id", pattern.id).order("sort")) as Row[];
  }
  return { target, exercises, packs: packs.map((p) => p.packs), sense, lexeme, usages, pattern, slots };
}

export async function updateRow(table: string, id: string, patch: Row) {
  must(await db().from(table).update(patch).eq("id", id));
}

export async function setTargetStatus(ids: string[], status: ContentStatus): Promise<number> {
  return must(await db().rpc("set_target_status", { p_targets: ids, p_status: status })) as number;
}

export async function listRevisions(entityId?: string) {
  let q = db().from("content_revisions").select("id,entity_type,entity_id,version,status_from,status_to,editor_id,created_at").order("created_at", { ascending: false }).limit(100);
  if (entityId) q = q.eq("entity_id", entityId);
  return must(await q) as Row[];
}

export async function listReports(status?: string) {
  let q = db().from("content_reports").select("*").order("created_at", { ascending: false }).limit(200);
  if (status) q = q.eq("status", status);
  return must(await q) as Row[];
}

export async function setReportStatus(id: string, status: "open" | "resolved" | "rejected") {
  must(await db().from("content_reports").update({ status, resolved_at: status === "open" ? null : new Date().toISOString() }).eq("id", id));
}

export const ENTITY_TABLES: Record<string, { label: string; title: string; columns: string[] }> = {
  domains: { label: "Alanlar", title: "name_tr", columns: ["id", "name_tr", "sort", "status"] },
  packs: { label: "Paketler", title: "title_tr", columns: ["slug", "domain_id", "title_tr", "status"] },
  scenarios: { label: "Senaryolar", title: "title_tr", columns: ["title_tr", "difficulty", "status"] },
  readings: { label: "Okuma metinleri", title: "title", columns: ["title", "kind", "difficulty", "status"] },
  grammar_notes: { label: "Yapı notları", title: "title_tr", columns: ["slug", "title_tr", "status"] },
  writing_tasks: { label: "Yazma görevleri", title: "prompt_tr", columns: ["prompt_tr", "difficulty", "status"] },
  situations: { label: "Cümle Rehberi durumları", title: "name_tr", columns: ["name_tr", "domain_id", "status"] },
};

export async function listEntities(table: string, search?: string) {
  const meta = ENTITY_TABLES[table];
  if (!meta) throw new Error("Bilinmeyen tablo");
  let q = db().from(table).select("*").order(meta.title).limit(300);
  if (search) q = q.ilike(meta.title, `%${search.replace(/[%_]/g, "")}%`);
  return must(await q) as Row[];
}

export async function getAppConfig() {
  return must(await db().from("app_config").select("key,value")) as { key: string; value: string }[];
}

/** Toplu aktarım: satırlar taslak olarak eklenir; var olan satırların durumu (incelendi/yayımlandı) korunur. */
export async function applyImport(plan: ImportPlan, onProgress?: (table: string, done: number) => void) {
  const conflictKey: Record<string, string> = { pack_targets: "pack_id,target_id", pack_grammar_notes: "pack_id,grammar_note_id", situation_items: "situation_id,target_id" };
  for (const table of TABLE_ORDER) {
    const rows = plan.tables[table];
    if (!rows?.length) continue;
    for (let i = 0; i < rows.length; i += 200) {
      const chunk = rows.slice(i, i + 200);
      let payload = chunk;
      if ("status" in chunk[0] && "id" in chunk[0]) {
        const existing = must(await db().from(table).select("id,status").in("id", chunk.map((r) => r.id as string))) as { id: string; status: string }[];
        const map = new Map(existing.map((e) => [e.id, e.status]));
        payload = chunk.map((r) => (map.has(r.id as string) ? { ...r, status: map.get(r.id as string) } : r));
      }
      must(await db().from(table).upsert(payload, { onConflict: conflictKey[table] ?? "id" }));
      onProgress?.(table, Math.min(i + 200, rows.length));
    }
  }
}

export type Metrics = {
  days: { day: string; active: number; new: number; cohort: number; d1: number; d7: number }[];
  events: { event: string; count: number; installs: number }[];
  errors: { error_type: string; message: string | null; screen: string | null; count: number; last: string; app_version: string | null }[];
  totals: { installs: number; accounts: number; guests: number };
};

export async function getMetrics(days = 30) {
  return must(await db().rpc("admin_metrics", { p_days: days })) as Metrics;
}

export async function setUserPlan(email: string, plan: "free" | "premium", days: number | null) {
  return must(await db().rpc("admin_set_plan", { p_email: email, p_plan: plan, p_days: days })) as { user_id: string; plan: string };
}
