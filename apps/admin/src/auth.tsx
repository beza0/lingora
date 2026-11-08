import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "./lib/supabase";

type AuthState = { loading: boolean; session: Session | null; isAdmin: boolean; error: string | null };
const AuthContext = createContext<AuthState>({ loading: true, session: null, isAdmin: false, error: null });

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ loading: true, session: null, isAdmin: false, error: null });

  useEffect(() => {
    if (!supabase) return;
    const client = supabase;
    let active = true;
    // Yöneticilik istemcideki bir bayrağa değil, sunucudaki is_admin() fonksiyonuna dayanır.
    const evaluate = async (session: Session | null) => {
      if (!session) return active && setState({ loading: false, session: null, isAdmin: false, error: null });
      const { data, error } = await client.rpc("is_admin");
      if (active) setState({ loading: false, session, isAdmin: data === true, error: error?.message ?? null });
    };
    client.auth.getSession().then(({ data }) => evaluate(data.session));
    const { data: sub } = client.auth.onAuthStateChange((_e, session) => evaluate(session));
    return () => {
      active = false;
      sub.subscription.unsubscribe();
    };
  }, []);

  return <AuthContext.Provider value={state}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);
