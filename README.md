# Lingora

**İngilizce, senin alanında.** Türkçe konuşanlar için alana göre (Genel, Yazılım, Mühendislik, YDS) İngilizce öğrenme uygulaması.

> Bu bir **test sürümüdür**. İçerik taslaktır ve uygulamada “İncelenmedi” rozetiyle gösterilir. GitHub'a gönderilmesi uygulamanın yayınlandığı anlamına gelmez.

## Repo yapısı

| Klasör | İçerik | Durum |
| --- | --- | --- |
| `supabase/migrations` | Postgres şeması, RLS, tetikleyiciler, kota ve birleştirme fonksiyonları | Hazır, doğrulandı |
| `supabase/functions` | Edge Functions: `ai-chat`, `ai-evaluate`, `merge-guest`, `delete-account` | Hazır, mantık testleri geçti |
| `content` | 12 içerik paketi (YAML), şema, doğrulama, paketleme, yükleme betikleri | Hazır, 0 hata |
| `apps/admin` | React + TypeScript yönetim paneli (yerelde çalışır) | Hazır |
| `apps/mobile` | Flutter uygulaması | **Henüz yazılmadı.** Yalnız içerik paketi (`assets/content`) var. Bkz. `docs/FLUTTER_HANDOFF.md` |
| `docs` | Ürün belgesi (`BUILD_SPEC.md`), tasarım, sözleşme, mimari | — |

Ayrıntılı durum: `PROGRESS.md`. Kararlar: `DECISIONS.md`.

## Gizli bilgiler

- Hiçbir anahtar repoya girmez. `.env`, `.env.json`, `google-services.json`, `GoogleService-Info.plist` ve keystore dosyaları `.gitignore` içindedir.
- Değişken adları `.env.example` dosyasındadır. Kopyalayıp değerleri **kendi bilgisayarında** doldur: `cp .env.example .env`.
- AI anahtarı (varsayılan `GROQ_API_KEY`) yalnız Supabase Secrets'ta durur (aşağıda). Uygulamaya ve panele hiçbir zaman girmez.
- `SUPABASE_SERVICE_ROLE_KEY` yalnız yerel `content:seed` komutunda kullanılır.
- Anahtarları sohbete, issue'ya veya commit mesajına yapıştırma.

## Kurulum (Mac)

### 1. Araçlar

```bash
brew install node pnpm supabase/tap/supabase
brew install --cask flutter          # Flutter uygulaması için
xcode-select --install               # Xcode App Store'dan ayrıca kurulmalı
pnpm install                         # repo kökünde
```

Node 22 veya üstü gerekir.

### 2. Supabase test projesi (`lingora-test`, Frankfurt)

1. supabase.com'da projeyi oluştur.
2. Terminalden bağlan ve şemayı yükle:
   ```bash
   supabase login                       # tarayıcıda açılır, token sohbete girmez
   supabase init                        # yalnız supabase/config.toml yoksa; var olan dosyaları değiştirmez
   supabase link --project-ref <proje-kimliği>
   supabase db push                     # migrations klasörünü uygular
   ```
3. Test projesinde taslakları göster (SQL Editor):
   ```sql
   update app_config set value = 'true'::jsonb where key = 'show_drafts';
   ```
4. Kendini yönetici yap. Önce panelden veya uygulamadan e-postayla bir hesap aç, sonra:
   ```sql
   insert into app_admins (user_id)
   select id from auth.users where email = '<senin-e-postan>';
   ```

### 3. Kimlik doğrulama ayarları (Supabase paneli → Authentication)

- **Anonymous sign-ins**: açık (misafir modu).
- **Email**: açık, e-posta doğrulaması açık.
- **URL Configuration → Redirect URLs**: `com.beyzaacar.lingora://auth-callback` ve panel için `http://localhost:5173`.
- **Rate Limits**: anonim giriş sınırını düşük tut (ör. saatte 30).
- **Google**: Google Cloud Console'da OAuth istemcileri oluştur (Web + iOS). Web istemci kimliği ve gizli anahtarı Supabase'in Google sağlayıcı ayarına gir. iOS istemci kimliği uygulamanın `.env.json` dosyasına gider.
- **Apple**: şimdilik kapalı (`FEATURE_APPLE_SIGN_IN=false`, ücretli Apple Developer hesabı gerekir).

### 4. Edge Functions ve AI anahtarı

```bash
supabase functions deploy ai-chat
supabase functions deploy ai-evaluate
supabase functions deploy merge-guest
supabase functions deploy delete-account

# Varsayılan AI sağlayıcısı Groq'tur (ücretsiz plan, console.groq.com → API Keys).
# Anahtar hazır olduğunda (terminal geçmişine düşmemesi için):
read -s GROQ_API_KEY && supabase secrets set GROQ_API_KEY="$GROQ_API_KEY" && unset GROQ_API_KEY
supabase secrets set IP_HASH_SALT="$(openssl rand -hex 32)"
```

Ya da Supabase paneli → Edge Functions → Secrets bölümünden ekle. Başka sağlayıcı (Anthropic, Gemini, OpenAI uyumlu) için `AI_PROVIDER` ve ilgili anahtar adları `.env.example` içinde.

Anahtar ayarlanmadan önce AI uç noktaları `ai_not_configured` döner ve uygulama bunu açıkça gösterir; sahte AI cevabı üretilmez. Kota ve model gibi diğer ayarlar `.env.example` içinde listelidir.

### 5. İçeriği veritabanına yükle

```bash
pnpm content:validate
pnpm content:bundle                  # apps/mobile/assets/content/content.json üretir
pnpm content:seed                    # .env içindeki SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY ile
```

Yükleme var olan satırların inceleme durumunu değiştirmez.

### 6. Yönetim paneli

```bash
cp apps/admin/.env.example apps/admin/.env    # değerleri doldur (anon key)
pnpm -C apps/admin dev                        # http://localhost:5173
```

Yalnız `app_admins` tablosundaki hesaplar paneli kullanabilir; yetki veritabanında RLS ile denetlenir.

### 7. iPhone'da çalıştırma (ücretsiz Apple ID)

1. Xcode → Settings → Accounts: Apple ID ekle.
2. `apps/mobile/ios/Runner.xcworkspace` → Signing & Capabilities: Team = Personal Team, Bundle ID `com.beyzaacar.lingora`.
3. iPhone'u kabloyla bağla; iPhone'da Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu'nu aç.
4. `cd apps/mobile && flutter run --dart-define-from-file=.env.json`
5. İlk açılışta iPhone'da Ayarlar → Genel → VPN ve Aygıt Yönetimi → geliştiriciye güven.

Ücretsiz hesapla kurulan uygulama 7 gün sonra yeniden kurulmalıdır.

## Testler

```bash
pnpm -C content test                 # içerik şeması ve türetme (12 test)
pnpm content:validate                # sayılar, yinelenenler, kimlik kilidi
pnpm -C supabase/functions test      # Edge Functions mantığı (27 test)
pnpm -C apps/admin lint && pnpm -C apps/admin test && pnpm -C apps/admin build
pnpm db:verify                       # yerel PostgreSQL 16 ile şema, RLS, kota, birleştirme (Docker gerekmez)
supabase test db                     # pgTAP testleri (Docker + yerel Supabase gerekir)
```

## Belgeler

- `docs/BUILD_SPEC.md`: ürün ve teknik tanım (asıl kaynak)
- `docs/architecture.md`: mimari, veri modeli, eşitleme ve birleştirme
- `docs/api-contract.md`: uygulamanın kullandığı veri biçimleri ve uç noktalar
- `docs/srs.md`: FSRS ayarları, oturum kurucu, değerlendirme
- `docs/content-guide.md`: içerik yazma ve inceleme
- `docs/FLUTTER_HANDOFF.md`: Flutter uygulamasını yazacak oturum için talimat
- `docs/design/`: ekran tasarımları
