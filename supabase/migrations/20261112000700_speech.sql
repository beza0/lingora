-- Konuşma pratiği (ses → yazı) ve sunucu seslendirmesi için yeni kota türleri; seslendirme önbelleği.
alter table public.ai_usage drop constraint if exists ai_usage_kind_check;
alter table public.ai_usage add constraint ai_usage_kind_check check (kind in ('chat', 'eval', 'speech', 'tts'));

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
  if p_kind not in ('chat', 'eval', 'speech', 'tts') then
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

revoke execute on function public.consume_ai_quota(uuid, text, int, text, int, int) from public, anon, authenticated;

-- Seslendirme dosyaları: herkese açık okunur (içerik cümleleri), yalnız sunucu yazar.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('tts', 'tts', true, 2097152, array['audio/wav', 'audio/mpeg'])
on conflict (id) do nothing;
