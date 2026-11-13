# Lingora — Maliyet ve yayın planı

_Hazırlanma: 13 Kasım 2026. Fiyatlar aşağıdaki kaynaklardan bu tarihte okundu; yayından önce sağlayıcı sayfalarında yeniden kontrol edilmeli._

## 1. Sabit giderler

| Kalem | Ücret | Ne zaman gerekli | Not |
|---|---|---|---|
| Apple Developer Program | 99 $ / yıl | TestFlight ve App Store | Her yıl yenilenir |
| Google Play Console | 25 $ bir kez | Play Store | Yeni kişisel hesaplarda yayından önce 12 test kullanıcısıyla 14 günlük kapalı test zorunlu |
| Supabase Pro | 25 $ / ay (10 $ işlem kredisi dahil, bir Micro sunucuyu karşılar) | Gerçek kullanıcıya açılırken | Ücretsiz planda kullanılmayan proje duraklatılır; Pro'da duraklama yok, günlük yedek var |
| Vercel Pro | 20 $ / kullanıcı / ay | Ücret alınmaya başlanınca (Premium) | Hobby planı yalnız kişisel ve ticari olmayan kullanım içindir |
| Alan adı (isteğe bağlı) | ~10–15 $ / yıl | Profesyonel adres ve e-posta için | Örn. lingora.app |

**İlk yıl asgari toplam (iki mağaza + Supabase Pro, Vercel ücretsizken):** 99 + 25 + 12×25 = **424 $**
**Premium'a geçince (Vercel Pro eklenir):** aylık ~45 $ + yıllık 99 $.

## 2. Kullanıma bağlı giderler (Groq)

| Model | Fiyat | Lingora'daki kullanım |
|---|---|---|
| gpt-oss-120b (sohbet, rol yapma, yazma değerlendirmesi) | 0,15 $ / 1M giriş, 0,60 $ / 1M çıkış token | Mesaj başına ~1.500 giriş + ~400 çıkış token ≈ **0,0005 $** |
| Whisper Large v3 Turbo (konuşma → yazı) | 0,04 $ / ses saati, istek başına en az 10 sn | Kısa kayıt başına ≈ **0,0001 $** |
| Orpheus English (seslendirme) | 22 $ / 1M karakter | Her cümle bir kez üretilip depoda saklanır; tüm içerik (~100 bin karakter) ≈ **2–3 $ bir kez** |

**Kullanıcı başına AI maliyeti (aylık, üst sınır):** günde 10 sohbet mesajı + 20 konuşma kaydı yapan yoğun bir kullanıcı ≈ 300 × 0,0005 + 600 × 0,0001 ≈ **0,21 $**. Kotalar (misafir 10, hesap 20 sohbet/gün) bunun üstüne çıkılmasını engelliyor.

## 3. Senaryolar (aylık)

| Aktif kullanıcı | AI kullananların oranı | Groq | Supabase | Vercel | Toplam / ay |
|---|---|---|---|---|---|
| 100 (beta) | %50 | ~3 $ | 0–25 $ | 0 $ | **~3–28 $** |
| 1.000 | %30 | ~25 $ | 25 $ | 0–20 $ | **~50–70 $** |
| 10.000 | %20 | ~200 $ | 25 $ + olası daha büyük sunucu | 20 $ | **~250–350 $** |

Varsayımlar: AI kullanan kişi ayda ortalama 0,1 $'lık AI tüketir (yoğun kullanıcıların yarısı kadar). 10.000 kullanıcıda Supabase'in Micro sunucusu yetmeyebilir; yük testine göre bir üst boyut gerekebilir.

**Premium ile denge:** Ayda 3 $'lık bir Premium'da, mağaza payı (%15) düşünce kişi başı ~2,5 $ kalır. 1.000 kullanıcıda ~25 Premium abone (%2,5) sabit giderleri karşılar.

## 4. Yayın kontrol listesi

### Hazır
- [x] Gizlilik politikası, KVKK aydınlatma metni, kullanım şartları, hesap silme sayfası (`/legal/…`)
- [x] Onay ekranı; AI için ayrı açık rıza; uygulama içinde hesap silme ve veri dışa aktarma
- [x] Anonim hata ve kullanım kaydı, panelde Metrikler; eski verilerin otomatik temizliği
- [x] Logo ve ikonlar
- [x] Google ile giriş, e-posta ile giriş, misafir modu

### Yayından önce senin yapacakların
- [ ] Yasal metinleri bir hukukçuya okut (özellikle yurt dışı aktarım ve açık rıza)
- [ ] Google Cloud'da OAuth onay ekranını "Production"a al (şu an test modunda)
- [ ] Groq'ta Orpheus seslendirme modelinin şartlarını kabul et; Groq'ta ücretli (Developer) plana geç ve harcama sınırı koy
- [ ] Supabase'i Pro'ya geçir (duraklamayı ve yedek eksikliğini önler)
- [ ] Panelden içerik paketlerini incele ve yayımla (şu an hepsi taslak)
- [ ] Apple Developer ve Google Play hesaplarını aç
- [ ] Mağaza görselleri, açıklama metni, yaş sınırı, gizlilik etiketleri (Apple "App Privacy", Google "Data safety")
- [ ] Ayrı bir üretim Supabase projesi (test verisiyle karışmasın) — şu an tek proje `lingora-test`

### Önerilen takvim
1. **Hafta 1–2:** iç test (sen + 2–3 kişi), hataları Metrikler sayfasından izle
2. **Hafta 3–4:** Apple hesabı → TestFlight ile 10–20 kişilik kapalı beta; Google Play kapalı testi (12 kişi / 14 gün)
3. **Hafta 5–6:** düzeltmeler, mağaza sayfaları, üretim projesi
4. **Hafta 7:** yayın; Premium'u kullanıcı geri bildirimine göre aç

## Kaynaklar
- Supabase fiyatları: https://supabase.com/pricing
- Groq fiyatları: https://www.morphllm.com/groq-pricing , https://www.cloudzero.com/blog/groq-pricing/
- Vercel adil kullanım politikası: https://vercel.com/docs/limits/fair-use-policy
- Mağaza ücretleri: https://splitmetrics.com/blog/google-play-apple-app-store-fees/ , https://ilab.md/en/articles/publishing-on-the-app-store-and-google-play-in-2026-timelines-costs-and-7-hidden-requirements-that-could-derail-your-launch
