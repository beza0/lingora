-- Lingora RLS ve fonksiyon doğrulamaları (yalın PostgreSQL + stub.sql).
-- Her başarısız beklenti istisna fırlatır; psql ON_ERROR_STOP ile çalışır.
\set ON_ERROR_STOP 1
\set QUIET 1

create schema verify;
grant usage on schema verify to anon, authenticated, service_role;

create function verify.expect_error(q text) returns void language plpgsql as $$
begin
  begin
    execute q;
  exception when others then
    return;
  end;
  raise exception 'HATA BEKLENİYORDU: %', q;
end $$;

create function verify.expect_eq(actual bigint, expected bigint, label text) returns void language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'BAŞARISIZ: % (beklenen %, gelen %)', label, expected, actual;
  end if;
  raise notice 'ok - %', label;
end $$;

create function verify.as_user(u uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u::text, false);
$$;
grant execute on all functions in schema verify to anon, authenticated, service_role;

-- ---------------------------------------------------------------- hazırlık (postgres)
insert into auth.users (id, email, is_anonymous) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com', false),
  ('00000000-0000-0000-0000-00000000000b', null, true),
  ('00000000-0000-0000-0000-00000000000c', 'admin@example.com', false);
insert into public.app_admins (user_id) values ('00000000-0000-0000-0000-00000000000c');

insert into public.packs (id, domain_id, slug, title_tr, description_tr) values
  ('10000000-0000-0000-0000-000000000001', 'software', 'verify-pack', 'Hatalar ve sorun giderme', 'Test paketi');
insert into public.lexemes (id, lemma, pos) values ('20000000-0000-0000-0000-000000000001', 'verifyword', 'verb');
insert into public.senses (id, lexeme_id, meaning_tr) values
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '(bir hatayı) yeniden oluşturmak');
insert into public.learning_targets (id, slug, kind, sense_id, difficulty) values
  ('40000000-0000-0000-0000-000000000001', 'verify-target', 'sense', '30000000-0000-0000-0000-000000000001', 2);
insert into public.pack_targets (pack_id, target_id) values
  ('10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001');

-- ---------------------------------------------------------------- 1. taslak görünürlüğü
select verify.as_user('00000000-0000-0000-0000-00000000000a');
set role authenticated;
select verify.expect_eq((select count(*) from public.learning_targets where slug = 'verify-target'), 0, 'show_drafts=false iken taslak görünmez');
reset role;
update public.app_config set value = 'true' where key = 'show_drafts';
set role authenticated;
select verify.expect_eq((select count(*) from public.learning_targets where slug = 'verify-target'), 1, 'show_drafts=true iken taslak görünür');
set role anon;
select verify.expect_eq((select count(*) from public.packs where slug = 'verify-pack'), 1, 'anon da yayın kuralıyla içerik okur');
reset role;

-- ---------------------------------------------------------------- 2. cevap olayları
select verify.as_user('00000000-0000-0000-0000-00000000000a');
set role authenticated;
insert into public.review_events (id, user_id, target_id, skill, outcome, rating, answered_at)
values ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', '40000000-0000-0000-0000-000000000001', 'vocab', 'correct', 3, now())
on conflict (id) do nothing;
insert into public.review_events (id, user_id, target_id, skill, outcome, rating, answered_at)
values ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', '40000000-0000-0000-0000-000000000001', 'vocab', 'correct', 3, now())
on conflict (id) do nothing;
select verify.expect_eq((select count(*) from public.review_events), 1, 'aynı olay iki kez gönderilince tek kayıt kalır');
select verify.expect_error($q$insert into public.review_events (id, user_id, target_id, skill, outcome, rating, answered_at)
  values (gen_random_uuid(), '00000000-0000-0000-0000-00000000000b', '40000000-0000-0000-0000-000000000001', 'vocab', 'correct', 3, now())$q$);
update public.review_events set rating = 1;
select verify.expect_eq((select count(*) from public.review_events where rating = 1), 0, 'cevap olayı değiştirilemez');
delete from public.review_events;
select verify.expect_eq((select count(*) from public.review_events), 1, 'cevap olayı silinemez');
reset role;

-- ---------------------------------------------------------------- 3. kullanıcılar arası yalıtım
select verify.as_user('00000000-0000-0000-0000-00000000000b');
set role authenticated;
insert into public.card_states (user_id, target_id, stability, difficulty, due_at, state)
values ('00000000-0000-0000-0000-00000000000b', '40000000-0000-0000-0000-000000000001', 1, 5, now(), 1);
insert into public.lists (id, user_id, name) values ('60000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000b', 'B listesi');
insert into public.chat_threads (id, user_id) values ('70000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000b');
insert into public.chat_messages (thread_id, user_id, role, content) values ('70000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000b', 'user', 'özel mesaj');
reset role;

select verify.as_user('00000000-0000-0000-0000-00000000000a');
set role authenticated;
select verify.expect_eq((select count(*) from public.card_states), 0, 'A, B''nin kart durumlarını göremez');
select verify.expect_eq((select count(*) from public.review_events where user_id <> '00000000-0000-0000-0000-00000000000a'), 0, 'A yalnız kendi olaylarını görür');
select verify.expect_eq((select count(*) from public.chat_messages), 0, 'A, B''nin sohbetini göremez');
update public.lists set name = 'ele geçirildi';
reset role;
select verify.expect_eq((select count(*) from public.lists where name = 'ele geçirildi'), 0, 'A, B''nin listesini değiştiremez');

select verify.as_user('00000000-0000-0000-0000-00000000000a');
set role authenticated;
insert into public.saved_items (id, user_id, target_id) values ('80000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a', '40000000-0000-0000-0000-000000000001');
select verify.expect_error($q$insert into public.list_items (list_id, saved_item_id, user_id)
  values ('60000000-0000-0000-0000-00000000000b', '80000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a')$q$);
select verify.expect_error($q$insert into public.chat_messages (thread_id, user_id, role, content)
  values ('70000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a', 'user', 'sızma')$q$);
reset role;

-- ---------------------------------------------------------------- 4. yönetim yetkisi
select verify.as_user('00000000-0000-0000-0000-00000000000a');
set role authenticated;
select verify.expect_error($q$insert into public.lexemes (id, lemma, pos) values (gen_random_uuid(), 'hack', 'verb')$q$);
update public.learning_targets set status = 'reviewed' where slug = 'verify-target';
select verify.expect_eq((select count(*) from public.learning_targets where slug = 'verify-target' and status = 'reviewed'), 0, 'yönetici olmayan içerik durumunu değiştiremez');
select verify.expect_eq((select count(*) from public.content_revisions), 0, 'yönetici olmayan değişiklik geçmişini göremez');
update public.app_config set value = 'false' where key = 'show_drafts';
select verify.expect_eq((select count(*) from public.app_config where key = 'show_drafts' and value = 'true'), 1, 'yönetici olmayan ayar değiştiremez');
select verify.expect_eq((select public.is_admin()::int), 0, 'is_admin() A için false');
reset role;

select verify.as_user('00000000-0000-0000-0000-00000000000c');
set role authenticated;
select verify.expect_eq((select public.is_admin()::int), 1, 'is_admin() yönetici için true');
select verify.expect_error($q$update public.learning_targets set status = 'published' where slug = 'verify-target'$q$);
update public.learning_targets set status = 'reviewed' where slug = 'verify-target';
update public.learning_targets set status = 'published' where slug = 'verify-target';
select verify.expect_eq((select count(*) from public.learning_targets where slug = 'verify-target' and status = 'published'), 1, 'incelendi → yayımlandı geçişi çalışır');
update public.senses set meaning_tr = 'yeniden oluşturmak (hata)' where id = '30000000-0000-0000-0000-000000000001';
select verify.expect_eq((select version from public.senses where id = '30000000-0000-0000-0000-000000000001'), 2, 'içerik değişince sürüm artar');
select verify.expect_eq((select count(*) from public.content_revisions where entity_type = 'learning_targets' and status_to = 'published'), 1, 'yayın geçişi geçmişe yazılır');
select verify.expect_eq((select count(*) from public.chat_messages), 0, 'yönetici kullanıcı sohbetlerini göremez');
select verify.expect_error($q$insert into public.lexemes (id, lemma, pos, status) values (gen_random_uuid(), 'direct', 'adj', 'published')$q$);
reset role;

-- ---------------------------------------------------------------- 5. hata bildirimleri
select verify.as_user('00000000-0000-0000-0000-00000000000a');
set role authenticated;
insert into public.content_reports (user_id, entity_type, entity_id, reason) values
  ('00000000-0000-0000-0000-00000000000a', 'exercise', '40000000-0000-0000-0000-000000000001', 'two_correct');
reset role;
select verify.as_user('00000000-0000-0000-0000-00000000000b');
set role authenticated;
select verify.expect_eq((select count(*) from public.content_reports), 0, 'B, A''nın bildirimini göremez');
reset role;
select verify.as_user('00000000-0000-0000-0000-00000000000c');
set role authenticated;
select verify.expect_eq((select count(*) from public.content_reports), 1, 'yönetici bildirimleri görür');
reset role;

-- ---------------------------------------------------------------- 6. AI kotası
select verify.as_user('00000000-0000-0000-0000-00000000000a');
set role authenticated;
select verify.expect_error($q$select public.consume_ai_quota('00000000-0000-0000-0000-00000000000a', 'chat', 100, null, 100, 100)$q$);
select verify.expect_eq((select count(*) from public.ai_usage), 0, 'istemci ai_usage okuyamaz');
reset role;

set role service_role;
select verify.expect_eq((select (public.consume_ai_quota('00000000-0000-0000-0000-00000000000b', 'chat', 2, 'iphash', 50, 10)->>'allowed')::boolean::int), 1, 'kota 1/2');
select verify.expect_eq((select (public.consume_ai_quota('00000000-0000-0000-0000-00000000000b', 'chat', 2, 'iphash', 50, 10)->>'allowed')::boolean::int), 1, 'kota 2/2');
select verify.expect_eq((select (public.consume_ai_quota('00000000-0000-0000-0000-00000000000b', 'chat', 2, 'iphash', 50, 10)->>'allowed')::boolean::int), 0, 'kota dolunca reddedilir');
select public.refund_ai_quota('00000000-0000-0000-0000-00000000000b', 'chat', 'iphash');
select verify.expect_eq((select (public.consume_ai_quota('00000000-0000-0000-0000-00000000000b', 'chat', 2, 'iphash', 50, 10)->>'allowed')::boolean::int), 1, 'iade sonrası tekrar izin verilir');
select verify.expect_eq((select (public.consume_ai_quota('00000000-0000-0000-0000-00000000000b', 'eval', 10, 'iphash', 50, 4)->>'allowed')::boolean::int), 0, 'dakika sınırı aşılınca reddedilir');
reset role;

select verify.as_user('00000000-0000-0000-0000-00000000000b');
set role authenticated;
select verify.expect_eq((select requests from public.my_ai_usage() where kind = 'chat'), 2, 'kullanıcı kendi kullanımını okuyabilir');
reset role;


-- ---------------------------------------------------------------- 6b. misafir birleştirme
insert into auth.users (id, email, is_anonymous) values ('00000000-0000-0000-0000-00000000000d', null, true);
insert into public.review_events (id, user_id, target_id, skill, outcome, rating, answered_at) values
  ('50000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000000d', '40000000-0000-0000-0000-000000000001', 'vocab', 'incorrect', 1, now()),
  ('50000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-00000000000d', '40000000-0000-0000-0000-000000000001', 'vocab', 'correct', 3, now());
insert into public.card_states (user_id, target_id, stability, difficulty, due_at, state) values
  ('00000000-0000-0000-0000-00000000000a', '40000000-0000-0000-0000-000000000001', 3, 5, now(), 2);
insert into public.saved_items (id, user_id, target_id) values ('80000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-00000000000d', '40000000-0000-0000-0000-000000000001');
insert into public.lists (id, user_id, name) values ('60000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-00000000000d', 'Misafir listesi');
insert into public.list_items (list_id, saved_item_id, user_id) values ('60000000-0000-0000-0000-00000000000d', '80000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-00000000000d');
insert into public.user_domains (user_id, domain_id, active) values
  ('00000000-0000-0000-0000-00000000000d', 'software', true), ('00000000-0000-0000-0000-00000000000d', 'yds', true),
  ('00000000-0000-0000-0000-00000000000a', 'software', false);
insert into public.study_sessions (id, user_id, domain_id, plan, started_at, updated_at) values
  ('90000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-00000000000d', 'software', '{}', now(), now()),
  ('90000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a', 'software', '{}', now() - interval '1 day', now() - interval '1 day');

select verify.as_user('00000000-0000-0000-0000-00000000000a');
set role authenticated;
select verify.expect_error($q$select public.merge_guest_data('00000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-00000000000a')$q$);
reset role;
set role service_role;
select verify.expect_error($q$select public.merge_guest_data('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000c')$q$);
select verify.expect_eq((select (public.merge_guest_data('00000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-00000000000a')->>'events')::bigint), 2, 'misafirin olayları hesaba taşınır');
select verify.expect_eq((select (public.merge_guest_data('00000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-00000000000a')->>'events')::bigint), 0, 'birleştirme tekrar çalışınca hiçbir şey çoğalmaz');
reset role;
select verify.expect_eq((select count(*) from public.review_events where user_id = '00000000-0000-0000-0000-00000000000a'), 3, 'hesapta tekil olaylar birleşir');
select verify.expect_eq((select count(*) from public.review_events where user_id = '00000000-0000-0000-0000-00000000000d'), 0, 'misafirde olay kalmaz');
select verify.expect_eq((select count(*) from public.card_states where user_id = '00000000-0000-0000-0000-00000000000a' and target_id = '40000000-0000-0000-0000-000000000001'), 0, 'etkilenen kart yeniden hesaplanmak üzere silinir');
select verify.expect_eq((select count(*) from public.saved_items where user_id = '00000000-0000-0000-0000-00000000000a' and target_id = '40000000-0000-0000-0000-000000000001'), 1, 'aynı hedef iki kez kaydedilmez');
select verify.expect_eq((select count(*) from public.list_items li join public.saved_items s on s.id = li.saved_item_id where li.list_id = '60000000-0000-0000-0000-00000000000d' and s.user_id = '00000000-0000-0000-0000-00000000000a'), 1, 'liste öğesi hesaptaki kayda bağlanır');
select verify.expect_eq((select count(*) from public.user_domains where user_id = '00000000-0000-0000-0000-00000000000a'), 2, 'alanlar birleşir');
select verify.expect_eq((select active::int from public.user_domains where user_id = '00000000-0000-0000-0000-00000000000a' and domain_id = 'software'), 1, 'alan etkinliği birleşir');
select verify.expect_eq((select count(*) from public.study_sessions where user_id = '00000000-0000-0000-0000-00000000000a' and status = 'in_progress'), 1, 'aynı alanda tek açık oturum kalır');
select verify.expect_eq((select count(*) from public.study_sessions where id = '90000000-0000-0000-0000-00000000000d' and status = 'in_progress'), 1, 'en yeni oturum açık kalır');

-- ---------------------------------------------------------------- 7. hesap silme
delete from auth.users where id = '00000000-0000-0000-0000-00000000000a';
select verify.expect_eq((select count(*) from public.review_events where user_id = '00000000-0000-0000-0000-00000000000a'), 0, 'hesap silinince olaylar silinir');
select verify.expect_eq((select count(*) from public.content_reports where user_id is null), 1, 'hesap silinince bildirim anonimleşir');

\echo 'TÜM DOĞRULAMALAR GEÇTİ'
