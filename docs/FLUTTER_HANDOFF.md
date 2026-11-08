# Flutter uygulaması için devir talimatı

Bu belge, `apps/mobile` uygulamasını Mac'te yazacak Claude Code oturumu içindir. Oturumu repo kökünde aç ve şunu yaz:

> `docs/FLUTTER_HANDOFF.md` dosyasını oku ve uygula.

## Önce bil

- Flutter dışındaki her şey **hazır ve test edildi**: Supabase şeması (`supabase/migrations`), Edge Functions (`supabase/functions`), içerik (`content/`, üretilmiş paket `apps/mobile/assets/content/content.json`), yönetim paneli (`apps/admin`). Bunları **yeniden yazma ve kontrolsüz değiştirme**. Bir sözleşme değişikliği gerekirse önce sebebini `DECISIONS.md` dosyasına yaz, ilgili testi güncelle.
- Asıl ürün tanımı: `docs/BUILD_SPEC.md`. Ekran tasarımları: `docs/design/*.dc.html` (tarayıcıda açılır). Sunucu sözleşmesi: `docs/api-contract.md`. Tekrar algoritması: `docs/srs.md`. Mimari: `docs/architecture.md`.
- Gizli bilgileri kullanıcıdan sohbete yapıştırmasını isteme. `apps/mobile/.env.json` dosyasını kullanıcı kendi doldurur (`.gitignore` içinde); örneği `apps/mobile/.env.json.example` olarak sen oluştur (yalnız anahtar adları).
- Sahte AI cevabı üretme. AI uç noktası `ai_not_configured` dönerse bunu tasarımdaki durum ekranıyla göster.

## Teknik çerçeve

- Flutter (kararlı sürüm), Dart 3, **Riverpod**, **go_router**, **drift** (SQLite), `supabase_flutter`, `google_sign_in`, `flutter_tts`, `fsrs` (pub.dev; uygun değilse `docs/srs.md` ayarlarıyla kendin yaz ve test et).
- Bundle ID / applicationId: `com.beyzaacar.lingora`. Derin bağlantı: `com.beyzaacar.lingora://auth-callback`.
- Yapılandırma `--dart-define-from-file=.env.json`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_IOS_CLIENT_ID`, `GOOGLE_WEB_CLIENT_ID`, `FEATURE_APPLE_SIGN_IN`.
- Değer yoksa uygulama çökmesin: çevrimdışı içerik ve yerel çalışma devam etsin, hesap/AI bölümleri “yapılandırılmadı” göstersin.
- Arayüz dili Türkçe. Tasarım: sade, göz yormayan; açık ve koyu tema; dinamik yazı boyutu; 44 pt dokunma alanı; ekran okuyucu etiketleri.

## Yapılacaklar (sırayla)

1. `flutter create --org com.beyzaacar --project-name lingora apps/mobile` (yalnız `assets/` varken; var olan `assets/content` dosyalarını silme). iOS en düşük sürüm 15. `pubspec.yaml` içinde `assets/content/` tanımla.
2. **Yerel veritabanı (drift):** içerik tabloları `content.json` içinden ilk açılışta (ya da `version.json` değişince) doldurulur. Kullanıcı tabloları sunucudakilerle aynı kolonlara sahip olur ve bir `sync_queue` tablosu eklenir.
3. **Kimlik:** ilk açılışta anonim oturum (`signInAnonymously`). E-posta kaydında anonim kullanıcı `updateUser` ile dönüştürülür. Var olan hesaba girişte `merge-guest` akışı (`prepare` → giriş → `complete`), ardından `recompute_targets` için FSRS yeniden hesaplama. Google girişi `signInWithIdToken`. Apple düğmesi bayrakla gizli.
4. **FSRS ve oturum kurucu:** `docs/srs.md` aynen. Birim testleri o belgedeki senaryoları kapsamalı.
5. **Alıştırmalar:** `docs/api-contract.md` §1.1'deki bütün türler; cevap karşılaştırma §3 (Dart'a çevir, `supabase/functions/_shared/evaluation.ts` ile aynı sonuçları verdiğini testle). İpuçları en fazla 2, sırayla. Dinleme `flutter_tts` (en-US).
6. **Ekranlar:** `docs/design` içinde `M*` mobil ekranlar, `S*` durum ekranları (boş, çevrimdışı, AI yapılandırılmadı, hata), `D*` koyu tema örnekleri; `A*` yönetim paneline aittir (zaten yapıldı). Taslak içerikte “İncelenmedi” rozeti.
7. **AI:** sohbet SSE akışı (meta/delta/done/error), Durdur düğmesi bağlantıyı kapatır, `<en>…</en>` blokları ayrı kart. Değerlendirme yanıtındaki `source` alanına göre etiket (“Yerel kontrol” / “AI değerlendirmesi”). Kota hatasında `resets_at` saatini göster; misafirse hesap oluşturmaya yönlendir.
8. **Eşitleme:** `docs/architecture.md` “Eşitleme” bölümü. Çevrimdışıyken her şey çalışır; kuyruk bağlantı gelince boşalır; olaylar yeniden gönderilirse yinelenmez.
9. **Hesap ve gizlilik:** veri dışa aktarma (JSON), hesap silme (`delete-account`, onay ekranı), içerik bildirimi (`content_reports`).
10. **Testler:** birim (FSRS, karşılaştırma, oturum kurucu, eşitleme kuyruğu), widget (alıştırma ekranları, hata durumları), `flutter analyze` sıfır uyarı.
11. **iPhone'da çalıştırma:** README §7. Ücretsiz Apple ID ile Personal Team; push bildirimleri ve Apple ile giriş bu hesapta yok, eklenmez.

## Bitirince

- `PROGRESS.md` dosyasına mobil bölümünü ekle: yapılanlar, çalıştırılan testler ve sonuçları, **çalıştırılmayan** kontroller ve sebebi.
- Anlamlı adımlarda commit et. `.env.json`, `GoogleService-Info.plist`, `google-services.json` asla commit edilmez; commit öncesi `git status` ile kontrol et.
- GitHub'a göndermek uygulamayı yayınlamak değildir; TestFlight veya mağaza adımı bu kapsamda yok.
