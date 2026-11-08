import { useQuery } from "@tanstack/react-query";
import { listRevisions } from "../lib/api";
import { Card, ErrorText, Loading, PageHeader } from "../components/ui";
import { STATUS_LABEL, type ContentStatus } from "../lib/status";

export function History() {
  const q = useQuery({ queryKey: ["revisions", "all"], queryFn: () => listRevisions() });
  return (
    <>
      <PageHeader title="Değişiklik geçmişi" subtitle="Son 100 içerik değişikliği (veritabanı tetikleyicisi yazar)" />
      {q.isLoading ? <Loading /> : q.error ? <ErrorText error={q.error} /> : (
        <Card className="overflow-x-auto p-0">
          <table className="w-full text-sm">
            <thead><tr className="border-b border-line text-left text-xs uppercase text-muted"><th className="px-3 py-2.5">Tablo</th><th className="px-3">Kimlik</th><th className="px-3">Sürüm</th><th className="px-3">Durum</th><th className="px-3">Tarih</th></tr></thead>
            <tbody>{q.data!.map((h) => (
              <tr key={String(h.id)} className="border-b border-line">
                <td className="px-3 py-2">{String(h.entity_type)}</td>
                <td className="px-3"><code>{String(h.entity_id).slice(0, 8)}</code></td>
                <td className="px-3">{String(h.version)}</td>
                <td className="px-3">{h.status_from && h.status_from !== h.status_to ? `${STATUS_LABEL[h.status_from as ContentStatus]} → ${STATUS_LABEL[h.status_to as ContentStatus]}` : STATUS_LABEL[h.status_to as ContentStatus]}</td>
                <td className="px-3 text-muted">{new Date(String(h.created_at)).toLocaleString("tr-TR")}</td>
              </tr>
            ))}</tbody>
          </table>
        </Card>
      )}
    </>
  );
}
