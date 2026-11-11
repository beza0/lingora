-- Yeni alanlar: sağlık, turizm, hukuk. İçerik satırları content.sql ile yüklenir.
alter table public.domains drop constraint if exists domains_id_check;
alter table public.domains add constraint domains_id_check
  check (id in ('general', 'software', 'engineering', 'yds', 'health', 'tourism', 'law'));

insert into public.domains (id, name_tr, description_tr, color_key, sort, status) values
  ('health', 'Sağlık İngilizcesi', 'Muayene, belirtiler, hasta öyküsü ve ilaç talimatı.', 'health', 5, 'draft'),
  ('tourism', 'Turizm İngilizcesi', 'Otel, resepsiyon, rezervasyon ve misafir karşılama.', 'tourism', 6, 'draft'),
  ('law', 'Hukuk İngilizcesi', 'Sözleşme dili, haklar ve yükümlülükler, hukuki yazışma.', 'law', 7, 'draft')
on conflict (id) do nothing;
