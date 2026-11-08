# Mobil uygulama için sunucu sözleşmesi

Bu belge Flutter uygulamasının kullandığı veri biçimlerini ve uç noktaları tanımlar. Kaynak kod: `supabase/`, `content/`.

## 1. Çevrimdışı içerik paketi

`apps/mobile/assets/content/content.json` dosyası `pnpm content:bundle` ile üretilir. Biçimi: tablo adı → satır listesi. Satırlar veritabanı satırlarıyla birebir aynıdır.

| Anahtar | Not |
| --- | --- |
| `content_version` | İçeriğin karması. Sunucudaki `app_config.content_version` ile karşılaştırılır. |
| `domains`, `packs`, `pack_targets` | Alanlar, paketler ve paket → hedef bağlantısı (`sort` < 100 kelime/ifade, ≥ 100 kalıp). |
| `lexemes`, `senses`, `sense_usages` | Sözcük → anlam → alana özgü kullanım (örnek, birliktelikler, aile, karıştırılanlar…). |
| `patterns`, `pattern_slots` | Kalıp, Türkçe şablon (`template_tr`, `…` yerine parça çevirisi gelir), değişen parçalar. |
| `learning_targets` | Kalıcı hedef kimliği. `kind`: `sense` / `pattern`. `slug` = `alan:kimlik`. |
| `exercises` | Alıştırmalar. Bkz. §1.1. |
| `scenarios`, `readings`, `grammar_notes`, `pack_grammar_notes`, `writing_tasks` | Senaryo, okuma, yapı notu, yazma görevi. |
| `situations`, `situation_items` | Cümle Rehberi ağacı (üst durum → alt durum → hedefler). |

Bütün satırlar `status: "draft"` taşır. Test projesinde uygulama taslakları **“İncelenmedi”** rozetiyle gösterir. Sunucu `app_config.show_drafts = false` ise yalnız `published` satırları döndürür; uygulama da yerel pakette aynı kuralı uygulamalıdır.

### 1.1 Alıştırma türleri (`exercises.type`)

| Tür | `prompt` | `answer` | Not |
| --- | --- | --- | --- |
| `meaning_choice` | `instruction_tr`, `text`, `sentence?`, `options[]` | `index` | Kalıplarda `text` tam cümledir, beceri `reading`. |
| `cloze_choice` | `instruction_tr`, `sentence` (`____` içerir), `sentence_tr`, `options[]`, `hints_tr[]` | `index`, `text` | `distractor_notes[seçenek]` = neden yanlış. |
| `recall_typing` | `instruction_tr`, `sentence`, `sentence_tr`, `hints_tr[2]` | `text` | `accepted_answers` ile karşılaştır (§3). |
| `listen_choice` | `instruction_tr`, `audio_text`, `options[]` | `index` | `audio_text` cihaz TTS ile okunur. |
| `tr_to_en` | `instruction_tr`, `text_tr`, `hints_tr[]` | `text` | Önce yerel kontrol, gerekirse `ai-evaluate`. |
| `matching` | `instruction_tr`, `left[]`, `right[]` | `pairs[[en,tr]]` | `group_target_ids`: eşleştirmedeki 4 hedef. |
| `dialogue_choice` | `instruction_tr`, `context[{speaker,en}]`, `options[]`, `scenario_id` | `index` | Senaryodaki seçim adımı. |
| `synonym_choice`, `short_writing` | — | — | Şemada var; başlangıç içeriğinde kullanılmıyor. Yazma görevleri `writing_tasks` tablosunda. |

İpuçları `hints_tr` sırasıyla açılır (en fazla 2). Her alıştırmada `explanation_tr` vardır.

## 2. Kullanıcı tabloları (doğrudan Supabase, RLS)

Bütün yazmalarda `user_id = auth.uid()` olmalıdır; RLS başka türlüsünü reddeder.

- `review_events`: yalnız `insert … on conflict (id) do nothing` (istemci UUID'si). Güncelleme ve silme yoktur.
- `card_states`: istemci FSRS ile hesaplar ve upsert eder. Birleştirmeden sonra bazı satırlar silinir; olayı olup kartı olmayan hedefler yeniden hesaplanır.
- `study_sessions`, `user_domains`, `profiles`, `lists`, `list_items`, `saved_items`, `custom_items`, `assessments`, `skill_evidence`, `daily_activity`, `user_badges`: satır bazlı upsert.
- `content_reports`: `insert` (`status = 'open'`).
- RPC `my_ai_usage()` → `[{kind, requests}]`: bugünkü AI kullanımı (yalnız gösterim için; sayım sunucuda yapılır).

## 3. Cevap karşılaştırma kuralları (istemcide de aynısı)

`normalize`: küçük harf; ’ → '; `i am → i'm`, `do not → don't`, `does not → doesn't`, `it is → it's`, `you are → you're`, `we are → we're`, `i have → i've`, `i would → i'd`, `i will → i'll`; noktalama kaldırılır; boşluklar tekleşir.

- Normalleştirilmiş cevap kabul edilenlerden biriyle aynıysa **doğru**.
- Levenshtein ≤ 1 (12 karakterden uzunsa ≤ 2) ise **anlam doğru, yazım hatası** (FSRS'de Hard).
- Diğer durumlar: `tr_to_en` ve yazma görevlerinde `ai-evaluate`; `recall_typing` için **yanlış**.

Başvuru uygulaması: `supabase/functions/_shared/evaluation.ts`.

## 4. Edge Functions

Bütün isteklerde `Authorization: Bearer <kullanıcı JWT>` gönderilir (anonim misafir dahil). Hata gövdesi her zaman `{"error": {"code", "message", …}}` biçimindedir.

| Kod | HTTP | Uygulamanın davranışı |
| --- | --- | --- |
| `unauthorized` | 401 | Oturumu yenile. |
| `ai_not_configured` | 503 | “AI henüz yapılandırılmadı” durumu (S3) + seçenekli çalışma. |
| `quota_exceeded` | 429 | `limit`, `resets_at`, `guest` alanları; misafirse hesap oluşturma (M20). |
| `rate_limited` | 429 | Kısa bekleme mesajı. |
| `too_long` | 413 | `max` karakter sınırı. |
| `provider_error` | 502 | “Yeniden dene” (S4); kota iade edilmiştir. |
| `invalid_output` | 422 | Seçenekli soruya düş. |
| `not_found`, `invalid_request`, `forbidden`, `server_error` | 404/400/403/500 | Genel hata durumu. |

### `POST /functions/v1/ai-chat` (SSE)

İstek: `{ "thread_id"?: uuid, "message": string, "domain_id"?: "general"|"software"|"engineering"|"yds", "context"?: { "kind", "text", "meaning_tr", "pack_title" } }`

Yanıt `text/event-stream`:

```
event: meta   data: {"thread_id": "...", "used": 4, "limit": 20}
event: delta  data: {"text": "..."}        (birden çok)
event: done   data: {"usage": {"input": 120, "output": 85}}
event: error  data: {"code": "provider_error", "message": "..."}   (akış ortasında kesilirse)
```

Yanıt metnindeki `<en>…</en>` blokları kullanılabilir İngilizce ifadelerdir; uygulama bunları dinle, kopyala ve koleksiyona ekle düğmeleriyle ayrı gösterir. İstemci bağlantıyı kapatırsa (Durdur) sunucu sağlayıcı isteğini iptal eder ve gelen kısmı kaydeder.

### `POST /functions/v1/ai-evaluate`

İstek: `{ "task": { "skill": "vocab"|"writing", "prompt_tr", "expected", "accepted": [], "answer", "rubric"?: [] } }`

Yanıt:
- `{"source": "local", "outcome": "correct"|"minor_spelling", "matched"}`: AI çağrılmadı, kota düşmedi.
- `{"source": "ai", "evaluation": {"verdict": "correct"|"acceptable"|"minor_error"|"incorrect", "meaning_ok", "spelling_issues": [{"wrong","right"}], "corrected", "alternatives": [], "explanation_tr"}, "used", "limit"}`

FSRS eşlemesi: `correct`/`acceptable` → Good, `minor_error` → Hard, `incorrect` → Again.

### `POST /functions/v1/merge-guest`

1. Misafir oturumuyla `{ "action": "prepare" }` → `{ "token", "expires_at" }` (15 dk).
2. Var olan hesapla giriş yapıldıktan sonra `{ "action": "complete", "token" }` → `{ "merged": true, "counts": { "events", "saved_items", "sessions", "recompute_targets" } }`.

`not_found` belirteç kullanılmış veya süresi geçmiş demektir; uygulama bu durumda birleştirmenin tamamlandığını varsayıp yeniden eşitleme yapar.

### `POST /functions/v1/delete-account`

İstek `{ "confirm": true }` → `{ "deleted": true }`. Uygulama ardından yerel kullanıcı verisini siler ve yeni bir misafir kimliği oluşturur.
