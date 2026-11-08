import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

/** Panel yalnız anon anahtarla çalışır; yetki sunucuda is_admin() ve RLS ile denetlenir. */
export const isConfigured = Boolean(url && anon);
export const supabase: SupabaseClient | null = isConfigured ? createClient(url!, anon!) : null;

export function db(): SupabaseClient {
  if (!supabase) throw new Error("Supabase yapılandırılmadı (apps/admin/.env).");
  return supabase;
}
