import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { getMetrics } from "../lib/api";
import { Banner, Card, ErrorText, Loading, PageHeader } from "../components/ui";

const pct = (a: number, b: number) => (b ? `%${Math.round((a / b) * 100)}` : "–");

export function Metrics() {
  const [days, setDays] = useState(30);
  const q = useQuery({ queryKey: ["metrics", days], queryFn: () => getMetrics(days) });
  const m = q.data;
  const maxActive = Math.max(1, ...(m?.days.map((d) => d.active) ?? [1]));
  const cohort = m?.days.reduce((s, d) => s + d.cohort, 0) ?? 0;
  const d1 = m?.days.reduce((s, d) => s + d.d1, 0) ?? 0;
  const d7 = m?.days.reduce((s, d) => s + d.d7, 0) ?? 0;
  return (
    <>
      <PageHeader title="Metrikler" subtitle="Anonim kullanım ve hata kayıtları · hesaplarla ilişkilendirilmez" />
      <div className="flex gap-2">
        {[7, 30, 90].map((d) => (
          <button key={d} type="button" aria-pressed={days === d} onClick={() => setDays(d)} className={`rounded-full border px-3 py-1.5 text-sm ${days === d ? "border-transparent bg-primary-soft font-semibold text-primary-text" : "border-line"}`}>Son {d} gün</button>
        ))}
      </div>
      {q.isLoading ? <Loading /> : q.error ? <ErrorText error={q.error} /> : m && (
        <>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
            {[
              ["Kurulum (toplam)", m.totals.installs],
              ["Hesap", m.totals.accounts],
              ["Misafir", m.totals.guests],
              ["1. gün geri dönüş", pct(d1, cohort)],
              ["7. gün geri dönüş", pct(d7, cohort)],
            ].map(([l, v]) => (
              <Card key={String(l)}><div className="text-xs uppercase text-muted">{l}</div><div className="mt-1 text-2xl font-bold">{v}</div></Card>
            ))}
          </div>
          <Card>
            <div className="mb-3 font-semibold">Günlük aktif kurulum</div>
            {!m.days.length ? <Banner>Bu aralıkta kayıt yok.</Banner> : (
              <div className="flex h-40 items-end gap-1" role="img" aria-label="Günlük aktif kurulum grafiği">
                {m.days.map((d) => (
                  <div key={d.day} className="flex flex-1 flex-col items-center gap-1" title={`${d.day}: ${d.active} aktif, ${d.new} yeni`}>
                    <div className="w-full rounded-t bg-primary" style={{ height: `${(d.active / maxActive) * 100}%`, minHeight: 2 }} />
                    <div className="text-[10px] text-muted">{d.day.slice(8)}</div>
                  </div>
                ))}
              </div>
            )}
          </Card>
          <div className="grid gap-4 lg:grid-cols-2">
            <Card className="overflow-x-auto p-0">
              <div className="px-4 pt-4 font-semibold">Olaylar</div>
              <table className="w-full text-sm">
                <thead><tr className="border-b border-line text-left text-xs uppercase text-muted"><th className="px-4 py-2">Olay</th><th className="px-4">Sayı</th><th className="px-4">Kurulum</th></tr></thead>
                <tbody>{m.events.map((e) => (
                  <tr key={e.event} className="border-b border-line"><td className="px-4 py-2 font-mono text-xs">{e.event}</td><td className="px-4">{e.count}</td><td className="px-4">{e.installs}</td></tr>
                ))}</tbody>
              </table>
            </Card>
            <Card className="overflow-x-auto p-0">
              <div className="px-4 pt-4 font-semibold">Uygulama hataları</div>
              {!m.errors.length ? <div className="p-4"><Banner tone="ok">Bu aralıkta hata kaydı yok.</Banner></div> : (
                <table className="w-full text-sm">
                  <thead><tr className="border-b border-line text-left text-xs uppercase text-muted"><th className="px-4 py-2">Hata</th><th className="px-4">Sayı</th><th className="px-4">Son</th></tr></thead>
                  <tbody>{m.errors.map((e) => (
                    <tr key={e.error_type} className="border-b border-line align-top">
                      <td className="px-4 py-2"><div className="font-mono text-xs">{e.error_type}</div><div className="text-muted">{e.message}</div><div className="text-xs text-muted">{e.screen} · {e.app_version}</div></td>
                      <td className="px-4 py-2">{e.count}</td>
                      <td className="px-4 py-2 text-muted">{new Date(e.last).toLocaleString("tr-TR")}</td>
                    </tr>
                  ))}</tbody>
                </table>
              )}
            </Card>
          </div>
        </>
      )}
    </>
  );
}
