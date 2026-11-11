import { useState, type FormEvent } from "react";
import { Navigate } from "react-router-dom";
import { supabase } from "../lib/supabase";
import { useAuth } from "../auth";
import { Banner, Button, Card, Field, inputClass } from "../components/ui";

export function Login() {
  const { session, isAdmin, loading } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  if (!loading && session && isAdmin) return <Navigate to="/content" replace />;

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const { error } = await supabase!.auth.signInWithPassword({ email, password });
    setBusy(false);
    if (error) setError("Giriş yapılamadı: e-posta veya parola hatalı.");
  };

  const google = async () => {
    setError(null);
    const { error } = await supabase!.auth.signInWithOAuth({ provider: "google", options: { redirectTo: window.location.origin } });
    if (error) setError("Google ile giriş başlatılamadı.");
  };

  return (
    <div className="grid min-h-screen place-items-center p-6">
      <Card className="flex w-full max-w-[400px] flex-col gap-4 p-8">
        <div className="flex items-center gap-2.5">
          <span aria-hidden="true" className="grid h-8 w-8 place-items-center rounded-lg bg-primary font-bold text-white">L</span>
          <span className="text-lg font-semibold">Lingora Panel</span>
        </div>
        <p className="text-muted">Yalnız yetkili yöneticiler girebilir.</p>
        {session && !isAdmin && !loading && (
          <Banner tone="error">
            Bu hesap yönetici değil. Yetki sunucudaki <code>app_admins</code> tablosundan okunur.{" "}
            <button type="button" className="underline" onClick={() => supabase?.auth.signOut()}>Başka hesapla gir</button>
          </Banner>
        )}
        <Button type="button" onClick={google}>Google ile giriş yap</Button>
        <p className="text-center text-sm text-muted">veya e-postayla</p>
        <form onSubmit={submit} className="flex flex-col gap-3">
          <Field label="E-posta"><input className={inputClass} type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} /></Field>
          <Field label="Parola"><input className={inputClass} type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} /></Field>
          {error && <Banner tone="error">{error}</Banner>}
          <Button variant="primary" type="submit" disabled={busy}>{busy ? "Giriş yapılıyor…" : "Giriş yap"}</Button>
        </form>
      </Card>
    </div>
  );
}
