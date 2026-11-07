-- Yalnız yerel geliştirme (`supabase db reset`). Test projesinde de aynı ayar elle yapılır (README).
update public.app_config set value = 'true' where key = 'show_drafts';
