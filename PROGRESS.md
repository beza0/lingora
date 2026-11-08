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
| `pnpm -C supabase/functions test` + `tsc` | 27/27 geçti, tür hatası yok |
| `pnpm -C apps/admin lint`, `test`, `build` | lint temiz, 8/8 geçti, derleme başarılı |
| `pnpm db:verify` (PostgreSQL 16) | Bütün doğrulamalar geçti: migration'lar, RLS (kullanıcılar arası erişim engeli), durum kuralları, kota ve iade, birleştirme (idempotent), toplu durum değiştirme, içerik yükleme |

## Çalıştırılmayan kontroller ve sebebi

| Kontrol | Sebep |
| --- | --- |
| Flutter uygulaması (yazma, derleme, test) | Bulut ortamında Flutter/Xcode yok; Mac'te yapılacak (`docs/FLUTTER_HANDOFF.md`) |
| `supabase test db` (pgTAP) | Docker yok. Aynı kuralların çoğu `db:verify` ile denendi. |
| Deno ile Edge Functions çalıştırma ve `deno lint` | Deno indirilemedi. Mantık Node + Vitest ile test edildi; Deno giriş dosyaları ince sarmalayıcı. |
| Gerçek Anthropic çağrısı | Anahtar henüz yok (bilinçli karar). Sağlayıcı sahte `fetch` ile test edildi. |
| Gerçek Supabase projesine yükleme (`db push`, `content:seed`, `functions deploy`) | Proje bilgileri bu ortamda yok; README adımlarıyla Mac'ten yapılacak. |
| Panelin gerçek PostgREST ile uçtan uca denenmesi | Yerel Supabase yığını yok. |

## Bilinen eksikler

- Mobil uygulama henüz yok.
- İçerik incelenmedi (test sürümü); uygulamada “İncelenmedi” rozetiyle gösterilecek.
- Apple ile giriş kapalı; push bildirimleri yok.
- GitHub'a bu oturumdan gönderilemedi; teslim git paketi ile yapıldı.
