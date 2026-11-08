# Tekrar algoritması (FSRS) ve kişiselleştirme

Tekrar planı **FSRS** ile hesaplanır. Ayarlar sabittir, rastgelelik kapalıdır: aynı olay geçmişi her cihazda aynı planı üretir. AI tekrar kararı vermez.

## Ayarlar

| Ayar | Değer |
| --- | --- |
| Ağırlıklar | Kütüphanenin varsayılan FSRS ağırlıkları (sürümü `pubspec.lock` ile sabit) |
| Hedef hatırlama | 0,90 |
| Öğrenme adımları | 1 dk, 10 dk |
| Yeniden öğrenme adımı | 10 dk |
| En uzun aralık | 365 gün |
| Fuzz | kapalı |

Kart durumu (`card_states`) her zaman `review_events` olaylarının `answered_at` sırasıyla yeniden oynatılmasından türetilebilir. `scheduled = false` olan olaylar plana katılmaz, yalnız beceri kanıtına yazılır.

## Cevaptan puana

| Durum (`outcome`) | FSRS puanı |
| --- | --- |
| `incorrect` ya da bütün ipuçlarından sonra doğru | Again (1) |
| `correct_with_hint` veya `minor_spelling` | Hard (2) |
| `correct` (yardımsız) | Good (3) |
| — | Easy (4) hiçbir zaman otomatik verilmez |

- Bir hedef aynı bölümde birden çok kez görülürse plan için yalnız **ilk** deneme puanlanır (`scheduled = true`); sonrakiler `scheduled = false`.
- “Biliyorum” tanıtımı atlar ve bir üretim sorusu (`recall_typing` veya `tr_to_en`) sorar; yalnız bu cevap puanlanır.
- Kaydetmek kart durumunu değiştirmez.

## Kullanıcıya gösterilen durum

| Durum | Kural |
| --- | --- |
| Yeni | Planlanan olay yok |
| Tekrar zamanı geldi | `due_at ≤ şimdi` |
| Öğreniliyor | öğrenme/yeniden öğrenme durumu ya da kararlılık < 21 gün |
| Peki̇şiyor | tekrar durumu ve kararlılık ≥ 21 gün |

Hiçbir hedef “tamamen öğrenildi” olarak gösterilmez.

## Oturum kurucu

1. En fazla 10 zamanı gelmiş tekrar seçilir; hatırlama olasılığı en düşük olanlar önce gelir.
2. Yaklaşık 5 yeni hedef seçilir: alanın paket sırasına göre, `difficulty ≤ level + 1` olanlardan. Bekleyen tekrar 50'yi aşarsa yeni hedef sayısı 3'e iner ve bu kullanıcıya söylenir.
3. Her yeni hedef için tanıtım kartı ve 1–2 alıştırma gelir; önceki hedeflerin alıştırmaları araya serpiştirilir. Yanlış cevaplanan hedef aynı bölümde farklı türde bir soruyla yeniden gelir.
4. Bölüm sonunda varsa kısa senaryo adımı (`dialogue_choice`), uygunsa üretim görevi gelir.
5. Tahmini süre: yeni hedef başına 45 sn, tekrar başına 15 sn (“yaklaşık … · tahmini”).

## Zorluk ayarı (alan başına)

- `user_domains.level_estimate` 1–5 arasıdır; değerlendirme yapılmadıysa 2'dir.
- Son 20 ilk denemede yardımsız doğru oranı %85'in üstündeyse +1, %60'ın altındaysa −1. Bölüm başına en fazla bir değişiklik yapılır; tek bir yanlış seviyeyi değiştirmez.
- “Daha kolay” / “Daha zor” geri bildirimi seviyeyi hemen 1 kaydırır; “Bu konudan daha fazla” o paketin önceliğini artırır.

## Başlangıç değerlendirmesi

1. Seviye 2'deki bir cümleyle başlar. Kullanıcı Anladım / Kısmen / Anlamadım der.
2. 1., 3. ve 5. adımlarda ve her “Anladım” yanıtından sonra en az bir kez kısa anlam sorusu sorulur.
3. Doğrulanmış anlama +1, kısmen/yanlış −1. 8 adımda biter, ya da en az 5 adımdan sonra iki yön değişikliği olursa biter.
4. Sonuç son üç adımın ortalamasıdır (yuvarlanır, 1–5). Bir cümlelik Türkçe özet gösterilir. CEFR veya puan gösterilmez.

Cümleler alanın paketlerindeki `sense_usages.example_en` ve `patterns.example_en` alanlarından, hedef zorluğuna göre seçilir. Anlam sorusu, o hedefin `meaning_choice` alıştırmasıdır.

## Beceri kanıtı

Kelime, okuma, dinleme ve yazılı ifade ayrı sayılır (`exercises.skill`). Bir beceride 10'dan az deneme varsa “Henüz yeterli veri yok” yazılır; 10 ve üzerinde yalnız yardımsız doğru oranı ve deneme sayısı gösterilir.

## Test edilmesi gereken senaryolar (Dart birim testleri)

- Yeni kart + Good → öğrenme adımı; aynı geçmiş iki kez oynatılınca aynı `due_at`.
- İpuçlu doğru (Hard) ile yardımsız doğru (Good) farklı aralık üretir; Hard aralığı daha kısadır.
- Again → lapses + 1, yeniden öğrenme.
- Kayıt (save) olayı kart durumunu değiştirmez.
- Bölümde ikinci deneme plana etki etmez.
- 30 gün ara → kart sıfırlanmaz, `due` geçmiş olarak görünür.
