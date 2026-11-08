# İlerleme

Son güncelleme: 2026-11-08

## Tamamlananlar

| Bölüm | İçerik |
| --- | --- |
| Tasarım | 38 ekran ve durum tasarımı (`docs/design`), açık/koyu tema |
| Veritabanı | 5 migration: içerik tabloları, kullanıcı tabloları, RLS, durum tetikleyicileri ve revizyon kaydı, AI kota fonksiyonları, misafir birleştirme, toplu durum değiştirme |
| İçerik | 12 paket (4 alan × 3): 240 anlam, 120 kalıp, 24 yapı notu, 24 senaryo, 24 okuma, yazma görevleri, Cümle Rehberi; 1427 türetilmiş alıştırma. Hepsi taslak. |
| Edge Functions | `ai-chat` (SSE), `ai-evaluate` (yerel kontrol + AI + şema doğrulama), `merge-guest`, `delete-account`; sağlayıcı katmanı, kota ve iade, hata kodları |
| Yönetim paneli | Giriş, içerik listesi ve süzme, hedef düzenleme, toplu inceleme/yayınlama, varlık tabloları, içe aktarma (önizlemeli), raporlar, değişiklik geçmişi |
| Belgeler | README, kararlar, mimari, API sözleşmesi, FSRS, içerik rehberi, Flutter devir talimatı |

## Çalıştırılan kontroller

| Kontrol | Sonuç |
| --- | --- |
| `pnpm content:validate` | 0 hata, 0 uyarı |
| `pnpm -C content test` | 12/12 geçti |
| `pnpm -C supabase/functions test` + `tsc` | 35/35 geçti (OpenAI uyumlu sağlayıcı testleri dahil), tür hatası yok |
| `pnpm -C apps/admin lint`, `test`, `build` | lint temiz, 8/8 geçti, derleme başarılı |
| Deno 2.9 `deno check` + `deno lint` (4 fonksiyon) | Tür hatası yok, lint temiz |
| Supabase `lingora-test` (Frankfurt) | 5 migration uygulandı; 4 Edge Function yüklendi |
| Canlı uç nokta testleri (gerçek JWT ile) | `ai-chat` → `ai_not_configured` (503), oturumsuz → `unauthorized` (401); `ai-evaluate` yerel kontrol → `correct` (200), AI gereken cevap → `ai_not_configured`; `merge-guest` hesapla `prepare` → `forbidden`, geçersiz belirteç → `not_found`; `delete-account` onaysız → `invalid_request`, onaylı → kullanıcı silindi |
| pgTAP (`supabase/tests/rls.test.sql`, gerçek Supabase üzerinde) | 16/16 geçti; test verisi sonra silindi |
| Supabase güvenlik denetimi | Bulgular `20261108000600_hardening.sql` ile giderildi; kalanlar bilinçli (sunucuya özel tablolarda politika olmaması, RLS'in çağırdığı `is_admin`/`content_visible`) |
| İçerik yükleme (Supabase) | GitHub'dan çekildi, MD5 doğrulandı; 12 paket, 360 hedef, 1427 alıştırma, 24 senaryo, 24 okuma, 24 yapı notu, 12 yazma görevi. `show_drafts = true`, `content_version = ee5852d367bbe995` |
| Misafir → hesap birleştirme (canlı, uçtan uca) | Misafir RLS ile 2 cevap + 1 kayıt yazdı; `prepare` → `complete` sonrası hepsi hesaba geçti, misafir silindi, belirteç ikinci kez `not_found` |
| Auth ayarları | Anonim giriş açık (canlı doğrulandı); Site URL ve yönlendirmeler: `com.beyzaacar.lingora://auth-callback`, `http://localhost:5173` |
| `pnpm db:verify` (PostgreSQL 16) | Bütün doğrulamalar geçti: migration'lar, RLS (kullanıcılar arası erişim engeli), durum kuralları, kota ve iade, birleştirme (idempotent), toplu durum değiştirme, içerik yükleme |

## Çalıştırılmayan kontroller ve sebebi

| Kontrol | Sebep |
| --- | --- |
| Flutter uygulaması (yazma, derleme, test) | Bulut ortamında Flutter/Xcode yok; Mac'te yapılacak (`docs/FLUTTER_HANDOFF.md`) |
| Gerçek AI çağrısı | `GROQ_API_KEY` henüz eklenmedi. Sağlayıcılar sahte `fetch` ile test edildi; anahtarsız uç noktalar canlıda `ai_not_configured` dönüyor. |
| Panelin gerçek PostgREST ile uçtan uca denenmesi | Yerel Supabase yığını yok. |

## Bilinen eksikler

- Mobil uygulama henüz yok.
- İçerik incelenmedi (test sürümü); uygulamada “İncelenmedi” rozetiyle gösterilecek.
- Apple ile giriş kapalı; push bildirimleri yok.
- Google ile giriş henüz yapılandırılmadı (Google Cloud OAuth istemcisi gerekiyor).
- Test kullanıcıları ve geçici tablolar temizlendi; veritabanında kullanıcı yok, yalnız içerik var.
