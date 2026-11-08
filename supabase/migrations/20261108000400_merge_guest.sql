-- Lingora · misafir verisini var olan hesaba birleştirme
-- Yalnız service role çağırır (merge-guest Edge Function). İşlem tek transaction'dır ve idempotenttir.
-- Kart durumları olaylardan türetildiği için birleştirilen hedeflerin card_states satırları silinir;
-- istemci, olayı olup kartı olmayan hedefleri FSRS ile yeniden hesaplayıp yazar.

create or replace function public.merge_guest_data(p_from uuid, p_to uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_events int := 0;
  v_saved int := 0;
  v_sessions int := 0;
  v_targets uuid[];
begin
  if p_from = p_to then
    raise exception 'Aynı kullanıcı birleştirilemez';
  end if;
  if not exists (select 1 from auth.users where id = p_from and is_anonymous) then
    raise exception 'Kaynak kullanıcı misafir (anonim) değil';
  end if;

  -- 1. cevap olayları: birleşim
  select coalesce(array_agg(distinct target_id), '{}') into v_targets from review_events where user_id = p_from;
  -- olay kimlikleri küresel olarak tekil olduğu için sahiplik devri çift kayıt üretmez
  update review_events set user_id = p_to where user_id = p_from;
  get diagnostics v_events = row_count;

  -- 2. kart durumları: etkilenen hedefler yeniden hesaplanacak
  delete from card_states where user_id = p_from;
  delete from card_states where user_id = p_to and target_id = any (v_targets);

  -- 3. alanlar: hedef hesapta olmayanlar eklenir, var olanlarda etkinlik birleşir
  insert into user_domains (user_id, domain_id, sort, active, level_estimate, updated_at)
  select p_to, domain_id, sort + 100, active, level_estimate, updated_at from user_domains where user_id = p_from
  on conflict (user_id, domain_id) do update
    set active = user_domains.active or excluded.active, updated_at = greatest(user_domains.updated_at, excluded.updated_at);
  delete from user_domains where user_id = p_from;

  -- 4. oturumlar: taşınır; aynı alanda birden çok açık oturum kalırsa en yenisi açık kalır
  update study_sessions set user_id = p_to where user_id = p_from;
  get diagnostics v_sessions = row_count;
  update study_sessions s set status = 'abandoned'
   where s.user_id = p_to and s.status = 'in_progress'
     and exists (select 1 from study_sessions n where n.user_id = p_to and n.domain_id = s.domain_id
                 and n.status = 'in_progress' and n.updated_at > s.updated_at);

  -- 5. kişisel öğeler ve kayıtlar
  update custom_items set user_id = p_to where user_id = p_from;
  -- aynı hedef iki kez kaydedilmez: liste öğeleri hesaptaki kayda yönlendirilir
  update list_items li set saved_item_id = t.id
    from saved_items f join saved_items t on t.user_id = p_to and t.target_id = f.target_id
   where f.user_id = p_from and f.target_id is not null and li.saved_item_id = f.id
     and not exists (select 1 from list_items x where x.list_id = li.list_id and x.saved_item_id = t.id);
  delete from saved_items f using saved_items t
   where f.user_id = p_from and t.user_id = p_to and f.target_id is not null and f.target_id = t.target_id;
  update saved_items set user_id = p_to where user_id = p_from;
  get diagnostics v_saved = row_count;
  update lists set user_id = p_to where user_id = p_from;
  update list_items set user_id = p_to where user_id = p_from;

  -- 6. diğerleri
  update assessments set user_id = p_to where user_id = p_from;
  update chat_threads set user_id = p_to where user_id = p_from;
  update chat_messages set user_id = p_to where user_id = p_from;
  update content_reports set user_id = p_to where user_id = p_from;
  insert into skill_evidence (user_id, domain_id, skill, attempts, correct, unaided_correct, updated_at)
  select p_to, domain_id, skill, attempts, correct, unaided_correct, updated_at from skill_evidence where user_id = p_from
  on conflict (user_id, domain_id, skill) do update
    set attempts = skill_evidence.attempts + excluded.attempts,
        correct = skill_evidence.correct + excluded.correct,
        unaided_correct = skill_evidence.unaided_correct + excluded.unaided_correct;
  delete from skill_evidence where user_id = p_from;
  insert into daily_activity (user_id, day, sessions, targets)
  select p_to, day, sessions, targets from daily_activity where user_id = p_from
  on conflict (user_id, day) do update
    set sessions = daily_activity.sessions + excluded.sessions, targets = daily_activity.targets + excluded.targets;
  delete from daily_activity where user_id = p_from;
  insert into user_badges (user_id, badge_key, earned_at)
  select p_to, badge_key, earned_at from user_badges where user_id = p_from
  on conflict (user_id, badge_key) do nothing;
  delete from user_badges where user_id = p_from;
  -- profil: hesabın kendi ayarları korunur; hesapta profil yoksa misafirinki taşınır
  if not exists (select 1 from profiles where user_id = p_to) then
    update profiles set user_id = p_to where user_id = p_from;
  else
    delete from profiles where user_id = p_from;
  end if;

  return jsonb_build_object('events', v_events, 'saved_items', v_saved, 'sessions', v_sessions, 'recompute_targets', cardinality(v_targets));
end;
$$;

revoke execute on function public.merge_guest_data(uuid, uuid) from public, anon, authenticated;
