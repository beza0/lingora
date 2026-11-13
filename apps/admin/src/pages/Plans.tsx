import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { setUserPlan } from "../lib/api";
import { Banner, Button, Card, ErrorText, Field, PageHeader, inputClass } from "../components/ui";

export function Plans() {
  const [email, setEmail] = useState("");
  const [plan, setPlan] = useState<"free" | "premium">("premium");
  const [days, setDays] = useState("30");
  const m = useMutation({ mutationFn: () => setUserPlan(email, plan, days ? Number(days) : null) });
  return (
    <>
      <PageHeader title="Premium planları" subtitle="Ödeme bağlanana kadar test kullanıcılarına Premium buradan verilir" />
      <Banner>Premium kullanıcıların günlük AI hakkı, uygulama ayarındaki çarpan kadar artar (varsayılan 3 kat). Yalnız e-posta veya Google ile kayıtlı hesaplara verilebilir.</Banner>
      <Card className="max-w-xl">
        <form className="flex flex-col gap-4" onSubmit={(e) => { e.preventDefault(); m.mutate(); }}>
          <Field label="Kullanıcının e-postası"><input className={inputClass} type="email" required value={email} onChange={(e) => setEmail(e.target.value)} /></Field>
          <Field label="Plan">
            <select className={inputClass} value={plan} onChange={(e) => setPlan(e.target.value as "free" | "premium")}>
              <option value="premium">Premium</option>
              <option value="free">Ücretsiz (Premium'u kaldır)</option>
            </select>
          </Field>
          <Field label="Süre (gün, boş bırakılırsa süresiz)"><input className={inputClass} type="number" min={1} value={days} onChange={(e) => setDays(e.target.value)} /></Field>
          <div><Button variant="primary" type="submit" disabled={m.isPending || !email}>Kaydet</Button></div>
          {m.error && <ErrorText error={m.error} />}
          {m.isSuccess && <Banner tone="ok">{email} için plan: {m.data.plan}.</Banner>}
        </form>
      </Card>
    </>
  );
}
