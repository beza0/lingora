-- Seviye alanları: A1–C2 (CEFR). İçerik satırları content.sql ile yüklenir.
alter table public.domains drop constraint if exists domains_id_check;
alter table public.domains add constraint domains_id_check
  check (id in ('general', 'software', 'engineering', 'yds', 'health', 'tourism', 'law', 'a1', 'a2', 'b1', 'b2', 'c1', 'c2'));

insert into public.domains (id, name_tr, description_tr, color_key, sort, status) values
  ('a1', 'A1 · Başlangıç', 'am/is/are, present simple, there is/are; kendini, aileni ve gününü anlatma.', 'a1', 11, 'draft'),
  ('a2', 'A2 · Temel', 'Past simple, gelecek planları, karşılaştırma; geçmişi ve planları anlatma.', 'a2', 12, 'draft'),
  ('b1', 'B1 · Orta', 'Present perfect, if cümleleri, -ing/to; deneyim, tavsiye ve görüş.', 'b1', 13, 'draft'),
  ('b2', 'B2 · Orta üstü', 'Relative clauses, bağlaçlar, 3. tip if, wish; tartışma ve pişmanlık.', 'b2', 14, 'draft'),
  ('c1', 'C1 · İleri', 'Devrik yapı, cleft cümleler, akademik ve resmî dil.', 'c1', 15, 'draft'),
  ('c2', 'C2 · Ustalık', 'Subjunctive, karma if, deyimler ve üslup inceliği.', 'c2', 16, 'draft')
on conflict (id) do nothing;
