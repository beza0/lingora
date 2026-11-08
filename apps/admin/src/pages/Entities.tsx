import { useState } from "react";
import { NavLink, useParams } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ENTITY_TABLES, listEntities, updateRow } from "../lib/api";
import { nextActions, type ContentStatus } from "../lib/status";
import type { Row } from "../lib/importer";
import { Button, Card, ErrorText, inputClass, Loading, PageHeader, StatusChip } from "../components/ui";

/** Alan, paket, senaryo, metin, yapı notu, yazma görevi ve Cümle Rehberi durumları için ortak düzenleyici. */
function JsonEditor({ table, row, onDone }: { table: string; row: Row; onDone: () => void }) {
  const qc = useQueryClient();
  const editable = Object.fromEntries(Object.entries(row).filter(([k]) => !["id", "status", "version", "created_at", "updated_at"].includes(k)));
  const [text, setText] = useState(JSON.stringify(editable, null, 2));
  const [parseError, setParseError] = useState<string | null>(null);
  const save = useMutation({
    mutationFn: async () => {
      let patch: Row;
      try {
        patch = JSON.parse(text);
      } catch {
        setParseError("JSON geçerli değil.");
        throw new Error("JSON geçerli değil.");
      }
      setParseError(null);
      await updateRow(table, String(row.id), patch);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["entities", table] });
      onDone();
    },
  });
  return (
    <div className="flex flex-col gap-2">
      <textarea aria-label="İçerik (JSON)" className={`${inputClass} min-h-72 font-mono text-[13px]`} value={text} onChange={(e) => setText(e.target.value)} />
      {(parseError || save.error) && <ErrorText error={parseError ?? save.error} />}
      <div className="flex gap-2"><Button variant="primary" onClick={() => save.mutate()} disabled={save.isPending}>Kaydet</Button><Button onClick={onDone}>Vazgeç</Button></div>
    </div>
  );
}

export function Entities() {
  const { table = "packs" } = useParams();
  const meta = ENTITY_TABLES[table];
  const [search, setSearch] = useState("");
  const [editing, setEditing] = useState<string | null>(null);
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ["entities", table, search], queryFn: () => listEntities(table, search || undefined), enabled: Boolean(meta) });
  const setStatus = useMutation({
    mutationFn: ({ id, to }: { id: string; to: ContentStatus }) => updateRow(table, id, { status: to }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["entities", table] }),
  });
  if (!meta) return <ErrorText error="Bilinmeyen içerik türü" />;
  return (
    <>
      <PageHeader title={meta.label} subtitle="İçerik silinmez; arşivlenir. Yayımlamak için önce “İncelendi” gerekir." />
      <div className="flex flex-wrap gap-2">
        {Object.entries(ENTITY_TABLES).map(([k, m]) => (
          <NavLink key={k} to={`/entities/${k}`} className={({ isActive }) => `rounded-full border px-3 py-1.5 text-sm ${isActive ? "border-transparent bg-primary-soft font-semibold text-primary-text" : "border-line"}`}>{m.label}</NavLink>
        ))}
      </div>
      <input aria-label="Ara" className={`${inputClass} max-w-[360px]`} placeholder="Ara" value={search} onChange={(e) => setSearch(e.target.value)} />
      {setStatus.error && <ErrorText error={setStatus.error} />}
      {q.isLoading ? <Loading /> : q.error ? <ErrorText error={q.error} /> : (
        <div className="flex flex-col gap-3">
          {q.data!.map((r) => (
            <Card key={String(r.id)} className="flex flex-col gap-3 p-4">
              <div className="flex flex-wrap items-center gap-3">
                <div className="min-w-0 flex-1">
                  <div className="font-semibold">{String(r[meta.title] ?? r.id)}</div>
                  <div className="text-xs text-muted">{meta.columns.filter((c) => c !== meta.title && c !== "status").map((c) => `${c}: ${String(r[c] ?? "—")}`).join(" · ")}</div>
                </div>
                {"status" in r && <StatusChip status={r.status as ContentStatus} />}
                {"status" in r && nextActions(r.status as ContentStatus).slice(0, 2).map((a) => (
                  <Button key={a.to} variant={a.primary ? "primary" : "secondary"} onClick={() => setStatus.mutate({ id: String(r.id), to: a.to })}>{a.label}</Button>
                ))}
                <Button variant="ghost" onClick={() => setEditing(editing === r.id ? null : String(r.id))}>{editing === r.id ? "Kapat" : "Düzenle"}</Button>
              </div>
              {editing === r.id && <JsonEditor table={table} row={r} onDone={() => setEditing(null)} />}
            </Card>
          ))}
        </div>
      )}
    </>
  );
}
