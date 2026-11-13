import { NavLink, Outlet } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { supabase } from "../lib/supabase";
import { getAppConfig } from "../lib/api";
import { Banner } from "./ui";

const items = [
  { to: "/content", label: "İçerik (hedefler)" },
  { to: "/entities/packs", label: "Paketler ve diğer içerik" },
  { to: "/import", label: "Toplu aktarım" },
  { to: "/reports", label: "Hata bildirimleri" },
  { to: "/metrics", label: "Metrikler" },
  { to: "/plans", label: "Premium planları" },
  { to: "/history", label: "Değişiklik geçmişi" },
];

export function Layout() {
  const cfg = useQuery({ queryKey: ["app_config"], queryFn: getAppConfig });
  const showDrafts = cfg.data?.find((c) => c.key === "show_drafts")?.value === "true";
  return (
    <div className="flex min-h-screen flex-wrap">
      <nav aria-label="Panel menüsü" className="flex min-w-[200px] flex-[0_1_240px] flex-col gap-1 border-r border-line bg-surface px-3.5 py-5">
        <div className="flex items-center gap-2.5 px-2 pb-4">
          <span aria-hidden="true" className="grid h-7 w-7 place-items-center rounded-lg bg-primary text-sm font-bold text-white">L</span>
          <span className="font-semibold">Lingora Panel</span>
        </div>
        {items.map((i) => (
          <NavLink key={i.to} to={i.to} className={({ isActive }) => `rounded-xl px-3 py-2.5 text-sm ${isActive ? "bg-primary-soft font-semibold text-primary-text" : "hover:bg-surface2"}`}>
            {i.label}
          </NavLink>
        ))}
        <button type="button" className="mt-auto rounded-xl px-3 py-2.5 text-left text-sm text-muted hover:bg-surface2" onClick={() => supabase?.auth.signOut()}>
          Çıkış yap
        </button>
      </nav>
      <main className="flex min-w-0 flex-[999_1_560px] flex-col gap-5 px-8 py-7">
        {showDrafts && (
          <Banner tone="warn">
            <b>Test projesi:</b> <code>show_drafts</code> açık. Taslaklar uygulamada “İncelenmedi” etiketiyle görünür. Üretim projesinde yalnız yayımlanmış içerik gösterilir.
          </Banner>
        )}
        <Outlet />
      </main>
    </div>
  );
}
