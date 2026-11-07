# Kararlar

Bu dosya geliştirme sırasında verilen kararları tutar. Ürün kararlarının tamamı `docs/BUILD_SPEC.md` içindedir; burada yalnız o belgede olmayan ya da onu netleştiren kararlar yer alır.

| Tarih | Karar | Gerekçe |
| --- | --- | --- |
| 2026-11-08 | Flutter dışındaki bölümler (Supabase, içerik, Edge Functions, panel) bulut ortamında yazıldı; Flutter uygulaması Mac'teki Claude Code ile yazılacak. | Bulut ortamının ağ izinleri Flutter SDK, Android SDK, Docker ve Deno indirmeyi engelliyor; iOS derlemesi Mac gerektiriyor. |
| 2026-11-08 | SQL testleri iki biçimde: `supabase/tests/*.test.sql` (pgTAP, `supabase test db`) ve `supabase/verify/` (yalın PostgreSQL üzerinde çalışan doğrulama betiği, auth şeması taklidiyle). | Bulut ortamında pgTAP ve Docker yok; yerel Postgres 16 var. |
| 2026-11-08 | Hedef kimlikleri içerik dosyalarında `slug` olarak yazılır; UUID'ler `uuidv5(namespace, slug)` ile deterministik üretilir. | Kimlikler kararlı kalır, dosyalar okunabilir olur; aynı slug her zaman aynı UUID'yi üretir. |
| 2026-11-08 | Alıştırmaların bir kısmı içerik verisinden kurallı olarak türetilir (anlam seçme, Türkçeden İngilizceye yazma); bağlam boşluk doldurma çeldiricileri elle yazılır. | Tutarlılık ve hacim; elle yazılan çeldiriciler tek doğru cevabı garanti eder. |
| 2026-11-08 | Edge Functions iş mantığı `_shared/` altında saf TypeScript modülleri olarak yazıldı ve Node + Vitest ile test edildi; Deno giriş dosyaları ince sarmalayıcıdır. | Deno bulut ortamında yok; mantık yine de test edilebilsin. |
