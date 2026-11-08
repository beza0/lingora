# Mimari

```
Flutter uygulaması ──(anon key + kullanıcı JWT, RLS)──► Supabase Postgres
   │  yerel SQLite (drift): içerik paketi + kullanıcı verisi + eşitleme kuyruğu
   └──(JWT)──► Edge Functions ──► Anthropic API (anahtar yalnız burada)
Yönetim paneli (yerel) ──(yönetici JWT, RLS + is_admin)──► Supabase Postgres
content/ (YAML) ──validate/bundle──► content.json (uygulama) ──seed──► Postgres
```

## İçerik modeli

- **Öğrenme hedefi** (`learning_targets`) bir sözcüğün tek bir anlamı (`kind = sense`) ya da bir kalıptır (`kind = pattern`). Hedef alandan bağımsızdır; alanlara paketler (`pack_targets`) üzerinden bağlanır. Aynı anlam başka bir alanda yeniden kullanılırsa tekrar planı ortak kalır.
- Sözcük → anlam → alana özgü kullanım: `lexemes` → `senses` → `sense_usages`.
- Kimlikler `uuidv5(6f1d2b3c-8a4e-5f60-9b7c-2d3e4f5a6b7c, "<tür>:<alan>:<kimlik>")` ile üretilir; `content/ids.lock.json` daha önce verilen kimlikleri kilitler.
- Durumlar: `draft → reviewed → published` (`archived` ayrıca). Tetikleyici `draft → published` atlamasını engeller, her değişiklikte `version` artırır ve `content_revisions` tablosuna kayıt yazar.
- `app_config.show_drafts` false ise kullanıcılar yalnız `published` satırları görür (`content_visible()`).

## Kullanıcı verisi

- Bütün kullanıcı tablolarında RLS: `user_id = auth.uid()`. Misafir de gerçek bir (anonim) Supabase kullanıcısıdır.
- `review_events` değişmez olay kaydıdır; birincil anahtar istemcide üretilen UUID'dir, bu yüzden yeniden gönderim zararsızdır.
- `card_states` olaylardan türetilir; kaybolsa bile olaylardan yeniden kurulabilir.
- `ai_usage`, `ai_ip_usage`, `ai_rate`: yalnız sunucu fonksiyonları yazar (security definer).

## Eşitleme

1. Uygulama her şeyi önce yerel SQLite'a yazar ve bir kuyruk satırı ekler.
2. Ağ varsa kuyruk sırayla gönderilir: olaylar `insert … on conflict do nothing`, diğer tablolar `upsert`.
3. Çakışma kuralı: olaylar birleştirilir (hiçbiri kaybolmaz); profil ve ayarlarda son yazan kazanır (`updated_at`); kart durumu olaylardan yeniden hesaplanır.
4. Uygulama açılışta ve öne geldiğinde sunucudan değişen satırları çeker (`updated_at > son eşitleme`).

## Misafir → hesap birleştirme

1. Misafir oturumuyla `merge-guest {action: prepare}` çağrılır → tek kullanımlık belirteç (yalnız SHA-256 karması saklanır, 15 dk).
2. Kullanıcı var olan hesabıyla giriş yapar.
3. `merge-guest {action: complete, token}` → `merge_guest_data(misafir, hesap)`:
   - olaylar hesaba taşınır (yinelenen kimlik varsa atlanır),
   - etkilenen hedeflerin `card_states` satırları silinir ve `recompute_targets` olarak döner,
   - kaydedilenler, listeler, oturumlar, beceri kanıtı, günlük etkinlik, rozetler birleştirilir,
   - misafir hesabı silinir.
4. Uygulama `recompute_targets` için kart durumunu olay geçmişinden yeniden hesaplar ve yükler.

Fonksiyon idempotenttir: ikinci çağrı bir şey taşımaz. Yeni hesap açılırken (e-posta kaydı) birleştirme gerekmez; Supabase anonim kullanıcıyı `updateUser` ile kalıcı hesaba dönüştürür.

## AI

- `AiProvider` arayüzü: `OpenAICompatProvider` (varsayılan Groq; Gemini, OpenRouter vb.) ve `AnthropicProvider`. Seçim `AI_PROVIDER` ile, kurulum `_shared/ai/factory.ts` içinde.
- Her istekten önce `consume_ai_quota`: dakika sınırı, IP günlük sınırı, kullanıcı günlük sınırı (gün İstanbul saatiyle). Sağlayıcı hata verirse `refund_ai_quota` ile iade.
- `ai-evaluate` önce yerel karşılaştırma yapar (kota düşmez); gerekirse AI'ı çağırır ve çıktıyı şemaya göre doğrular, geçersizse `invalid_output`.
- Anahtar yoksa `ai_not_configured`. Uygulama hiçbir durumda yerel olarak sahte AI cevabı üretmez.

## Hesap silme

`delete-account {confirm: true}` kullanıcıyı `auth.admin.deleteUser` ile siler; kullanıcı tabloları `on delete cascade` ile temizlenir. İçerik raporlarında `user_id` boşaltılır.
