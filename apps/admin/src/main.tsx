import { StrictMode, type ReactNode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import "./index.css";
import { isConfigured } from "./lib/supabase";
import { AuthProvider, useAuth } from "./auth";
import { Layout } from "./components/Layout";
import { Banner, Card, Loading } from "./components/ui";
import { Login } from "./pages/Login";
import { Content } from "./pages/Content";
import { TargetEditor } from "./pages/TargetEditor";
import { Entities } from "./pages/Entities";
import { Import } from "./pages/Import";
import { Reports } from "./pages/Reports";
import { Metrics } from "./pages/Metrics";
import { Plans } from "./pages/Plans";
import { History } from "./pages/History";

const queryClient = new QueryClient({ defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: false } } });

function RequireAdmin({ children }: { children: ReactNode }) {
  const { loading, session, isAdmin } = useAuth();
  if (loading) return <div className="p-8"><Loading /></div>;
  if (!session || !isAdmin) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

function NotConfigured() {
  return (
    <div className="grid min-h-screen place-items-center p-6">
      <Card className="max-w-lg">
        <Banner tone="warn">Panel yapılandırılmadı. <code>apps/admin/.env</code> dosyasına <code>VITE_SUPABASE_URL</code> ve <code>VITE_SUPABASE_ANON_KEY</code> ekleyip <code>pnpm dev</code> komutunu yeniden çalıştır. Service-role anahtarını buraya koyma.</Banner>
      </Card>
    </div>
  );
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    {!isConfigured ? <NotConfigured /> : (
      <QueryClientProvider client={queryClient}>
        <AuthProvider>
          <BrowserRouter>
            <Routes>
              <Route path="/login" element={<Login />} />
              <Route element={<RequireAdmin><Layout /></RequireAdmin>}>
                <Route path="/" element={<Navigate to="/content" replace />} />
                <Route path="/content" element={<Content />} />
                <Route path="/content/:id" element={<TargetEditor />} />
                <Route path="/entities/:table" element={<Entities />} />
                <Route path="/import" element={<Import />} />
                <Route path="/reports" element={<Reports />} />
                <Route path="/metrics" element={<Metrics />} />
                <Route path="/plans" element={<Plans />} />
                <Route path="/history" element={<History />} />
              </Route>
            </Routes>
          </BrowserRouter>
        </AuthProvider>
      </QueryClientProvider>
    )}
  </StrictMode>,
);
