import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { getTarget, listRevisions, setTargetStatus, updateRow } from "../lib/api";
import { nextActions, type ContentStatus } from "../lib/status";
import type { Row } from "../lib/importer";
import { Banner, Button, Card, ErrorText, Field, inputClass, Loading, PageHeader, StatusChip } from "../components/ui";

type FieldSpec = { key: string; label: string; multiline?: boolean; list?: boolean };

/** Basit alan düzenleyici: metin, çok satırlı metin ve virgülle ayrılmış liste. */
function RowForm({ table, row, fields }: { table: string; row: Row; fields: FieldSpec[] }) {
  const qc = useQueryClient();
  const [draft, setDraft] = useState<Record<string, string>>(() =>
    Object.fromEntries(fields.map((f) => [f.key, f.list ? ((row[f.key] as string[] | null) ?? []).join(", ") : String(row[f.key] ?? "")])));
  const save = useMutation({
    mutationFn: () => updateRow(table, String(row.id), Object.fromEntries(fields.map((f) => [f.key, f.list ? draft[f.key].split(",").map((s) => s.trim()).filter(Boolean) : draft[f.key]]))),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["target"] }),
  });
  const dirty = fields.some((f) => draft[f.key] !== (f.list ? ((row[f.key] as string[] | null) ?? []).join(", ") : String(row[f.key] ?? "")));
  return (
    <div className="flex flex-col gap-3">
      <div className="grid gap-3 md:grid-cols-2">
        {fields.map((f) => (
          <Field key={f.key} label={f.label}>
            {f.multiline
              ? <textarea className={`${inputClass} min-h-20`} value={draft[f.key]} onChange={(e) => setDraft({ ...draft, [f.key]: e.target.value })} />
              : <input className={inputClass} value={draft[f.key]} onChange={(e) => setDraft({ ...draft, [f.key]: e.target.value })} />}
          </Field>
        ))}
      </div>
      {save.error && <ErrorText error={save.error} />}
      <div><Button variant="primary" disabled={!dirty || save.isPending} onClick={() => save.mutate()}>{save.isPending ? "Kaydediliyor…" : "Kaydet"}</Button></div>
    </div>
  );
}

function ExerciseCard({ ex }: { ex: Row }) {
  const prompt = ex.prompt as { instruction_tr?: string; sentence?: string; text?: string; text_tr?: string; audio_text?: string; options?: string[] };
  const answer = ex.answer as { index?: number; text?: string };
  return (
    <details className="rounded-xl border border-line p-3">
      <summary className="cursor-pointer text-sm"><b>{String(ex.type)}</b> · {prompt.instruction_tr} <StatusChip status={ex.status as ContentStatus} /></summary>
      <div className="mt-3 flex flex-col gap-2 text-sm">
        <p>{prompt.sentence ?? prompt.text ?? prompt.text_tr ?? prompt.audio_text}</p>
        {prompt.options && <ol className="list-[upper-alpha] pl-6">{prompt.options.map((o, i) => <li key={o} className={i === answer.index ? "font-semibold text-ok" : ""}>{o}{i === answer.index ? " ✓" : ""}</li>)}</ol>}
        {answer.text && !prompt.options && <p>Cevap: <b>{answer.text}</b></p>}
        <RowForm table="exercises" row={ex} fields={[{ key: "explanation_tr", label: "Türkçe açıklama", multiline: true }, { key: "accepted_answers", label: "Kabul edilen cevaplar (virgülle)", list: true }]} />
      </div>
    </details>
  );
}

export function TargetEditor() {
  const { id = "" } = useParams();
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ["target", id], queryFn: () => getTarget(id) });
  const history = useQuery({ queryKey: ["revisions", id], queryFn: () => listRevisions(id) });
  const status = useMutation({
    mutationFn: (to: ContentStatus) => setTargetStatus([id], to),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["target", id] });
      qc.invalidateQueries({ queryKey: ["revisions", id] });
      qc.invalidateQueries({ queryKey: ["targets"] });
    },
  });
  if (q.isLoading) return <Loading />;
  if (q.error) return <ErrorText error={q.error} />;
  const { target, sense, lexeme, usages, pattern, slots, exercises, packs } = q.data!;
  const st = target.status as ContentStatus;

  return (
    <>
      <PageHeader
        title={`${String(lexeme?.lemma ?? pattern?.template_en ?? target.slug)}`}
        subtitle={`${target.kind === "sense" ? "Kelime anlamı" : "Kalıp"} · ${String(target.slug)} · sürüm ${String(target.version)}`}
        actions={<Link to="/content" className="inline-flex min-h-10 items-center rounded-xl border border-line bg-surface px-4 text-sm font-semibold text-primary-text">Listeye dön</Link>}
      />
      <div className="flex flex-wrap items-start gap-6">
        <div className="flex min-w-0 flex-[999_1_520px] flex-col gap-5">
          {sense && (
            <Card className="flex flex-col gap-4">
              <h2 className="font-semibold">Anlam</h2>
              <RowForm table="senses" row={sense} fields={[{ key: "meaning_tr", label: "Türkçe anlam" }, { key: "notes_tr", label: "Not" }]} />
            </Card>
          )}
          {usages.map((u) => (
            <Card key={String(u.id)} className="flex flex-col gap-4">
              <h2 className="font-semibold">Alan kullanımı · {String(u.domain_id)}</h2>
              <RowForm table="sense_usages" row={u} fields={[
                { key: "example_en", label: "Örnek (EN)", multiline: true }, { key: "example_tr", label: "Örnek (TR)", multiline: true },
                { key: "collocations", label: "Birliktelikler", list: true }, { key: "synonyms", label: "Yakın anlamlılar", list: true },
                { key: "tone_tags", label: "Ton etiketleri", list: true }, { key: "other_meanings_tr", label: "Diğer anlamlar" },
              ]} />
            </Card>
          ))}
          {pattern && (
            <Card className="flex flex-col gap-4">
              <h2 className="font-semibold">Kalıp</h2>
              <RowForm table="patterns" row={pattern} fields={[
                { key: "template_en", label: "Kalıp" }, { key: "example_en", label: "Örnek (EN)" }, { key: "example_tr", label: "Örnek (TR)" },
                { key: "template_tr", label: "Türkçe şablon" }, { key: "context_tags", label: "Bağlam", list: true }, { key: "tone_tags", label: "Ton", list: true },
              ]} />
              <p className="text-sm text-muted">Değişen parçalar: {slots.map((s) => String(s.text_en)).join(" · ")}</p>
            </Card>
          )}
          <Card className="flex flex-col gap-3">
            <h2 className="font-semibold">Alıştırmalar ({exercises.length})</h2>
            {exercises.map((ex) => <ExerciseCard key={String(ex.id)} ex={ex} />)}
          </Card>
        </div>
        <aside className="flex flex-[1_1_300px] flex-col gap-4">
          <Card className="flex flex-col gap-3">
            <h2 className="font-semibold">Yayın durumu</h2>
            <div className="flex flex-wrap items-center gap-2"><StatusChip status={st} /><span className="text-sm text-muted">Taslak → İncelendi → Yayımlandı</span></div>
            {nextActions(st).map((a) => (
              <Button key={a.to} variant={a.primary ? "primary" : "secondary"} disabled={status.isPending} onClick={() => status.mutate(a.to)}>{a.label}</Button>
            ))}
            {status.error && <ErrorText error={status.error} />}
            <p className="text-sm text-muted">Durum değişikliği bağlı anlam, kullanım ve alıştırmalara da uygulanır. Kimlik kalıcıdır: yayımlanmış bir anlamı başka bir anlama çevirmek yerine yeni hedef oluştur; öğrenme kayıtları korunur.</p>
          </Card>
          <Card className="flex flex-col gap-2">
            <h2 className="font-semibold">Paketler</h2>
            <p className="text-sm">{packs.map((p) => String(p?.title_tr)).join(", ") || "—"}</p>
          </Card>
          <Card className="flex flex-col gap-2">
            <h2 className="font-semibold">Değişiklik geçmişi</h2>
            {history.data?.length ? history.data.slice(0, 8).map((h) => (
              <div key={String(h.id)} className="flex justify-between border-b border-line py-1.5 text-sm last:border-0">
                <span>{h.status_from && h.status_from !== h.status_to ? `${String(h.status_from)} → ${String(h.status_to)}` : `sürüm ${String(h.version)}`}</span>
                <span className="text-muted">{new Date(String(h.created_at)).toLocaleString("tr-TR")}</span>
              </div>
            )) : <Banner>Kayıt yok.</Banner>}
          </Card>
        </aside>
      </div>
    </>
  );
}
