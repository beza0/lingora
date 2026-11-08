-- Lingora · Supabase güvenlik denetimi (database linter) bulgularına göre sıkılaştırma
-- Tetikleyici fonksiyonları RPC olarak çağrılamaz; kişisel kullanım fonksiyonu yalnız oturum açmış kullanıcıya açıktır.
-- is_admin() ve content_visible() anon rolüne bilinçli olarak açık kalır: RLS politikaları bunları çağırır ve
-- oturumsuz istek de yayımlanmış içeriği okuyabilir. İkisi de yalnız true/false döner, veri sızdırmaz.

alter function public.content_before_write() set search_path = public;

revoke execute on function public.content_before_write() from public, anon, authenticated;
revoke execute on function public.content_after_write() from public, anon, authenticated;

revoke execute on function public.my_ai_usage() from public, anon;
grant execute on function public.my_ai_usage() to authenticated;
