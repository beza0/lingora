-- Premium altyapısı: kullanıcı planı, plana göre AI kotası, yönetici atama işlevi.
-- Ödeme (App Store / Play / RevenueCat) henüz bağlı değil; plan şimdilik yalnız yönetici tarafından atanır.

create table if not exists public.user_plans (
  user_id uuid primary key references auth.users (id) on delete cascade,
  plan text not null default 'free' check (plan in ('free', 'premium')),
  source text not null default 'manual' check (source in ('manual', 'promo', 'app_store', 'play_store')),
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.user_plans enable row level security;
drop policy if exists "user_plans_select_own" on public.user_plans;
create policy "user_plans_select_own" on public.user_plans for select to authenticated using (user_id = auth.uid());
revoke insert, update, delete on public.user_plans from anon, authenticated;

insert into public.app_config (key, value) values ('premium_quota_multiplier', '3') on conflict (key) do nothing;

create or replace function public.is_premium(p_user uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from user_plans
    where user_id = p_user and plan = 'premium' and (expires_at is null or expires_at > now())
  );
$$;
revoke all on function public.is_premium(uuid) from public, anon, authenticated;

-- İstemci kendi planını okur
create or replace function public.my_plan()
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select jsonb_build_object('plan', case when plan = 'premium' and (expires_at is null or expires_at > now()) then 'premium' else 'free' end,
                               'expires_at', expires_at, 'source', source)
     from user_plans where user_id = auth.uid()),
    jsonb_build_object('plan', 'free'));
$$;
revoke all on function public.my_plan() from public;
grant execute on function public.my_plan() to authenticated;

-- Yönetici: e-postaya göre plan atar (p_days null ise süresiz)
create or replace function public.admin_set_plan(p_email text, p_plan text, p_days int default null)
returns jsonb
language plpgsql security definer set search_path = public, auth as $$
declare v_user uuid;
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_plan not in ('free', 'premium') then raise exception 'Geçersiz plan: %', p_plan; end if;
  select id into v_user from auth.users where lower(email) = lower(trim(p_email)) and not coalesce(is_anonymous, false);
  if v_user is null then raise exception 'Bu e-postayla hesap bulunamadı'; end if;
  insert into user_plans (user_id, plan, source, expires_at, updated_at)
  values (v_user, p_plan, 'manual', case when p_days is null then null else now() + make_interval(days => p_days) end, now())
  on conflict (user_id) do update set plan = excluded.plan, source = excluded.source, expires_at = excluded.expires_at, updated_at = now();
  return jsonb_build_object('user_id', v_user, 'plan', p_plan);
end $$;
revoke all on function public.admin_set_plan(text, text, int) from public;
grant execute on function public.admin_set_plan(text, text, int) to authenticated;

-- AI kotası: Premium kullanıcılarda kullanıcı kotası çarpanla artar (IP ve dakika sınırları aynı kalır)
create or replace function public.consume_ai_quota(
  p_user uuid, p_kind text, p_limit int, p_ip_hash text, p_ip_limit int, p_per_minute int
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_day date := (now() at time zone 'Europe/Istanbul')::date;
  v_minute timestamptz := date_trunc('minute', now());
  v_used int;
  v_ip int;
  v_rate int;
  v_limit int := p_limit;
begin
  if p_kind not in ('chat', 'eval', 'speech', 'tts') then
    raise exception 'Geçersiz kota türü: %', p_kind;
  end if;
  if public.is_premium(p_user) then
    v_limit := p_limit * coalesce((select value::int from app_config where key = 'premium_quota_multiplier'), 3);
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
  if v_used > v_limit then
    update ai_usage set requests = requests - 1 where user_id = p_user and day = v_day and kind = p_kind;
    if p_ip_hash is not null then
      update ai_ip_usage set requests = requests - 1 where ip_hash = p_ip_hash and day = v_day;
    end if;
    return jsonb_build_object('allowed', false, 'reason', 'quota_exceeded', 'scope', 'user', 'used', v_used - 1, 'limit', v_limit);
  end if;

  return jsonb_build_object('allowed', true, 'used', v_used, 'limit', v_limit);
end;
$$;
revoke execute on function public.consume_ai_quota(uuid, text, int, text, int, int) from public, anon, authenticated;
