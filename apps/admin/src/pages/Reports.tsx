import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { listReports, setReportStatus } from "../lib/api";
import { Banner, Button, Card, ErrorText, Loading, PageHeader } from "../components/ui";

const REASON: Record<string, string> = {
  wrong_answer: "Cevap yanlış", two_correct: "Birden fazla doğru seçenek", translation: "Çeviri hatalı", audio: "Seslendirme sorunu", typo: "Yazım hatası", other: "Diğer",
};

export function Reports() {
  const [status, setStatus] = useState<"open" | "resolved" | "rejected" | "">("open");
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ["reports", status], queryFn: () => listReports(status || undefined) });
  const m = useMutation({
    mutationFn: ({ id, to }: { id: string; to: "open" | "resolved" | "rejected" }) => setReportStatus(id, to),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["reports"] }),
  });
  return (
    <>
      <PageHeader title="Hata bildirimleri" subtitle="Kullanıcıların içerik bildirimleri · kişisel AI sohbetleri burada görünmez" />
      <div className="flex gap-2">
        {([["open", "Açık"], ["resolved", "Çözüldü"], ["rejected", "Reddedildi"], ["", "Tümü"]] as const).map(([v, l]) => (
          <button key={v} type="button" aria-pressed={status === v} onClick={() => setStatus(v)} className={`rounded-full border px-3 py-1.5 text-sm ${status === v ? "border-transparent bg-primary-soft font-semibold text-primary-text" : "border-line"}`}>{l}</button>
        ))}
      </div>
      {m.error && <ErrorText error={m.error} />}
      {q.isLoading ? <Loading /> : q.error ? <ErrorText error={q.error} /> : !q.data!.length ? <Banner>Bu durumda bildirim yok.</Banner> : (
        <Card className="overflow-x-auto p-0">
          <table className="w-full text-sm">
            <thead><tr className="border-b border-line text-left text-xs uppercase text-muted"><th className="px-3 py-2.5">Bildirim</th><th className="px-3">İçerik</th><th className="px-3">Tarih</th><th className="px-3">İşlem</th></tr></thead>
            <tbody>{q.data!.map((r) => (
              <tr key={String(r.id)} className="border-b border-line">
                <td className="px-3 py-2.5"><b>{REASON[String(r.reason)] ?? String(r.reason)}</b>{r.text ? <div className="text-muted">{String(r.text)}</div> : null}</td>
                <td className="px-3">{r.entity_type === "target" ? <Link className="text-primary-text underline" to={`/content/${String(r.entity_id)}`}>Hedefi aç</Link> : `${String(r.entity_type)} · ${String(r.entity_id).slice(0, 8)}`}</td>
                <td className="px-3 text-muted">{new Date(String(r.created_at)).toLocaleString("tr-TR")}</td>
                <td className="px-3"><div className="flex gap-2 py-2">
                  {r.status !== "resolved" && <Button onClick={() => m.mutate({ id: String(r.id), to: "resolved" })}>Çözüldü</Button>}
                  {r.status !== "rejected" && <Button variant="ghost" onClick={() => m.mutate({ id: String(r.id), to: "rejected" })}>Reddet</Button>}
                  {r.status !== "open" && <Button variant="ghost" onClick={() => m.mutate({ id: String(r.id), to: "open" })}>Yeniden aç</Button>}
                </div></td>
              </tr>
            ))}</tbody>
          </table>
        </Card>
      )}
    </>
  );
}
