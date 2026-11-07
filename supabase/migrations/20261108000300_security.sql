-- Lingora · yetki, RLS, tetikleyiciler ve sunucu fonksiyonları

-- ---------------------------------------------------------------- yardımcılar
create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (select 1 from public.app_admins where user_id = auth.uid());
$$;

create or replace function public.content_visible(s public.content_status)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select s = 'published'
      or (s <> 'archived'
          and coalesce((select value from public.app_config where key = 'show_drafts'), 'false') = 'true');
$$;

grant execute on function public.is_admin() to anon, authenticated;
grant execute on function public.content_visible(public.content_status) to anon, authenticated;

-- ---------------------------------------------------------------- içerik denetimi
-- Yayın akışı: draft → reviewed → published. İncelenmemiş içerik yayımlanamaz.
-- İçerik alanı değişirse sürüm artar; her değişiklik content_revisions'a yazılır.
create or replace function public.content_before_write()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.status = 'published' and current_user not in ('postgres', 'service_role', 'supabase_admin') then
      raise exception 'İçerik doğrudan yayımlanmış olarak eklenemez; önce incelenmeli.' using errcode = 'check_violation';
    end if;
    return new;
  end if;
  if new.status = 'published' and old.status not in ('reviewed', 'published') then
    raise exception 'İncelenmemiş içerik yayımlanamaz (% → published).', old.status using errcode = 'check_violation';
  end if;
  if (to_jsonb(new) - 'updated_at' - 'version' - 'status') is distinct from (to_jsonb(old) - 'updated_at' - 'version' - 'status') then
    new.version := old.version + 1;
  else
    new.version := old.version;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.content_after_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and to_jsonb(new) = to_jsonb(old) then
    return null;
  end if;
  insert into public.content_revisions (entity_type, entity_id, version, snapshot, status_from, status_to, editor_id)
  values (tg_table_name, new.id::text, new.version, to_jsonb(new),
          case when tg_op = 'UPDATE' then old.status end, new.status, auth.uid());
  return null;
end;
$$;

do $$
declare
  t text;
  versioned text[] := array['domains', 'packs', 'lexemes', 'senses', 'sense_usages', 'grammar_notes', 'patterns',
                            'learning_targets', 'exercises', 'scenarios', 'readings', 'writing_tasks', 'situations'];
  linking text[] := array['pattern_slots', 'pack_targets', 'pack_grammar_notes', 'situation_items'];
begin
  foreach t in array versioned loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy %I on public.%I for select using (public.content_visible(status) or public.is_admin())', t || '_read', t);
    execute format('create policy %I on public.%I for insert with check (public.is_admin())', t || '_admin_insert', t);
    execute format('create policy %I on public.%I for update using (public.is_admin()) with check (public.is_admin())', t || '_admin_update', t);
    execute format('create trigger %I before insert or update on public.%I for each row execute function public.content_before_write()', t || '_before', t);
    execute format('create trigger %I after insert or update on public.%I for each row execute function public.content_after_write()', t || '_after', t);
  end loop;
  foreach t in array linking loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy %I on public.%I for select using (true)', t || '_read', t);
    execute format('create policy %I on public.%I for all using (public.is_admin()) with check (public.is_admin())', t || '_admin_write', t);
  end loop;
end;
$$;

-- Silme yok: içerik arşivlenir (status = archived). Bağlantı tablolarında yönetici silebilir.

alter table public.app_config enable row level security;
create policy app_config_read on public.app_config for select using (true);
create policy app_config_admin on public.app_config for update using (public.is_admin()) with check (public.is_admin());

alter table public.content_revisions enable row level security;
create policy content_revisions_admin_read on public.content_revisions for select using (public.is_admin());

-- ---------------------------------------------------------------- kullanıcı verisi
do $$
declare
  t text;
  owned text[] := array['profiles', 'user_domains', 'study_sessions', 'card_states', 'skill_evidence', 'custom_items',
                        'saved_items', 'lists', 'list_items', 'assessments', 'chat_threads', 'chat_messages',
                        'daily_activity', 'user_badges'];
begin
  foreach t in array owned loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy %I on public.%I for select using (user_id = auth.uid())', t || '_own_select', t);
    execute format('create policy %I on public.%I for insert with check (user_id = auth.uid())', t || '_own_insert', t);
    execute format('create policy %I on public.%I for update using (user_id = auth.uid()) with check (user_id = auth.uid())', t || '_own_update', t);
    execute format('create policy %I on public.%I for delete using (user_id = auth.uid())', t || '_own_delete', t);
  end loop;
end;
$$;

-- Liste öğesi yalnız kendi listesine ve kendi kaydına bağlanabilir
create policy list_items_own_refs on public.list_items as restrictive for insert
  with check (
    exists (select 1 from public.lists l where l.id = list_id and l.user_id = auth.uid())
    and exists (select 1 from public.saved_items s where s.id = saved_item_id and s.user_id = auth.uid())
  );

-- Sohbet mesajı yalnız kendi sohbetine yazılabilir
create policy chat_messages_own_thread on public.chat_messages as restrictive for insert
  with check (exists (select 1 from public.chat_threads c where c.id = thread_id and c.user_id = auth.uid()));

-- Cevap olayları değiştirilemez: yalnız okuma ve ekleme
alter table public.review_events enable row level security;
create policy review_events_own_select on public.review_events for select using (user_id = auth.uid());
create policy review_events_own_insert on public.review_events for insert with check (user_id = auth.uid());

-- Hata bildirimleri: kullanıcı kendi bildirimini yazar/okur; yönetici hepsini okur ve durumunu değiştirir
alter table public.content_reports enable row level security;
create policy content_reports_insert on public.content_reports for insert with check (user_id = auth.uid() and status = 'open');
create policy content_reports_select on public.content_reports for select using (user_id = auth.uid() or public.is_admin());
create policy content_reports_admin_update on public.content_reports for update using (public.is_admin()) with check (public.is_admin());

-- Yönetici tablosu: herkes yalnız kendi satırını görebilir; yazma yalnız SQL ile (service role)
alter table public.app_admins enable row level security;
create policy app_admins_self on public.app_admins for select using (user_id = auth.uid());

-- Yalnız sunucu: politika yok → istemciye kapalı (service role RLS'i atlar)
alter table public.ai_usage enable row level security;
alter table public.ai_ip_usage enable row level security;
alter table public.ai_rate enable row level security;
alter table public.merge_tokens enable row level security;

-- ---------------------------------------------------------------- AI kotası (yalnız service role)
-- Tek işlemde: dakika sınırı, IP günlük sınırı ve kullanıcı günlük kotası.
create or replace function public.consume_ai_quota(
  p_user uuid, p_kind text, p_limit int, p_ip_hash text, p_ip_limit int, p_per_minute int
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_day date := (now() at time zone 'Europe/Istanbul')::date;
  v_minute timestamptz := date_trunc('minute', now());
  v_used int;
  v_ip int;
  v_rate int;
begin
  if p_kind not in ('chat', 'eval') then
    raise exception 'Geçersiz kota türü: %', p_kind;
  end if;

  insert into ai_rate (user_id, minute, requests) values (p_user, v_minute, 1)
  on conflict (user_id, minute) do update set requests = ai_rate.requests + 1
  returning requests into v_rate;
  if v_rate > p_per_minute then
    update ai_rate set requests = requests - 1 where user_id = p_user and minute = v_minute;
    return jsonb_build_object('allowed', false, 'reason', 'rate_limited');
  end if;

  if p_ip_hash is not null then
    insert into ai_ip_usage (ip_hash, day, requests) values (p_ip_hash, v_day, 1)
    on conflict (ip_hash, day) do update set requests = ai_ip_usage.requests + 1
    returning requests into v_ip;
    if v_ip > p_ip_limit then
      update ai_ip_usage set requests = requests - 1 where ip_hash = p_ip_hash and day = v_day;
      update ai_rate set requests = requests - 1 where user_id = p_user and minute = v_minute;
      return jsonb_build_object('allowed', false, 'reason', 'quota_exceeded', 'scope', 'ip');
    end if;
  end if;

  insert into ai_usage (user_id, day, kind, requests) values (p_user, v_day, p_kind, 1)
  on conflict (user_id, day, kind) do update set requests = ai_usage.requests + 1
  returning requests into v_used;
  if v_used > p_limit then
    update ai_usage set requests = requests - 1 where user_id = p_user and day = v_day and kind = p_kind;
    if p_ip_hash is not null then
      update ai_ip_usage set requests = requests - 1 where ip_hash = p_ip_hash and day = v_day;
    end if;
    return jsonb_build_object('allowed', false, 'reason', 'quota_exceeded', 'scope', 'user', 'used', v_used - 1, 'limit', p_limit);
  end if;

  return jsonb_build_object('allowed', true, 'used', v_used, 'limit', p_limit);
end;
$$;

-- Sağlayıcı hatasında kotayı iade eder
create or replace function public.refund_ai_quota(p_user uuid, p_kind text, p_ip_hash text)
returns void
language sql
security definer
set search_path = public
as $$
  update ai_usage set requests = greatest(requests - 1, 0)
   where user_id = p_user and day = (now() at time zone 'Europe/Istanbul')::date and kind = p_kind;
  update ai_ip_usage set requests = greatest(requests - 1, 0)
   where p_ip_hash is not null and ip_hash = p_ip_hash and day = (now() at time zone 'Europe/Istanbul')::date;
$$;

create or replace function public.record_ai_tokens(p_user uuid, p_kind text, p_in int, p_out int)
returns void
language sql
security definer
set search_path = public
as $$
  update ai_usage set input_tokens = input_tokens + p_in, output_tokens = output_tokens + p_out
   where user_id = p_user and day = (now() at time zone 'Europe/Istanbul')::date and kind = p_kind;
$$;

-- Kullanıcının bugünkü kullanımını kendisi okuyabilir (sayım sunucuda yapılır, istemci yalnız görür)
create or replace function public.my_ai_usage()
returns table (kind text, requests int)
language sql
stable
security definer
set search_path = public
as $$
  select kind, requests from ai_usage
   where user_id = auth.uid() and day = (now() at time zone 'Europe/Istanbul')::date;
$$;

revoke execute on function public.consume_ai_quota(uuid, text, int, text, int, int) from public, anon, authenticated;
revoke execute on function public.refund_ai_quota(uuid, text, text) from public, anon, authenticated;
revoke execute on function public.record_ai_tokens(uuid, text, int, int) from public, anon, authenticated;
grant execute on function public.my_ai_usage() to authenticated;

-- ---------------------------------------------------------------- başlangıç verisi
insert into public.app_config (key, value) values
  ('show_drafts', 'false'),
  ('content_version', '0')
on conflict (key) do nothing;

insert into public.domains (id, name_tr, description_tr, color_key, sort, status) values
  ('general', 'Genel İngilizce', 'Günlük konuşma, istekler, planlar ve sorunlar.', 'general', 1, 'draft'),
  ('software', 'Yazılım İngilizcesi', 'Toplantı, hata kaydı ve kod incelemesinde kullanılan İngilizce.', 'software', 2, 'draft'),
  ('engineering', 'Mühendislik İngilizcesi', 'Ölçüm, test, teknik sorun ve çözüm önerisi.', 'engineering', 3, 'draft'),
  ('yds', 'YDS/YÖKDİL', 'Akademik cümle yorumlama, paragraf ilişkileri ve çıkarım.', 'yds', 4, 'draft')
on conflict (id) do nothing;
