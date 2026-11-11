# İlerleme

Son güncelleme: 2026-11-12

## Tamamlananlar

| Bölüm | İçerik |
| --- | --- |
| Tasarım | 38 ekran ve durum tasarımı (`docs/design`), açık/koyu tema |
| Veritabanı | 5 migration: içerik tabloları, kullanıcı tabloları, RLS, durum tetikleyicileri ve revizyon kaydı, AI kota fonksiyonları, misafir birleştirme, toplu durum değiştirme |
| İçerik | 12 paket (4 alan × 3): 240 anlam, 120 kalıp, 24 yapı notu, 24 senaryo, 24 okuma, yazma görevleri, Cümle Rehberi; 1427 türetilmiş alıştırma. Hepsi taslak. |
| Edge Functions | `ai-chat` (SSE), `ai-evaluate` (yerel kontrol + AI + şema doğrulama), `merge-guest`, `delete-account`; sağlayıcı katmanı, kota ve iade, hata kodları |
| Yönetim paneli | Giriş, içerik listesi ve süzme, hedef düzenleme, toplu inceleme/yayınlama, varlık tabloları, içe aktarma (önizlemeli), raporlar, değişiklik geçmişi |
| Mobil uygulama (Flutter) | Açılış/alan seçimi, Bugün, çalışma oturumu (tanıtım, 6 alıştırma türü, ipucu, geri bildirim, özet), FSRS, seviye ayarı, Keşfet (arama, paket, hedef ayrıntısı, Cümle Rehberi, okuma, senaryo), AI sohbet (SSE, `<en>` kartları, kota), başlangıç seviye testi (alan başına 5–8 soru, uyarlamalı), eşleştirme alıştırması, yazma görevleri (AI değerlendirme + örnek cevaplar), AI ile rol yapma (alan başına 3 senaryo, her turda Türkçe geri bildirim), ses efektleri, İngilizce sesli okuma, Koleksiyon, Profil (hesap, birleştirme, beceri, ayarlar, dışa aktarma, hesap silme), drift ile yerel kayıt ve eşitleme |
| Web sürümü (iPhone'da Ana Ekrana Ekle) | https://lingora-beza0s-projects.vercel.app — her `main` gönderiminde Vercel derler: `flutter analyze` + `flutter test` + `flutter build web` |
| Belgeler | README, kararlar, mimari, API sözleşmesi, FSRS, içerik rehberi, Flutter devir talimatı |

## Çalıştırılan kontroller

| Kontrol | Sonuç |
| --- | --- |
| `pnpm content:validate` | 0 hata, 0 uyarı |
| `pnpm -C content test` | 12/12 geçti |
| `pnpm -C supabase/functions test` + `tsc` | 36/36 geçti (OpenAI uyumlu sağlayıcı ve rol yapma yönergesi testleri dahil), tür hatası yok |
| `pnpm -C apps/admin lint`, `test`, `build` | lint temiz, 8/8 geçti, derleme başarılı |
| Deno 2.9 `deno check` + `deno lint` (4 fonksiyon) | Tür hatası yok, lint temiz |
| Supabase `lingora-test` (Frankfurt) | 5 migration uygulandı; 4 Edge Function yüklendi |
| Canlı uç nokta testleri (gerçek JWT ile) | `ai-chat` → `ai_not_configured` (503), oturumsuz → `unauthorized` (401); `ai-evaluate` yerel kontrol → `correct` (200), AI gereken cevap → `ai_not_configured`; `merge-guest` hesapla `prepare` → `forbidden`, geçersiz belirteç → `not_found`; `delete-account` onaysız → `invalid_request`, onaylı → kullanıcı silindi |
| pgTAP (`supabase/tests/rls.test.sql`, gerçek Supabase üzerinde) | 16/16 geçti; test verisi sonra silindi |
| Supabase güvenlik denetimi | Bulgular `20261108000600_hardening.sql` ile giderildi; kalanlar bilinçli (sunucuya özel tablolarda politika olmaması, RLS'in çağırdığı `is_admin`/`content_visible`) |
| İçerik yükleme (Supabase) | GitHub'dan çekildi, MD5 doğrulandı; 12 paket, 360 hedef, 1427 alıştırma, 24 senaryo, 24 okuma, 24 yapı notu, 12 yazma görevi. `show_drafts = true`, `content_version = ee5852d367bbe995` |
| Misafir → hesap birleştirme (canlı, uçtan uca) | Misafir RLS ile 2 cevap + 1 kayıt yazdı; `prepare` → `complete` sonrası hepsi hesaba geçti, misafir silindi, belirteç ikinci kez `not_found` |
| Auth ayarları | Anonim giriş açık (canlı doğrulandı); Site URL ve yönlendirmeler: `com.beyzaacar.lingora://auth-callback`, `http://localhost:5173` |
| Gerçek AI çağrısı (Groq, `openai/gpt-oss-120b`) | `ai-chat` SSE akışı `<en>` bloklarıyla İngilizce ifadeler + Türkçe açıklama döndü; `ai-evaluate` şemaya uygun değerlendirme döndü. Kota (misafir 1/3 sohbet, 1/10 değerlendirme), token sayımı ve mesaj kaydı doğrulandı; test verisi silindi |
| Flutter (Vercel derlemesinde) | `flutter analyze` hatasız, `flutter test` 27/27 geçti (eşleştirme ve seviye testi dahil), web derlemesi başarılı |
| Web sürümü elle deneme (telefon boyutu) | Açılış → alan seçimi → Bugün → oturum (tanıtım, anlam sorusu, yanlış/doğru geri bildirimi, çıkış onayı) → AI sohbet (gerçek Groq yanıtı, kota 1/3) çalıştı; yerel veritabanı IndexedDB üzerinde açıldı |
| iOS imzasız derleme (GitHub Actions, macOS) | Başarılı; `Lingora-unsigned-ipa` (9,5 MB). Telefonda kurulum Sideloadly ile, cihazda denenmedi |
| Google ile giriş (canlı) | Google hesabı oluştu, misafir ilerlemesi (cevap + alan) hesaba taşındı, misafir silindi |
| `pnpm db:verify` (PostgreSQL 16) | Bütün doğrulamalar geçti: migration'lar, RLS (kullanıcılar arası erişim engeli), durum kuralları, kota ve iade, birleştirme (idempotent), toplu durum değiştirme, içerik yükleme |

## Çalıştırılmayan kontroller ve sebebi

| Kontrol | Sebep |
| --- | --- |
| Android derlemesi | Denenmedi |
| Rol yapma ve yazma görevlerinin telefonda elle denenmesi | Kod Vercel'de derlenip test edildi; tarayıcıda deneme bu raporda ayrıca belirtilir |
| Panelin gerçek PostgREST ile uçtan uca denenmesi | Yerel Supabase yığını yok. |

## Bilinen eksikler

- İçerik incelenmedi (test sürümü); uygulamada “İncelenmedi” rozetiyle gösterilecek.
- Apple ile giriş kapalı; push bildirimleri yok.
- Google girişi Google Cloud'da “Testing” modunda: yalnız test kullanıcısı olarak eklenen adresler girebilir.
- Web'de cihazda İngilizce ses yoksa sesli okuma yapılmaz, ses ekleme yolu gösterilir.
- Test kullanıcıları ve geçici tablolar temizlendi; veritabanında kullanıcı yok, yalnız içerik var.
