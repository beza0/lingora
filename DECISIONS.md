# Kararlar

Bu dosya geliştirme sırasında verilen kararları tutar. Ürün kararlarının tamamı `docs/BUILD_SPEC.md` içindedir; burada yalnız o belgede olmayan ya da onu netleştiren kararlar yer alır.

| Tarih | Karar | Gerekçe |
| --- | --- | --- |
| 2026-11-08 | Flutter dışındaki bölümler (Supabase, içerik, Edge Functions, panel) bulut ortamında yazıldı; Flutter uygulaması Mac'teki Claude Code ile yazılacak. | Bulut ortamının ağ izinleri Flutter SDK, Android SDK, Docker ve Deno indirmeyi engelliyor; iOS derlemesi Mac gerektiriyor. |
| 2026-11-08 | SQL testleri iki biçimde: `supabase/tests/*.test.sql` (pgTAP, `supabase test db`) ve `supabase/verify/` (yalın PostgreSQL üzerinde çalışan doğrulama betiği, auth şeması taklidiyle). | Bulut ortamında pgTAP ve Docker yok; yerel Postgres 16 var. |
| 2026-11-08 | Hedef kimlikleri içerik dosyalarında `slug` olarak yazılır; UUID'ler `uuidv5(namespace, slug)` ile deterministik üretilir. | Kimlikler kararlı kalır, dosyalar okunabilir olur; aynı slug her zaman aynı UUID'yi üretir. |
| 2026-11-08 | Alıştırmaların bir kısmı içerik verisinden kurallı olarak türetilir (anlam seçme, Türkçeden İngilizceye yazma); bağlam boşluk doldurma çeldiricileri elle yazılır. | Tutarlılık ve hacim; elle yazılan çeldiriciler tek doğru cevabı garanti eder. |
| 2026-11-08 | Edge Functions iş mantığı `_shared/` altında saf TypeScript modülleri olarak yazıldı ve Node + Vitest ile test edildi; Deno giriş dosyaları ince sarmalayıcıdır. | Deno bulut ortamında yok; mantık yine de test edilebilsin. |
| 2026-11-08 | Yönetim paneli TypeScript 6.0 ile sabitlendi. | typescript-eslint henüz TypeScript 7'yi desteklemiyor. |
| 2026-11-08 | İnceleme akışı `set_target_status(hedefler, durum)` RPC'si ile yapılır; durum hedefe bağlı sözcük, anlam, kullanım, kalıp ve alıştırmalara sırayla uygulanır. Yalnız yöneticiler çağırabilir. | Panelde tek tıkla tutarlı durum değişikliği; tetikleyiciler draft → published atlamasını yine engeller. |
| 2026-11-08 | Misafir birleştirmesi olayları taşır ve etkilenen hedeflerin `card_states` satırlarını siler; uygulama bu hedefleri olay geçmişinden FSRS ile yeniden hesaplar (`recompute_targets`). | FSRS hesabı istemcide; sunucuda ikinci bir uygulama tutulmadı. |
| 2026-11-08 | Misafir hesabı açma sınırı Supabase Auth'un yerleşik hız sınırına bırakıldı; AI uç noktalarında ek olarak IP başına günlük sınır var (`AI_IP_DAILY_LIMIT`, IP yalnız tuzlu SHA-256 olarak saklanır). | Anonim hesapları kod tarafında sınırlamak için Auth kancası gerekir; test sürümü için yerleşik sınır yeterli. |
| 2026-11-08 | Supabase test projesi `lingora-test` (ref `djeuqmxlndfgeofxloht`, eu-central-1) bu oturumda kuruldu; repo `beza0/lingora` gizli. | Kurulum adımları README'de; yeniden kurulumda aynı sıra izlenir. |
| 2026-11-08 | Varsayılan AI sağlayıcısı Groq (`openai/gpt-oss-120b`, ücretsiz plan); Anthropic, Gemini ve OpenAI uyumlu servisler `AI_PROVIDER` ile seçilebilir. | Test sürümü ücretsiz kalsın; Groq ücretsiz planı kredi kartı istemiyor ve veriyi eğitimde kullanmıyor. Ücretsiz plan sınırları sağlayıcıya göre değişebilir. |
