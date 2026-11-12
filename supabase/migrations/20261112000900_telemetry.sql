-- Anonim hata ve kullanım kayıtları, yönetici metrikleri, eski veri temizliği.
-- Kayıtlar hesapla ilişkilendirilmez: yalnız cihaza özgü rastgele bir kimlik (install_id) tutulur.

create table if not exists public.client_errors (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  install_id text,
  platform text,
  app_version text,
  screen text,
  error_type text not null,
  message text,
  stack text
);
create index if not exists client_errors_created_idx on public.client_errors (created_at desc);

create table if not exists public.usage_events (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  day date not null default (now() at time zone 'Europe/Istanbul')::date,
  install_id text not null,
  platform text,
  app_version text,
  event text not null,
  props jsonb not null default '{}'::jsonb
);
create index if not exists usage_events_day_idx on public.usage_events (day, install_id);
create index if not exists usage_events_event_idx on public.usage_events (event, day);

alter table public.client_errors enable row level security;
alter table public.usage_events enable row level security;
-- Doğrudan okuma/yazma yok; yalnız aşağıdaki işlevler.
revoke all on public.client_errors, public.usage_events from anon, authenticated;

create or replace function public.log_client_error(
  p_install_id text, p_platform text, p_app_version text, p_screen text, p_error_type text, p_message text, p_stack text
) returns void
language plpgsql security definer set search_path = public as $$
begin
  -- Aynı kurulumdan dakikada en fazla 20 kayıt
  if (select count(*) from client_errors where install_id = left(p_install_id, 64) and created_at > now() - interval '1 minute') >= 20 then
    return;
  end if;
  insert into client_errors (install_id, platform, app_version, screen, error_type, message, stack)
  values (left(p_install_id, 64), left(p_platform, 20), left(p_app_version, 40), left(p_screen, 120),
          left(coalesce(p_error_type, 'error'), 120), left(p_message, 500), left(p_stack, 3000));
end $$;

create or replace function public.log_usage(p_install_id text, p_platform text, p_app_version text, p_events jsonb)
returns void
language plpgsql security definer set search_path = public as $$
declare e jsonb;
begin
  if p_install_id is null or length(p_install_id) < 8 or jsonb_typeof(p_events) <> 'array' then return; end if;
  if (select count(*) from usage_events where install_id = left(p_install_id, 64) and created_at > now() - interval '1 minute') >= 200 then
    return;
  end if;
  for e in select * from jsonb_array_elements(p_events) limit 50 loop
    if jsonb_typeof(e->'event') = 'string' then
      insert into usage_events (install_id, platform, app_version, event, props)
      values (left(p_install_id, 64), left(p_platform, 20), left(p_app_version, 40), left(e->>'event', 60),
              case when jsonb_typeof(e->'props') = 'object' and length((e->'props')::text) < 500 then e->'props' else '{}'::jsonb end);
    end if;
  end loop;
end $$;

revoke all on function public.log_client_error(text, text, text, text, text, text, text) from public;
revoke all on function public.log_usage(text, text, text, jsonb) from public;
grant execute on function public.log_client_error(text, text, text, text, text, text, text) to anon, authenticated;
grant execute on function public.log_usage(text, text, text, jsonb) to anon, authenticated;

-- Yönetici metrikleri: günlük aktif kurulum, yeni kurulum, 1/7. gün geri dönüş, olaylar, hatalar.
create or replace function public.admin_metrics(p_days int default 30)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare result jsonb;
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  with first_seen as (
    select install_id, min(day) as d0 from usage_events group by install_id
  ),
  daily as (
    select day, count(distinct install_id) as active from usage_events
    where day > current_date - p_days group by day
  ),
  newbies as (
    select d0 as day, count(*) as new_installs from first_seen where d0 > current_date - p_days group by d0
  ),
  ret as (
    select f.d0 as day,
      count(*) as cohort,
      count(*) filter (where exists (select 1 from usage_events u where u.install_id = f.install_id and u.day = f.d0 + 1)) as d1,
      count(*) filter (where exists (select 1 from usage_events u where u.install_id = f.install_id and u.day = f.d0 + 7)) as d7
    from first_seen f where f.d0 > current_date - p_days group by f.d0
  )
  select jsonb_build_object(
    'days', coalesce((select jsonb_agg(jsonb_build_object(
        'day', d.day, 'active', d.active, 'new', coalesce(n.new_installs, 0),
        'cohort', coalesce(r.cohort, 0), 'd1', coalesce(r.d1, 0), 'd7', coalesce(r.d7, 0)) order by d.day)
      from daily d left join newbies n on n.day = d.day left join ret r on r.day = d.day), '[]'::jsonb),
    'events', coalesce((select jsonb_agg(x order by x->>'count' desc) from (
        select jsonb_build_object('event', event, 'count', count(*), 'installs', count(distinct install_id)) as x
        from usage_events where day > current_date - p_days group by event order by count(*) desc limit 30) t), '[]'::jsonb),
    'errors', coalesce((select jsonb_agg(x) from (
        select jsonb_build_object('error_type', error_type, 'message', min(message), 'screen', min(screen),
          'count', count(*), 'last', max(created_at), 'app_version', max(app_version)) as x
        from client_errors where created_at > now() - make_interval(days => p_days)
        group by error_type order by count(*) desc limit 30) t), '[]'::jsonb),
    'totals', jsonb_build_object(
        'installs', (select count(*) from first_seen),
        'accounts', (select count(*) from auth.users where not coalesce(is_anonymous, false)),
        'guests', (select count(*) from auth.users where coalesce(is_anonymous, false)))
  ) into result;
  return result;
end $$;
revoke all on function public.admin_metrics(int) from public;
grant execute on function public.admin_metrics(int) to authenticated;

-- Eski veri temizliği (gizlilik politikasıyla aynı süreler):
--  * anonim hata/kullanım kayıtları: 180 gün
--  * 30 gündür hiçbir etkinliği olmayan misafir hesaplar (ve bağlı tüm verileri)
--  * süresi dolmuş birleştirme belirteçleri
create or replace function public.cleanup_old_data()
returns jsonb
language plpgsql security definer set search_path = public, auth as $$
declare n_err int; n_use int; n_guest int; n_tok int;
begin
  delete from public.client_errors where created_at < now() - interval '180 days';
  get diagnostics n_err = row_count;
  delete from public.usage_events where created_at < now() - interval '180 days';
  get diagnostics n_use = row_count;
  delete from public.merge_tokens where expires_at < now() - interval '1 day';
  get diagnostics n_tok = row_count;
  with stale as (
    select u.id from auth.users u
    where coalesce(u.is_anonymous, false)
      and u.created_at < now() - interval '30 days'
      and coalesce(u.last_sign_in_at, u.created_at) < now() - interval '30 days'
      and not exists (select 1 from public.review_events e where e.user_id = u.id and e.received_at > now() - interval '30 days')
      and not exists (select 1 from public.chat_messages m where m.user_id = u.id and m.created_at > now() - interval '30 days')
      and not exists (select 1 from public.ai_usage a where a.user_id = u.id and a.day > current_date - 30)
      and not exists (select 1 from public.app_admins ad where ad.user_id = u.id)
    limit 1000
  )
  delete from auth.users where id in (select id from stale);
  get diagnostics n_guest = row_count;
  return jsonb_build_object('client_errors', n_err, 'usage_events', n_use, 'merge_tokens', n_tok, 'guests', n_guest);
end $$;
revoke all on function public.cleanup_old_data() from public, anon, authenticated;

create extension if not exists pg_cron;
do $$
begin
  perform cron.unschedule('lingora-cleanup') where exists (select 1 from cron.job where jobname = 'lingora-cleanup');
  perform cron.schedule('lingora-cleanup', '17 0 * * *', 'select public.cleanup_old_data()');
end $$;
