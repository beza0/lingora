# İçerik rehberi

İçerik `content/packs/<alan>/<paket>.yaml` dosyalarında yazılır. Şema: `content/schema/authoring.ts`.

## Sayılar (paket başına)

20 kelime/ifade anlamı, 10 kalıp, 2 yapı notu, 2 senaryo, 2 okuma, ayrıca yazma görevleri ve Cümle Rehberi durumları. Toplam: 240 anlam, 120 kalıp, 24 yapı notu, 24 senaryo, 24 okuma, 12 paket. `pnpm content:validate` bunları denetler.

## Kurallar

- Her anlam için: Türkçe karşılık (`tr`), alana özgü örnek (`ex`, hedef `[[...]]` içinde), örneğin Türkçesi (`extr`), en az 3 elle yazılmış çeldirici (`dis`, “seçenek | neden yanlış” biçiminde), kabul edilen alternatifler (`alt`).
- Çeldiriciler cümlede gerçekten yanlış olmalı; tek doğru cevap garanti edilmelidir.
- Kalıplarda Türkçe şablon (`ttr`) değişen parçanın yerine `…` taşır.
- Ton etiketi (`tone`): `neutral`, `formal`, `informal`, `polite`. Gerekirse kullanım notu yaz.
- Kimlik (`id`) bir kez verildikten sonra değiştirilmez; `ids.lock.json` bunu denetler. Bir hedefi kaldırmak gerekiyorsa silme, panelden `archived` yap.
- YDS paketleri sınav cümle yapısını hedefler; soru kalıbı veya gerçek sınav sorusu kopyalanmaz.

## Akış

```bash
pnpm content:validate                 # hata yoksa
pnpm content:bundle --update-lock     # yeni kimlikleri kilide ekler, content.json üretir
pnpm content:seed                     # test projesine yükler (durumları korur)
```

## İnceleme (yönetim paneli)

1. **İçerik** sayfasında hedefleri alan, paket ve duruma göre süz.
2. Hedefi aç, metinleri düzelt, kaydet (sürüm artar, geçmişe yazılır).
3. “İncelendi” → “Yayınla”. Seçili hedeflerde toplu yapılabilir; durum bağlı alıştırmalara da uygulanır.
4. **Raporlar** sayfasında kullanıcı bildirimlerini kapat.
5. **İçe aktar** sayfası JSON/CSV ile satırları taslak olarak ekler. Aynı kimlikli satır zaten varsa metni güncellenir ama inceleme durumu korunur; önizlemede hangi satırların değişeceğini kontrol et.

Test projesinde `show_drafts = true` olduğu için taslaklar da görünür. Gerçek yayından önce bu değer `false` yapılmalı ve içerik incelenmelidir.
