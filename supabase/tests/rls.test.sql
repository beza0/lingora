-- pgTAP: `supabase test db` ile çalışır (yerel Supabase, Docker gerekir).
-- Aynı kuralların yalın Postgres sürümü: supabase/verify/tests.sql
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email, is_anonymous) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com', false),
  ('00000000-0000-0000-0000-00000000000b', null, true),
  ('00000000-0000-0000-0000-00000000000c', 'admin@example.com', false);
insert into public.app_admins (user_id) values ('00000000-0000-0000-0000-00000000000c');
insert into public.packs (id, domain_id, slug, title_tr, description_tr) values
  ('10000000-0000-0000-0000-000000000001', 'software', 'tap-pack', 'Test', 'Test');
insert into public.lexemes (id, lemma, pos) values ('20000000-0000-0000-0000-000000000001', 'taptest', 'verb');
insert into public.senses (id, lexeme_id, meaning_tr) values ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'test');
insert into public.learning_targets (id, slug, kind, sense_id, difficulty) values
  ('40000000-0000-0000-0000-000000000001', 'tap-target', 'sense', '30000000-0000-0000-0000-000000000001', 2);
update public.app_config set value = 'false' where key = 'show_drafts';

-- A
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
set local role authenticated;
select is((select count(*)::int from public.learning_targets where slug = 'tap-target'), 0, 'taslak show_drafts=false iken gizli');
select lives_ok($$insert into public.review_events (id, user_id, target_id, skill, outcome, rating, answered_at)
  values ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', '40000000-0000-0000-0000-000000000001', 'vocab', 'correct', 3, now())$$, 'kendi olayını ekler');
select lives_ok($$insert into public.review_events (id, user_id, target_id, skill, outcome, rating, answered_at)
  values ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', '40000000-0000-0000-0000-000000000001', 'vocab', 'correct', 3, now())
  on conflict (id) do nothing$$, 'tekrar gönderim hatasız');
select is((select count(*)::int from public.review_events), 1, 'çift kayıt yok');
select throws_ok($$insert into public.review_events (id, user_id, target_id, skill, outcome, rating, answered_at)
  values (gen_random_uuid(), '00000000-0000-0000-0000-00000000000b', '40000000-0000-0000-0000-000000000001', 'vocab', 'correct', 3, now())$$,
  '42501', null, 'başkası adına olay eklenemez');
select throws_ok($$insert into public.lexemes (id, lemma, pos) values (gen_random_uuid(), 'x', 'verb')$$, '42501', null, 'yönetici olmayan içerik ekleyemez');
select throws_ok($$select public.consume_ai_quota('00000000-0000-0000-0000-00000000000a', 'chat', 100, null, 100, 100)$$, '42501', null, 'istemci kota fonksiyonunu çağıramaz');
select is((select public.is_admin()), false, 'A yönetici değil');
reset role;

-- B
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
set local role authenticated;
select is((select count(*)::int from public.review_events), 0, 'B, A''nın olaylarını göremez');
insert into public.chat_threads (id, user_id) values ('70000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000b');
insert into public.chat_messages (thread_id, user_id, role, content) values ('70000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000b', 'user', 'özel');
reset role;

-- Yönetici
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
set local role authenticated;
select is((select public.is_admin()), true, 'C yönetici');
select is((select count(*)::int from public.learning_targets where slug = 'tap-target'), 1, 'yönetici taslağı görür');
select throws_ok($$update public.learning_targets set status = 'published' where slug = 'tap-target'$$, '23514', null, 'incelenmeden yayımlanamaz');
select lives_ok($$update public.learning_targets set status = 'reviewed' where slug = 'tap-target'$$, 'incelendi işaretlenir');
select lives_ok($$update public.learning_targets set status = 'published' where slug = 'tap-target'$$, 'incelenmiş içerik yayımlanır');
select is((select count(*)::int from public.chat_messages), 0, 'yönetici sohbetleri göremez');
reset role;

-- Hesap silme
delete from auth.users where id = '00000000-0000-0000-0000-00000000000a';
select is((select count(*)::int from public.review_events where user_id = '00000000-0000-0000-0000-00000000000a'), 0, 'hesap silinince olaylar silinir');

select * from finish();
rollback;
