import { useState } from "react";
import { Link } from "react-router-dom";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { listTargets, PAGE_SIZE, setTargetStatus, type TargetFilter } from "../lib/api";
import { Banner, Button, Card, ErrorText, inputClass, Loading, PageHeader, StatusChip } from "../components/ui";

const DOMAINS = [["", "Tüm alanlar"], ["general", "Genel"], ["software", "Yazılım"], ["engineering", "Mühendislik"], ["yds", "YDS/YÖKDİL"]];
const STATUSES = [["", "Tüm durumlar"], ["draft", "Taslak"], ["reviewed", "İncelendi"], ["published", "Yayımlandı"], ["archived", "Arşivlendi"]];
const KINDS = [["", "Tüm türler"], ["sense", "Kelime / ifade"], ["pattern", "Kalıp"]];

export function Content() {
  const [f, setF] = useState<TargetFilter>({ page: 0 });
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ["targets", f], queryFn: () => listTargets(f), placeholderData: keepPreviousData });
  const bulk = useMutation({
    mutationFn: () => setTargetStatus([...selected], "reviewed"),
    onSuccess: () => {
      setSelected(new Set());
      qc.invalidateQueries({ queryKey: ["targets"] });
    },
  });
  const set = (patch: Partial<TargetFilter>) => setF((p) => ({ ...p, ...patch, page: 0 }));
  const toggle = (id: string) => setSelected((s) => { const n = new Set(s); if (n.has(id)) n.delete(id); else n.add(id); return n; });
  const pages = Math.max(1, Math.ceil((q.data?.total ?? 0) / PAGE_SIZE));

  return (
    <>
      <PageHeader title="İçerik" subtitle={q.data ? `${q.data.total} öğrenme hedefi` : undefined} actions={<Link className="inline-flex min-h-10 items-center rounded-xl border border-line bg-surface px-4 text-sm font-semibold text-primary-text" to="/import">Toplu aktar</Link>} />
      <div className="flex flex-wrap gap-2.5">
        <input aria-label="Ara" className={`${inputClass} max-w-[360px]`} placeholder="Ara: kimlik (ör. blocker)" value={f.search ?? ""} onChange={(e) => set({ search: e.target.value || undefined })} />
        {[["domain", DOMAINS], ["status", STATUSES], ["kind", KINDS]].map(([key, opts]) => (
          <select key={key as string} aria-label={key as string} className={`${inputClass} w-auto`} value={String((f as unknown as Record<string, unknown>)[key as string] ?? "")} onChange={(e) => set({ [key as string]: e.target.value || undefined })}>
            {(opts as string[][]).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
          </select>
        ))}
      </div>
      {bulk.error && <ErrorText error={bulk.error} />}
      {q.isLoading ? <Loading /> : q.error ? <ErrorText error={q.error} /> : (
        <Card className="overflow-x-auto p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-line text-left text-xs uppercase tracking-wide text-muted">
                <th className="px-3 py-2.5"><span className="sr-only">Seç</span></th>
                <th className="px-3 py-2.5">İçerik</th><th className="px-3 py-2.5">Tür</th><th className="px-3 py-2.5">Paket</th>
                <th className="px-3 py-2.5">Zorluk</th><th className="px-3 py-2.5">Durum</th><th className="px-3 py-2.5">Güncellendi</th>
              </tr>
            </thead>
            <tbody>
              {q.data!.rows.map((t) => (
                <tr key={t.id} className="border-b border-line last:border-0">
                  <td className="px-3 py-2.5"><input type="checkbox" aria-label={`${t.slug} seç`} checked={selected.has(t.id)} onChange={() => toggle(t.id)} /></td>
                  <td className="px-3 py-2.5">
                    <Link className="font-semibold text-ink hover:underline" to={`/content/${t.id}`}>{t.senses?.lexemes?.lemma ?? t.patterns?.template_en ?? t.slug}</Link>
                    <div className="text-xs text-muted">{t.senses?.meaning_tr ?? t.patterns?.example_tr} · {t.slug}</div>
                  </td>
                  <td className="px-3 py-2.5">{t.kind === "sense" ? `Kelime · ${t.senses?.lexemes?.pos ?? ""}` : "Kalıp"}</td>
                  <td className="px-3 py-2.5">{t.pack_targets.map((p) => p.packs?.title_tr).filter(Boolean).join(", ")}</td>
                  <td className="px-3 py-2.5">{t.difficulty}</td>
                  <td className="px-3 py-2.5"><StatusChip status={t.status} /></td>
                  <td className="px-3 py-2.5 text-muted">{new Date(t.updated_at).toLocaleDateString("tr-TR")}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {!q.data!.rows.length && <div className="p-5"><Banner>Bu filtreyle içerik bulunamadı.</Banner></div>}
        </Card>
      )}
      <div className="flex flex-wrap items-center gap-3">
        <span className="text-sm text-muted">Seçili {selected.size} öğe:</span>
        <Button disabled={!selected.size || bulk.isPending} onClick={() => bulk.mutate()}>İncelendi olarak işaretle</Button>
        <span className="ml-auto text-sm text-muted">Sayfa {f.page + 1} / {pages}</span>
        <Button disabled={f.page === 0} onClick={() => setF((p) => ({ ...p, page: p.page - 1 }))}>Önceki</Button>
        <Button disabled={f.page + 1 >= pages} onClick={() => setF((p) => ({ ...p, page: p.page + 1 }))}>Sonraki</Button>
      </div>
    </>
  );
}
