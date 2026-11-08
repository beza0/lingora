import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { applyImport } from "../lib/api";
import { CSV_COLUMNS, planFromCsv, validateBundle, type ImportPlan } from "../lib/importer";
import { Banner, Button, Card, ErrorText, PageHeader } from "../components/ui";

export function Import() {
  const [fileName, setFileName] = useState<string | null>(null);
  const [plan, setPlan] = useState<ImportPlan | null>(null);
  const [progress, setProgress] = useState<string | null>(null);
  const apply = useMutation({
    mutationFn: () => applyImport(plan!, (t, n) => setProgress(`${t}: ${n}`)),
    onSuccess: () => setProgress("Tamamlandı. Bütün yeni satırlar taslak olarak eklendi."),
  });

  const onFile = async (file: File) => {
    setFileName(file.name);
    setProgress(null);
    const text = await file.text();
    if (file.name.toLowerCase().endsWith(".csv")) return setPlan(planFromCsv(text));
    try {
      setPlan(validateBundle(JSON.parse(text)));
    } catch {
      setPlan({ tables: {}, counts: {}, issues: [{ level: "error", where: "dosya", message: "JSON okunamadı." }] });
    }
  };
  const errors = plan?.issues.filter((i) => i.level === "error") ?? [];
  const warnings = plan?.issues.filter((i) => i.level === "warning") ?? [];

  return (
    <>
      <PageHeader title="Toplu aktarım" subtitle="JSON veya CSV · önce doğrulanır, hata yoksa taslak olarak yüklenir" />
      <Card className="flex flex-col items-center gap-3 border-2 border-dashed p-9 text-center">
        <p className="font-semibold">Dosyayı seç</p>
        <p className="text-sm text-muted">JSON: <code>pnpm content:bundle</code> çıktısı (<code>content/dist-content.json</code>) · CSV sütunları: <code>{CSV_COLUMNS.join(", ")}</code></p>
        <label className="inline-flex min-h-10 cursor-pointer items-center rounded-xl border border-line bg-surface px-4 text-sm font-semibold text-primary-text">
          Dosya seç
          <input type="file" accept=".json,.csv,application/json,text/csv" className="sr-only" onChange={(e) => e.target.files?.[0] && onFile(e.target.files[0])} />
        </label>
        <p className="text-xs text-muted">Önerilen yol: içeriği <code>content/packs/*.yaml</code> dosyalarında yazıp <code>pnpm content:validate</code> ve <code>pnpm content:seed</code> çalıştırmak. Panel aktarımı küçük düzeltmeler içindir.</p>
      </Card>
      {plan && (
        <Card className="flex flex-col gap-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 className="font-semibold">Doğrulama raporu · {fileName}</h2>
            <span className={`rounded-full px-3 py-1 text-xs font-semibold ${errors.length ? "bg-bad-soft text-bad" : "bg-ok-soft text-ok"}`}>{errors.length ? `${errors.length} hata` : "Hata yok"}</span>
          </div>
          <div className="flex flex-wrap gap-5 text-sm">{Object.entries(plan.counts).map(([t, n]) => <span key={t}>{t}: <b>{n}</b></span>)}</div>
          {plan.issues.length > 0 && (
            <div className="max-h-96 overflow-auto">
              <table className="w-full text-sm">
                <thead><tr className="border-b border-line text-left text-xs uppercase text-muted"><th className="py-2">Düzey</th><th>Konum</th><th>Sorun</th></tr></thead>
                <tbody>{[...errors, ...warnings].slice(0, 300).map((i, k) => (
                  <tr key={k} className="border-b border-line"><td className={`py-2 font-semibold ${i.level === "error" ? "text-bad" : "text-warn"}`}>{i.level === "error" ? "Hata" : "Uyarı"}</td><td><code>{i.where}</code></td><td>{i.message}</td></tr>
                ))}</tbody>
              </table>
            </div>
          )}
          {apply.error && <ErrorText error={apply.error} />}
          {progress && <Banner tone={apply.isSuccess ? "ok" : "info"}>{progress}</Banner>}
          <div><Button variant="primary" disabled={errors.length > 0 || apply.isPending || !Object.keys(plan.tables).length} onClick={() => apply.mutate()}>{errors.length ? "Yükle · önce hataları düzelt" : apply.isPending ? "Yükleniyor…" : "Taslak olarak yükle"}</Button></div>
        </Card>
      )}
    </>
  );
}
