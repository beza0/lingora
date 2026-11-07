# Lingora — Nihai Geliştirme Talimatı (v1, test sürümü)

> Bu talimat kendi başına yeterlidir; önceki bir konuşmayı okumana gerek yok. Gizli bilgi içermez.
> Hazırlanma tarihi: 2026-11-08 · Karar belgesi: https://claude.ai/artifact/QEig4Y2H4a6qjhyTvNqJRw · Tasarım: https://claude.ai/artifact/EzVx2wQrvLYVbKKSDVDn3J

---

## 0. Görevin ve çalışma biçimin

Lingora'yı geliştir: Türkçe konuşan kullanıcılar için alan odaklı bir İngilizce öğrenme uygulaması. Slogan: **“İngilizce, senin alanında.”**

Yalnızca plan ya da ekran taslağı hazırlama. Şunların hepsini çalışır hâlde teslim et: Flutter mobil uygulama (iOS + Android), Supabase veritabanı geçişleri ve RLS, Edge Functions, başlangıç içerikleri ve yükleme komutları, React yönetim paneli, testler ve dokümantasyon.

Çalışma kuralları:

1. **Önce incele.** Çalışma klasörünü, varsa mevcut dosyaları, `docs/design/` klasörünü ve kurulu araçları kontrol et (`flutter doctor -v`, `xcodebuild -version`, `node -v`, `pnpm -v`, `supabase --version`, `docker info`, `deno --version`, `gh auth status`). Mevcut çalışmayı silme ve kontrolsüz üzerine yazma.
2. **Kısa plan ve görev listesiyle başla, sonra uygulamaya geç.** Yalnız plan sunup durma.
3. **Rutin teknik kararlar için soru sorma.** Bu belgenin kapsamadığı küçük kararları makul biçimde ver ve `DECISIONS.md` dosyasına yaz.
4. **Bağlamı dosyalarda tut.** İlerlemeyi ve kalan işleri `PROGRESS.md`, kararları `DECISIONS.md` dosyasında güncel tut. Uzun çalışmada bağlam kaybolursa bu iki dosyayla devam et.
5. **Aşama aşama ilerle** (§17). Her aşamayı kendi testleriyle doğrula ve anlamlı bir commit yap.
6. **Dış hesap veya anahtar gerektiren işler dışında her şeyi tamamla.** Eksik yapılandırmayı açıkça bildir. Çalışmayan bir entegrasyonu çalışıyormuş gibi gösterme. Sahte AI yanıtı üretme.
7. **Çalıştıramadığın kontrolü “çalıştırılmadı + neden” diye raporla.** iOS derlemesini gerçekten yapamadıysan başarılı sayma.

---

## 1. Kesin kararlar (yeniden tartışma)

| Konu | Karar |
| --- | --- |
| Platform | Flutter; iOS ve Android birlikte. Gerçek cihaz testi iPhone'da, MacBook Air M4 + Xcode ile ve ücretsiz Apple ID ile yapılır (kurulum 7 günde bir yenilenir). Android emülatörde test edilir. |
| Geliştirme makinesi | Kullanıcının MacBook'u. |
| Kapsam | Bu belgedeki her şey, tek teslimde. |
| İçerik durumu | Bu bir test sürümü; içeriği inceleyen bir editör yok. Bütün içerik `draft` durumundadır ve uygulamada “İncelenmedi” rozetiyle görünür. Yayımlama akışı çalışır ama hiçbir içerik yayımlanmış sayılmaz. |
| AI | Sağlayıcı Anthropic API'dir; yalnız sunucu tarafında kullanılır. Kodun tamamı yazılır, anahtar sonra eklenir. Anahtar yokken uygulama “AI henüz yapılandırılmadı” der; hazır içerikle çalışma tam işler. |
| AI kotası | Sohbet: misafire 3, hesaplı kullanıcıya 20 mesaj/gün. Değerlendirme: misafire 10, hesaplı kullanıcıya 50 istek/gün. Hepsi sunucu ayarıdır. |
| Giriş | Misafir (anonim), e-posta + parola, Google. Apple ile giriş kodda hazır olur ama bir özellik bayrağıyla kapalı kalır (ücretli Apple Developer üyeliği gerekir). |
| Yönetim paneli | React + TypeScript + Vite; yalnız yerelde çalışır (`pnpm dev`). İnternete açılmaz. |
| Backend | Supabase ücretsiz plan, Frankfurt bölgesi, proje adı `lingora-test`. |
| Tekrar algoritması | FSRS: deterministik, rastgelelik kapalı, testli (§9). |
| Paket kimliği | iOS bundle ID ve Android applicationId: `com.beyzaacar.lingora`. Uygulama adı: **Lingora**. |
| Derin bağlantı | `com.beyzaacar.lingora://auth-callback` |
| Repo | GitHub, kullanıcının kişisel hesabı, repo adı `lingora`, **private** (§20). |
| Ücret | Uygulama kullanıcıya ücretsizdir; ödeme ve abonelik yoktur. |

---

## 2. Ürün özeti

Uygulama yalnızca kelime kartlarından oluşmaz. Kullanıcı kendi alanının İngilizcesini şunlarla öğrenir: kelimeler ve anlamları, sık kullanılan ifadeler ve cümle kalıpları, gerçek durumlarda kullanılan tam cümleler, kısa diyaloglar ve senaryolar, okuma ve dinleme metinleri, gerektiği anda kısa gramer açıklamaları, yazılı ifade çalışmaları, AI sohbet ve aralıklı tekrar.

Öğrenme modeli: kısa tanıtım → bağlam içinde örnek → alıştırma → daha sonra hatırlama. **Arayüz ve açıklamalar Türkçe, öğrenilen içerik İngilizcedir.**

Alanlar: **Genel İngilizce** (turkuaz), **Yazılım İngilizcesi** (mavi), **Mühendislik İngilizcesi** (turuncu), **YDS/YÖKDİL** (mor). Alan anlamı hiçbir yerde yalnız renkle verilmez; her zaman ad, nokta veya ikonla birlikte gösterilir.

---

## 3. Tasarım

### 3.1 Tasarım kaynakları

- Tasarım tuvali: https://claude.ai/artifact/EzVx2wQrvLYVbKKSDVDn3J (özeldir; kullanıcının hesabıyla açılır).
- Kullanıcı tasarım dosyalarını repoya `docs/design/` altına koyar (`*.dc.html` + `canvas.json`). Bu dosyalar inline stilli HTML'dir; ölçü, renk, metin ve düzen için birincil referans olarak oku.
- Dosyalar yoksa: artifact araçların varsa tuvali oradan oku. O da yoksa bu bölümdeki yazılı tasarım kurallarıyla devam et ve durumu `PROGRESS.md` dosyasına yaz.
- Tasarım bir prototiptir; birebir piksel kopyası beklenmez. Renk, tipografi, boşluk, bileşen davranışı ve ekran içeriği ise tutarlı olmalıdır.

### 3.2 Tasarım jetonları (`lib/core/theme/` altında `ThemeExtension` olarak)

| Jeton | Açık | Koyu |
| --- | --- | --- |
| bg | #FAF8F5 | #0E1424 |
| surface | #FFFFFF | #161E33 |
| surface2 | #F3F0F8 | #1D2740 |
| text | #1E1B2E | #ECEAF4 |
| muted | #5E5A6E | #A6A3BA |
| border | #E6E1EE | #2A3452 |
| primary | #5B3FD0 | #A58DFF |
| onPrimary | #FFFFFF | #140F2E |
| primarySoft | #EEE9FC | #2A2550 |
| primaryText | #4E33C2 | #BBA8FF |
| success / successSoft | #1E7A46 / #E5F4EA | #5BD08F / #173528 |
| hint / hintSoft | #A34B07 / #FFF0E0 | #F5A25A / #3A2614 |
| danger / dangerSoft | #B3263E / #FCE8EC | #FF8A9A / #3D1A22 |
| alan: genel, yazılım, mühendislik, yds | #0B7F80, #2B63C9, #B45A0C, #6E42C8 | #3CC7C4, #6EA2FF, #F0A050, #B79BFF |

- **Yazı tipi:** Inter (`google_fonts` yerine yazı tipi dosyalarını uygulamayla birlikte paketle; çevrimdışı çalışmalı). Ölçek: Başlık 1 26/32 700 · Başlık 2 19/26 650 · Başlık 3 16/22 600 · İngilizce içerik 26/34 650 · Gövde 15/22 400 · Küçük 13/18 · Etiket 12/16 600, büyük harf.
- **Boşluk:** 4, 8, 12, 16, 20, 24, 32. Ekran kenarı 20, kart içi 16.
- **Köşe:** kart 16, düğme ve seçenek 12, çip tam yuvarlak, alt sayfa 22.
- **Çizgi ve gölge:** 1 px çizgi; gölge neredeyse hiç kullanılmaz.
- **İkonlar:** 1,8 px çizgili, yuvarlak uçlu, 22 px. Lucide benzeri bir set kullan (`lucide_icons` veya eşdeğeri). Emoji ve maskot yok.
- **Logo:** Konuşma balonuyla birleşen sade bir “L”. Mor yuvarlatılmış kare + alt solda balon kuyruğu + içinde beyaz L. SVG'si tasarım sistemi çalışma alanında; `flutter_svg` ile kullan, uygulama ikonu da bundan üretilir.
- **Bileşenler:** birincil/ikincil/metin/pasif düğme; alan çipi; durum etiketi (ikon + metin); seçenek kartı (normal, seçili, doğru, yanlış: renk + ikon + metin); ipucu kutusu (turuncu zemin); bilgi/çevrimdışı bandı; arama alanı; segment kontrol; anahtar; onay kutusu; alt menü (seçili sekmede hap zemin + kalın etiket); alt sayfa; iskelet yükleyici.
- **Erişilebilirlik:** Dokunma alanı en az 44 px. Bütün etkileşimli öğelerde `Semantics` etiketi olmalı. Kontrast en az 4,5:1 (yukarıdaki çiftler doğrulandı). Sistem yazı boyutu %200'e kadar düzeni bozmamalı. Giriş alanları klavyenin altında kalmamalı. “Azaltılmış hareket” ayarı ve sistem ayarı açıkken yalnız solma kullanılır. Animasyonlar kısa olmalı (150–200 ms); konfeti ve süs yok.
- **Temalar:** Açık ve koyu; varsayılan sistem teması.

### 3.3 Ekranlar ve rotalar (go_router)

Ekran kodları tasarımdaki çalışma alanı adlarıyla aynıdır.

| Kod | Ekran | Rota | Tasarım dosyası |
| --- | --- | --- | --- |
| M01 | Alan seçimi (ilk açılış) | `/welcome` | M01-Welcome |
| M02 | Alan ana ekranı + alan sekmeleri | `/learn` | M02-Home |
| M03 | Alan yönetimi | `/learn/domains` | M03-Domains |
| M04 | Paket detayı | `/learn/pack/:id` | (çizilmedi; M02 paket satırı ve M05 diliyle kur) |
| M05 | Öğrenme oturumu: tanıtım kartı + alıştırmalar | `/session/:id` | M05-Intro, M05-Exercise |
| M06 | Cevap geri bildirimi (oturum içi panel) | — | M06-Wrong, M06-Typing |
| M07 | Kalıp ve yapı | oturum içi / `/learn/pattern/:id` | M07-Pattern |
| M08 | Oturum özeti | `/session/:id/summary` | M08-Summary |
| M09 | Senaryo | `/scenario/:id` | M09-Scenario |
| M10 | Cümle Rehberi | `/learn/phrasebook` | M10-Phrasebook |
| M11 | Oku ve Dinle | `/reading/:id` | M11-Reading |
| M12 | İçerik ayrıntıları (alt sayfa) | sheet | M12-Details |
| M13 | Başlangıç değerlendirmesi + sonuç | `/assessment/:domain` | M13-Assessment, M13-AssessmentResult |
| M14 | Tekrar | `/review` | M14-Review |
| M15 | AI Sohbet listesi | `/chat` | M15-ChatList |
| M16 | AI sohbet | `/chat/:id` (öğrenmeden alt sayfa) | M16-Chat |
| M17 | Koleksiyonum | `/collection` | M17-Collection |
| M18 | Ekle / metinden çıkar | `/collection/add` | M18-Add |
| M19 | Profil | `/profile` | M19-Profile |
| M20 | Giriş / hesap oluştur | `/auth` (sheet) | M20-Auth |
| M21 | Ayarlar | `/profile/settings` | M21-Settings |
| S1–S5 | Yükleniyor, boş, AI yapılandırılmadı, ağ hatası, çevrimdışı | — | S1…S5 |
| D1–D4 | Koyu tema örnekleri | — | D1…D4 |
| A01–A05 | Panel: giriş, içerik listesi, düzenleyici, toplu aktarım, hata bildirimleri | panel rotaları | A01…A05 |

**Gezinme:** Beş sekmeli `StatefulShellRoute`: **Öğren · Tekrar · AI Sohbet · Koleksiyonum · Profil**. Her sekme kendi yığınını korur. Oturum, senaryo, okuma ve değerlendirme tam ekran açılır ve alt menüyü gizler. Bu ekranlardan çıkarken ilerleme kaydedilir ve önceki sekmeye dönülür. İçerik detayları, senaryolar ve Cümle Rehberi Öğren bölümünün altındadır.

---

## 4. İşlevsel gereksinimler

### 4.1 Açılış

- Uzun anket, zorunlu hesap, günlük hedef veya zorunlu seviye testi yok.
- İlk ekranın başlığı: **“Ne üzerine İngilizce öğrenmek istiyorsun?”** Altında 4 alan kartı var; birden fazla seçilebilir. Seçimden sonra alanın ana ekranı açılır ve kullanıcı hemen çalışmaya başlayabilir.
- Hesap, bildirim ve diğer izinler açılışta istenmez; ilgili eylem sırasında sunulur.
- İlk açılış ağsız da çalışır: yerel bir misafir kimliği (UUID) oluşturulur ve paketlenmiş içerik SQLite'a yüklenir.

### 4.2 Alan sekmeleri

- Öğren bölümünün üstünde eklenen alanların yatay sekmeleri ve sonda “+” bulunur.
- Sekme eklenebilir, sürükleyerek yeniden sıralanabilir ve kaldırılabilir (M03).
- Alan kaldırmak öğrenme kayıtlarını silmez (`user_domains.active = false`). Alan yeniden eklenince ilerleme ve kuyruk geri gelir.
- Her alanın kendi çalışma kuyruğu, değerlendirmesi, seviyesi ve ilerlemesi vardır.
- Alan değiştirirken yarım oturum kaybolmaz.

### 4.3 Alan ana ekranı (M02)

- Alan başlığı ve kısa açıklama.
- “Bugünkü çalışma” kartı: gerçek kuyruktan hesaplanan yeni içerik ve tekrar sayısı, “yaklaşık … dk · tahmini” süre, belirgin **Çalışmaya başla** düğmesi.
- Yarım oturum varsa **Kaldığın yerden devam et** (paket adı + adım).
- İsteğe bağlı **Başlangıç düzeyini belirle** bağlantısı.
- Konu paketleri (ilerleme çubuğu, “İncelenmedi” rozeti). Üniteler önkoşulla kilitlenmez. İçeriği olmayan paket kullanılabilir gibi gösterilmez.
- Senaryolar · Cümle Rehberi · Oku ve Dinle · Zorlandıklarımı çalış kutucukları.
- AI kartı: **“Ben bunu nasıl söylerim?”**
- Alanın ilerleme özeti: durumlara göre sayılar; “çalışılan” ile “pekişen” ayrı gösterilir.

### 4.4 Başlangıç değerlendirmesi (M13), isteğe bağlı ve alana özel

- 5–8 adımlık uyarlanabilir akış. Her adımda bir cümle gösterilir; kullanıcı **Anladım / Kısmen anladım / Anlamadım** der.
- Öz bildirim kısa anlam sorularıyla doğrulanır: 1., 3. ve 5. adımlarda ve her “Anladım” yanıtından sonra en az bir kez. Yalnız “Anladım” demesinden seviye çıkarılmaz.
- Doğrulanmış anlama zorluğu +1, kısmen ya da yanlış −1 değiştirir. Akış seviye 2'de başlar. 8 adımda biter, ya da en az 5 adımdan sonra iki yön değişikliği olursa biter. Sonuç son üç adımın ortalamasıdır.
- Sonuç ekranında bir cümlelik Türkçe özet gösterilir (ör. “Temel yazılım cümlelerini rahat anlıyorsun. Teknik kelimeler ve daha uzun cümlelerle başlayalım.”). Seçenekler: **Bu düzeyde başla / Daha kolay / Daha zor**.
- Kesin CEFR, konuşma becerisi veya genel puan iddiası yok. Ekranda “sınırlı başlangıç önerisi” olduğu yazılır.
- Değerlendirmeyi atlayan kullanıcı seviye 2'den başlar ve ilk oturumda zorluk kademeli artar. Seviye öğrenme sırasında güncellenir (§9).

### 4.5 Öğrenme oturumu (M05–M08)

- Varsayılan bölüm: en fazla 10 zamanı gelmiş tekrar + yaklaşık 5 yeni hedef (kelime, ifade veya kalıp).
- Akış: (1) sınırlı tekrar → (2) yeni içeriğin kısa tanıtımı → (3) tanıtımlar arasına dağıtılmış alıştırmalar → (4) bağlam veya kısa senaryo → (5) uygunsa kısa üretim görevi → (6) özet.
- Oturum her adımda otomatik kaydedilir; kullanıcı istediği an çıkabilir. Her alanda en fazla bir açık oturum olur. 7 günden eski yarım oturum, cevapları korunarak kapatılır.
- **Tanıtım kartı:** İngilizce içerik; içerik türü ve gerekiyorsa kelime türü; ilgili Türkçe anlam; alana uygun örnek cümle; açılabilir çeviri; dinleme; Kaydet; **Biliyorum**; AI'a sor; Hata bildir; açılabilir Ayrıntılar (M12: kelime ailesi, yakın/zıt anlam, sık birliktelikler, karıştırılanlar, diğer anlamlar, kullanım tonu ve ortamı).
- **“Biliyorum”** tanıtımı atlar ve hemen bir üretim/hatırlama sorusu sorar. Yalnız bu soruya yardımsız doğru cevap tanıtımı geçer saydırır. Tek başına “öğrenildi” anlamına gelmez.
- **Özet (M08):** yardımsız doğru, ipuçlu ve yanlış sayıları; çalışılan hedefler ve durumları; sonraki tekrar zamanı; “Daha kolay / Uygun / Daha zor” geri bildirimi.

### 4.6 Cümle ve kalıp öğrenimi (M07)

- Örnek cümle “I'm working on the login page.”; kalıp “I'm working on …”; değiştirilebilir bölüm “the login page”.
- Kullanıcı parçayı değiştirebilir (a bug fix · the payment system · a new feature); cümle ve çevirisi güncellenir.
- **Yapısını göster:** anlamlı parçalara ayrılmış açıklama. Kısa Türkçe gramer notu ve isteğe bağlı ayrıntılı mini açıklama.
- Bağlam ve ton etiketleri: Ekip mesajı, Toplantı, Teknik rapor, Günlük, Nazik, Resmî…

### 4.7 Alıştırmalar

- **Türler:** anlam seçme · bağlama uygun boşluk doldurma · eşleştirme · yakın anlam seçme · dinleyip anlam veya ifade bulma · yazarak hatırlama · diyalogda uygun yanıtı seçme · Türkçeden İngilizceye kısa ifade · kısa yazma görevi. Her oturumda bütün türler zorunlu değildir.
- **İpuçları aşamalıdır** (en fazla 2). Kullanılan ipucu kaydedilir; ipuçlu doğru cevap yardımsız doğru gibi sayılmaz.
- **Yanlış cevapta:** doğru cevap gösterilir; kısa Türkçe gerekçe verilir; uygunsa diğer seçeneklerin neden uymadığı açıklanır; hedef aynı oturumda farklı türde bir soruyla yeniden gelir.
- Birden fazla geçerli seçeneği olan soru üretilmez; doğrulayıcı bunu yakalar (§13).
- **Yazım ve anlam ayrı değerlendirilir:** büyük/küçük harf, noktalama ve kısaltma (I'm = I am) normalleştirilir; `accepted_answers` listesi kullanılır; küçük yazım farkı (Levenshtein ≤ 1, uzun kelimede ≤ 2) “anlam doğru, yazım hatası” sayılır ve açıklanır. Bu kontroller cihazda yapılır.
- **Serbest cümleler:** geçerli alternatifler kabul edilir. Yerel kontrol yetmezse `ai-evaluate` çağrılır. Yanıt yapılandırılmış çıktıdır ve sunucuda doğrulanır.
- Kullanıcı **“Seçeneklerle cevapla”** diyebilir. AI kullanılamıyorsa (anahtar yok, kota dolu, ağ yok) eşdeğer seçenekli soru sunulur.

### 4.8 Senaryolar (M09)

Her alan için gerçekçi kısa durumlar hazırlanır. Kolay düzeyde seçenekli, ileride isteğe bağlı serbest yazılı cevap kullanılır (“Kendi cevabımı yazmak istiyorum”).

- **Yazılım:** günlük toplantıda ilerleme bildirme, yardım isteme, hata bildirme, kod incelemesi isteme, bir engeli açıklama.
- **Genel:** sipariş, plan, yardım, sorun anlatma.
- **Mühendislik:** ölçüm, test, teknik sorun ve çözüm önerisi.
- **YDS/YÖKDİL:** akademik cümle yorumlama, paragraf ilişkileri, çıkarım.

### 4.9 Cümle Rehberi (M10)

- Duruma göre ifade bulma; örnek: Toplantı → Anlamadığımı belirtmek → “Could you clarify what you mean?”
- Türkçe ya da İngilizce arama ve durum filtreleri.
- Her ifadede: Türkçe anlam, kullanım yeri ve ton, seslendirme, kopyalama, koleksiyona kaydetme, isteğe bağlı tekrara ekleme.

### 4.10 Oku ve Dinle (M11)

- Kısa metinler seçilen alana ve zorluğa uygundur. Yazılımda hata kaydı, README parçası ve ekip mesajlaşması gibi özgün örnekler kullanılır.
- Metin ilk açılışta çevirisiz gösterilir; istenirse cümle bazında ya da bütün metin için çeviri açılır.
- Bir kelimeye veya ifadeye dokunulunca ayrıntı açılır; kaydetme ve AI'a sorma desteklenir.
- Metin dinlenebilir ve durdurulabilir; hız seçilebilir.
- Sonunda kısa anlama soruları bulunur.

### 4.11 AI Sohbet (M15, M16)

- Ayrı ve kalıcı bir bölümdür. Türkçe veya İngilizce serbest soru sorulabilir. Yanıt akışla görüntülenir; yeni sohbet açılabilir, geçmiş sohbetler görülebilir ve silinebilir. Yanıt durdurulabilir; hata hâlinde yeniden denenebilir. Alan bağlamı değiştirilebilir. Kalan günlük kota görünür.
- **Desteklenen ihtiyaçlar:** “Şunu nasıl söylerim?”, cümle düzeltme, mesaj veya cümle anlamı, kelime karşılaştırma, daha doğal/kısa/resmî ifade, yazılı rol yapma ve mülakat pratiği, gramer açıklaması.
- **Yanıt biçimi:** Önce doğrudan kullanılabilir İngilizce ifade, sonra en fazla 3 cümlelik Türkçe açıklama. Belirsizlik varsa kısa bir açıklama sorusu sorulur. İngilizce ifadeler özel bir blokta döner ve istemci bunları dinle/kopyala/koleksiyona ekle düğmeleriyle gösterir.
- **Öğrenmeden açılma:** “AI'a sor” sohbeti alt sayfa olarak açar; ilgili hedef, cümle ve alan bağlamı bir bağlam çipiyle taşınır. Kullanıcı kapatınca oturuma kayıpsız döner.
- AI içeriği her zaman “AI” etiketiyle gösterilir. Öğrencinin yazıları resmî içerik havuzuna eklenmez.
- **Hatalar** (ağ, kota, sağlayıcı, yapılandırma yok) anlaşılır Türkçeyle gösterilir. Kota bitince hesap açma önerilir (M20).

### 4.12 Koleksiyonum (M17, M18)

- Kaydedilmiş kelimeler, cümleler ve kalıplar; kişisel listeler; manuel kelime/cümle ekleme.
- **Yapıştırılan metinden aday çıkarma** cihazda yapılır: metin parçalara ayrılır, kökler ve çok kelimeli ifadeler içerik veritabanıyla eşleştirilir. Hazır içerikte olan ve olmayan adaylar işaretlenir. Kullanıcı onayladıktan sonra listeye eklenir. AI bu adımda kullanılmaz.
- Alan seçimi, düzenleme, silme, arama, filtre ve tekrara ekleme.
- Kaydetmek ile öğrenme durumu ayrıdır. Aynı hedef farklı listelerde bulunsa da tek tekrar kaydı vardır.
- Kişisel ve AI önerili içerik, incelenmiş hazır içerikten rozetle ayrılır.

### 4.13 Profil ve ayarlar (M19, M21)

- **Hesap:** misafir durumu ve hesap oluşturma, giriş/çıkış, hesabı ve verileri silme.
- **İlerleme:** alanlara göre.
- **Motivasyon:** haftalık hedef (“haftada X oturum”, varsayılanı kapalı); isteğe bağlı günlük seri; rozetler.
- **Ayarlar:** tema, yazı boyutu, azaltılmış hareket, ses hızı, çevrimdışı ses durumu, yerel hatırlatıcı (saat seçimi, kapatma), eşitleme durumu (bekleyen ve başarısız kayıtlar, “Yeniden dene”).

### 4.14 Seslendirme

- İlk sürümde kelime, cümle ve metin dinleme var (`flutter_tts`, `en-US` ses).
- Oynat/durdur, tekrar dinle ve hız (0,7× · 0,9× · 1,0×) desteklenir.
- Ekran değişince ses durur; sesler üst üste binmez (tek bir `AudioController`).
- Ses yoksa veya çevrimdışı desteklenmiyorsa açık bir durum gösterilir.
- Konuşma kaydı ve telaffuz puanlama kapsam dışıdır.

### 4.15 Motivasyon ve bildirim

- **Seri:** isteğe bağlı; günde en az bir tamamlanan bölüm veya tekrar parçası gerekir. Bozulunca ilerleme etkilenmez.
- **Rozetler:** İlk oturum, İlk senaryo, 7 günlük seri, 50 hedef çalışıldı, 25 hedef pekişiyor, 4 alanda çalışma.
- **Olmayacaklar:** can kaybetme, liderlik tablosu, ara verince sıfırlama.
- **Bildirim:** yalnız yerel hatırlatıcı (`flutter_local_notifications`). Bildirim izni yalnız hatırlatıcı açılınca istenir.

---

## 5. Teknik yığın

- **Mobil:** Flutter (güncel kararlı sürüm), Riverpod (kod üretimli), go_router, drift (SQLite), supabase_flutter, google_sign_in, flutter_tts, flutter_local_notifications, connectivity_plus, uuid, flutter_svg, freezed/json_serializable. FSRS için önce pub.dev'deki `fsrs` paketini değerlendir. Uygun değilse FSRS'yi referans formüllere göre `lib/domain/srs/` altında kendin yaz ve test et.
- **Panel:** React + TypeScript + Vite, @supabase/supabase-js, TanStack Query, React Router, zod, Tailwind (jetonlar §3.2'den).
- **Sunucu:** Supabase (Postgres, Auth, Storage gerekirse), Edge Functions (Deno, `npm:@anthropic-ai/sdk`), pgTAP testleri.
- **İçerik araçları:** Node 22 + TypeScript + zod (`content/scripts`).
- **Sürümler:** Birbiriyle uyumlu, desteklenen sürümleri seç ve sabitle (`pubspec.lock`, `pnpm-lock.yaml`, `deno.lock` commit edilir). Kurulum yönergeleri README'de yer alır.

---

## 6. Repo düzeni

```
lingora/
  apps/mobile/                Flutter uygulaması
    lib/core/                 tema, router, hata tipleri, ayarlar, ses denetleyicisi
    lib/data/                 drift şeması, depolar, outbox, eşitleme, Supabase istemcisi
    lib/domain/               srs (FSRS), oturum kurucu, cevap değerlendirici, seviye, değerlendirme
    lib/features/             welcome, learn, session, pattern, scenario, phrasebook, reading,
                              assessment, review, chat, collection, profile, settings, auth
    assets/content/           paketlenmiş başlangıç içeriği (content:bundle üretir)
    test/                     birim, widget ve entegrasyon testleri
  apps/admin/                 React yönetim paneli
  supabase/
    migrations/               şema, RLS, SQL fonksiyonları
    functions/                ai-chat, ai-evaluate, merge-guest, delete-account, _shared/
    tests/                    pgTAP
    config.toml               yerel geliştirme ayarları (gizli bilgi yok)
  content/
    schema/                   zod şemaları
    packs/<alan>/<paket>.json 12 paket
    scripts/                  validate.ts, bundle.ts, seed.ts
  docs/
    design/                   kullanıcının koyduğu tasarım dosyaları
    architecture.md, data-model.md, srs.md, content-guide.md, setup.md, sync-and-merge.md
  .env.example  .gitignore  README.md  PROGRESS.md  DECISIONS.md
```

---

## 7. Veri modeli

Öğrenme hedefi alandan bağımsızdır ve **anlam** (veya kalıp) düzeyindedir. Alanlar hedeflere paketler üzerinden bağlanır. Böylece “stress” (günlük: stres) ile “stress” (mühendislik: gerilme) iki ayrı hedef olur, ama aynı anlam iki alanda iki kez öğretilmez. Bir hedef iki alanın paketinde bulunuyorsa tek kartı vardır; tekrar ikisinde birden sayılır.

### 7.1 İçerik tabloları

Hepsinde şu alanlar bulunur: `status` (enum `draft | reviewed | published | archived`), `version int`, `created_at`, `updated_at`.

- `domains` (id slug: general, software, engineering, yds; name_tr, description_tr, color_key, sort)
- `packs` (id uuid, domain_id, slug, title_tr, description_tr, sort)
- `lexemes` (id, lemma, pos, is_phrase)
- `senses` (id, lexeme_id, meaning_tr, definition_en, register, notes_tr)
- `sense_usages` (sense_id, domain_id, example_en, example_tr, collocations text[], family jsonb, synonyms text[], antonyms text[], confusables jsonb, other_meanings_tr, tone_tags text[])
- `patterns` (id, template_en, slot_key, example_en, example_tr, chunks jsonb, grammar_note_id, context_tags text[], tone_tags text[])
- `pattern_slots` (id, pattern_id, text_en, text_tr, sort)
- `learning_targets` (id uuid **kalıcı**, kind `sense | pattern`, sense_id, pattern_id, difficulty 1–5). Kimlik asla yeniden kullanılmaz. Anlamı değişen içerik yeni hedef olur; eskisi `archived` yapılır.
- `pack_targets` (pack_id, target_id, sort, is_core)
- `exercises` (id, target_id, type, skill `vocab | reading | listening | writing`, prompt jsonb, answer jsonb, accepted_answers text[], distractor_notes jsonb, explanation_tr, difficulty)
- `scenarios` (id, pack_id, title_tr, situation_tr, turns jsonb, target_ids uuid[], mode `choice | free`)
- `readings` (id, pack_id, title, kind, sentences jsonb `[{en,tr}]`, glossary jsonb, questions jsonb, difficulty)
- `grammar_notes` (id, title_tr, short_tr, long_tr, examples jsonb)
- `writing_tasks` (id, pack_id, prompt_tr, rubric jsonb, sample_answers text[])
- `situations` (id, domain_id, parent_id, name_tr), `situation_items` (situation_id, target_id)
- `content_revisions` (id, entity_type, entity_id, version, snapshot jsonb, status_from, status_to, editor_id, note, created_at)
- `app_config` (key, value): `show_drafts` (test projesinde `true`), `content_version`.

### 7.2 Kullanıcı tabloları

Hepsinde `user_id uuid references auth.users` ve RLS bulunur.

- `profiles` (display_name, weekly_goal, streak_enabled, reminder_time, settings jsonb)
- `user_domains` (domain_id, sort, active, level_estimate 1–5)
- `study_sessions` (id istemci UUID, domain_id, status `in_progress | completed | abandoned`, plan jsonb, cursor int, started_at, updated_at)
- `review_events` (id istemci UUID PK, target_id, exercise_id, session_id, skill, outcome `correct | correct_with_hint | minor_spelling | incorrect`, rating 1–4, hints_used, response_ms, answered_at, received_at default now(), device_id). Kayıtlar değiştirilmez.
- `card_states` (user_id, target_id PK; stability, difficulty, due_at, reps, lapses, state, last_review_at). Olaylardan türetilir ve yeniden hesaplanabilir.
- `skill_evidence` (domain_id, skill, attempts, correct, unaided_correct)
- `saved_items` (id, target_id ya da custom_item_id, deleted_at)
- `lists`, `list_items`
- `custom_items` (text_en, meaning_tr, note, domain_id, source `manual | extracted | ai`)
- `assessments` (domain_id, steps jsonb, result_level, chosen_level)
- `chat_threads` (title, domain_id), `chat_messages` (thread_id, role, content, context_ref jsonb, model, created_at)
- `content_reports` (entity_type, entity_id, reason, text, status)
- `daily_activity` (day, sessions, targets), `user_badges` (badge_key, earned_at)
- `ai_usage` (user_id, day, kind `chat | eval`, requests, input_tokens, output_tokens). **Yalnız sunucu yazar.**
- `merge_tokens` (token_hash, anon_user_id, expires_at, used_at). **Yalnız sunucu erişir.**

### 7.3 Yetki ve RLS

- Bütün kullanıcı tablolarında: `select/insert/update/delete using (user_id = auth.uid())`. `ai_usage` ve `merge_tokens` istemciye kapalıdır.
- `app_admins(user_id)` tablosu ve `is_admin()` security-definer fonksiyonu kullanılır. İçerik tablolarına yazma yalnız `is_admin()` ile yapılır.
- İçerik okuma koşulu: `status = 'published' OR (select value from app_config where key='show_drafts') = 'true'`.
- `content_reports`: kullanıcı kendi bildirimini yazar ve okur; yönetici hepsini okur. Yönetici **chat tablolarını okuyamaz**.
- Service-role anahtarı yalnız Edge Functions'ta ve yerel içerik yükleme komutunda bulunur; uygulamaya veya panele asla girmez. Yöneticilik istemcideki bir bayrağa dayanmaz.

---

## 8. Yerel depolama, çevrimdışı çalışma ve eşitleme

- **drift:** İçerik tablolarının yerel kopyası tutulur. Kullanıcı tabloları `owner_id` ile bölünür. Bir `outbox` tablosu bulunur (op_id, table, payload, status `pending | failed | done`, attempts, last_error).
- **İçerik:** `assets/content/` ilk açılışta SQLite'a yüklenir. Ağ gelince `content_version` karşılaştırılır ve yalnız değişen paketler indirilir. Paket ekranında “çevrimdışı kullanılabilir” durumu görünür.
- **Cevaplar:** Önce SQLite'a yazılır, sonra outbox ile gönderilir. `review_events` için `insert … on conflict (id) do nothing` kullanılır; aynı kaydın tekrar gönderilmesi çift kayıt üretmez.
- **Çakışma kuralları:** Olaylar birleşim olarak alınır ve `card_states` olaylardan yeniden hesaplanır. `study_sessions`'ta `updated_at` daha yeni olan kazanır. Profil, alan, liste, kayıt ve kişisel öğelerde son yazan kazanır; silme `deleted_at` ile yapılır. Sohbet yalnız çevrimiçi çalışır; yereldeki önbellektir.
- **Zaman:** Plan istemci zamanı (`answered_at`) ile hesaplanır. Gelecekteki zaman damgaları sunucu zamanına kırpılır.
- **Outbox tetikleri:** açılış, ağın gelmesi, bölüm sonu. 5 başarısız denemeden sonra kayıt `failed` olur ve Ayarlar → Eşitleme'de görünür. Üst çubukta “eşitleme bekliyor (n)” göstergesi bulunur.
- **Çıkış:** Gönderilmemiş kayıt varsa kullanıcı uyarılır. Yalnız o `owner_id`'nin satırları silinir; içerik önbelleği kalır ve yeni bir misafir kimliği oluşturulur.
- AI'ın bağlantı gerektirdiği yazılır. Çevrimdışı ses, cihaz desteği olmadan garanti edilmez.
- Kuralların tamamını `docs/sync-and-merge.md` dosyasına yaz.

---

## 9. Tekrar (FSRS) ve kişiselleştirme

- **Ayarlar:** varsayılan FSRS ağırlıkları; hedef hatırlama 0,90; öğrenme adımları 1 dk ve 10 dk; yeniden öğrenme 10 dk; en uzun aralık 365 gün; fuzz kapalı. Parametre sürümü kodda sabittir. Aynı olay geçmişi her cihazda aynı planı üretmelidir. AI tekrar kararı vermez.
- **Cevaptan puana:**

  | Durum | Puan |
  | --- | --- |
  | Yanlış, ya da bütün ipuçlarından sonra doğru | Again (1) |
  | İpucuyla doğru, ya da anlam doğru ama yazım hatalı | Hard (2) |
  | Yardımsız doğru | Good (3) |
  | Easy (4) | Hiçbir zaman otomatik verilmez |

- Bir hedef bir bölümde birden çok kez görülürse plan yalnız ilk denemeyle puanlanır; sonraki denemeler beceri kanıtına yazılır.
- **Kullanıcıya gösterilen durumlar:** Yeni (olay yok) · Tekrar zamanı geldi (`due_at ≤ şimdi`) · Öğreniliyor (öğrenme/yeniden öğrenme ya da kararlılık < 21 gün) · Pekişiyor (tekrar durumu ve kararlılık ≥ 21 gün). Her durum ikon + metin + renkle gösterilir. Hiçbir hedef “tamamen öğrenildi” olarak gösterilmez. Kaydetmek durumu değiştirmez.
- **Birikme:** Bekleyen tekrar 50'yi aşarsa yeni hedef sayısı 3'e iner ve bu kullanıcıya söylenir. Tekrar oturumu 20'lik parçalardan oluşur; hatırlama olasılığı en düşük olanlar önce gelir. Ara vermek hiçbir şeyi sıfırlamaz.
- **Tekrar ekranı (M14):** Seçili alanı tekrar et · Tüm alanları tekrar et · Zorlandıklarımı çalış (son 30 günde ipuçlu veya yanlış cevaplanan, lapses > 0 olan hedefler). Durum dağılımı ve beceri kanıtı gösterilir.
- **Tahmini süre:** yeni hedef başına 45 sn, tekrar başına 15 sn; ekranda “yaklaşık … · tahmini” diye yazılır.
- **Zorluk ayarı (alan başına):** Yeni hedefler `difficulty ≤ level + 1` arasından seçilir. Son 20 ilk denemede yardımsız doğru oranı %85'in üstündeyse seviye +1, %60'ın altındaysa −1 olur. Oturum başına en fazla bir değişiklik yapılır; tek bir yanlış seviyeyi değiştirmez. “Daha kolay/Daha zor” seviyeyi hemen 1 kaydırır. “Bu konudan daha fazla” paket önceliğini artırır.
- **Beceri kanıtı:** Kelime, okuma, dinleme ve yazılı ifade ayrı sayılır. 10 denemeden azsa “Henüz yeterli veri yok” yazılır; 10 ve üzerinde yalnız yardımsız doğru oranı ve deneme sayısı gösterilir.
- Algoritmayı ve eşlemeyi `docs/srs.md` dosyasında örneklerle belgele.

---

## 10. AI servisi (Edge Functions)

- **Sağlayıcı katmanı:** `_shared/ai/provider.ts` içinde `AiProvider` arayüzü (`streamChat`, `structured`) ve `AnthropicProvider` sınıfı. Sağlayıcı `AI_PROVIDER` ile seçilir; model kimlikleri ortam değişkeninden okunur. Kaynak kodda anahtar veya model kimliği sabit yazılmaz (yalnız `.env.example` içinde örnek değer olarak geçer).
- **`ai-chat`:** SSE akışı. İstek gövdesi: `{threadId?, message, domainId, contextRef?}`.
- **`ai-evaluate`:** Yapılandırılmış JSON döner: `{verdict: correct|acceptable|minor_error|incorrect, meaning_ok, spelling_issues[], corrected, alternatives[], explanation_tr}`. Şema sunucuda zod ile doğrulanır. Geçersiz çıktıda bir kez yeniden denenir; yine geçersizse `422 invalid_output` döner ve istemci seçenekli soruya geçer.
- **İstek sırası:**
  1. JWT doğrulanır (anonim kullanıcı dahil); yoksa 401.
  2. Anahtar yoksa `503 ai_not_configured`.
  3. `AI_MAX_INPUT_CHARS` aşılırsa 413. Kullanıcı ve IP başına dakika sınırı aşılırsa `429 rate_limited`.
  4. `consume_ai_quota(kind)` SQL fonksiyonu kotayı tek işlemde artırır (misafir/hesaplı sınırı `auth.users.is_anonymous`'tan okunur). Doluysa `429 quota_exceeded` ve sıfırlanma zamanı (Europe/Istanbul gece yarısı) döner. İstemcinin bildirdiği sayıya güvenilmez.
  5. Bağlam kurulur: sistem yönergesi + alan + bağlam kaydı + son en fazla 10 mesaj. Bütün geçmiş gönderilmez.
  6. Sağlayıcı hatasında kota iade edilir ve `502 provider_error` döner.
  7. Mesajlar `chat_messages`'a yazılır. **Sunucu günlüklerine mesaj içeriği yazılmaz.**
- **Ortam değişkenleri** (Supabase Secrets): `ANTHROPIC_API_KEY` (gizli), `AI_PROVIDER=anthropic`, `AI_MODEL_CHAT=claude-haiku-5-5`, `AI_MODEL_EVAL=claude-haiku-5-5`, `AI_DAILY_CHAT_GUEST=3`, `AI_DAILY_CHAT_USER=20`, `AI_DAILY_EVAL_GUEST=10`, `AI_DAILY_EVAL_USER=50`, `AI_MAX_INPUT_CHARS=1000`, `AI_MAX_OUTPUT_TOKENS=600`, `AI_RATE_PER_MINUTE=6`, `ANON_SIGNUPS_PER_IP_PER_DAY=5`.
- **Misafir kötüye kullanımı:** Cloudflare Turnstile yapılandırılırsa anonim girişte CAPTCHA açılır (isteğe bağlı). Yapılandırılmazsa IP başına günlük anonim hesap ve AI sınırı uygulanır; bu durum README'de açıkça yazılır.
- **İstemci davranışı:** Her hata için Türkçe ve anlaşılır bir durum gösterilir (S3, S4, M20). Hazır öğrenme akışı AI hatasından hiç etkilenmez.

---

## 11. Hesap, misafir ve birleştirme

- **Misafir:** Yerel kimlik oluşturulur; ağ gelince Supabase anonim oturumu açılır ve yerel satırların `owner_id` değeri bu kullanıcıya bağlanır.
- **E-posta + parola:** kayıt, e-posta onayı, giriş, güvenli parola sıfırlama (derin bağlantı ile), çıkış.
- **Google:** iOS ve Android'de yerel `google_sign_in` + `signInWithIdToken`. Yapılandırma eksikse düğme gizlenir ve README'de nedeni yazılır.
- **Apple:** Kod ve düğme hazırdır ama `FEATURE_APPLE_SIGN_IN=false` iken görünmez.
- **Misafirden yeni hesaba:** Anonim kullanıcıya kimlik eklenir (`updateUser` / `linkIdentity`). `user_id` değişmez; veri taşınmaz.
- **Misafirden var olan hesaba:**
  1. Outbox boşaltılır.
  2. Misafir oturumuyla `merge-guest/prepare` çağrılır ve tek kullanımlık, 15 dakikalık bir birleştirme belirteci alınır (sunucuda hash'i saklanır).
  3. Var olan hesapla giriş yapılır ve `merge-guest/complete` belirteçle çağrılır.
  4. Birleştirme: olayların birleşimi alınır (UUID tekil) ve kartlar yeniden hesaplanır. Alanlar, listeler ve kayıtlar birleştirilir; aynı hedef iki kez kaydedilmez. Aynı alanda iki açık oturum varsa en yenisi kalır. Profilde hesabın kendi ayarları korunur.
  5. Anonim kullanıcı silinir. İşlem idempotenttir; yarıda kalırsa yeniden çağrılabilir. Kullanıcıya “n cevap ve m kayıt aktarıldı” gösterilir.
- **Hesap silme:** `delete-account` bütün kullanıcı satırlarını ve auth kaydını siler; `content_reports` anonimleştirilir; uygulama yerel veriyi temizler.
- Yapılandırılmamış bir giriş seçeneği çalışıyormuş gibi gösterilmez.

---

## 12. Yönetim paneli (A01–A05)

- Giriş Supabase Auth ile yapılır. Yetki sunucuda `is_admin()` ile kontrol edilir; yetkisiz kullanıcı içerik göremez ve hiçbir işlem yapamaz.
- **İşlevler:**
  - Alan ve paket yönetimi.
  - Kelime, anlam ve alan kullanımı yönetimi.
  - Kalıp ve cümle yönetimi.
  - Soru, cevap ve açıklama yönetimi.
  - Senaryo, metin ve gramer notu yönetimi.
  - **Taslak → İncelendi → Yayımlandı** akışı; incelenmeden yayımlama kapalıdır.
  - Toplu JSON/CSV aktarımı: önce doğrulama ve satır/konum bazlı hata raporu, hata yoksa `draft` olarak yükleme.
  - Arama ve filtre (alan, paket, tür, durum, zorluk).
  - Kullanıcı hata bildirimlerini inceleme.
  - İçerik değişiklik geçmişi.
- Önemli değişiklikler mevcut öğrenme kayıtlarını bozmaz. Kimlik kalıcıdır; anlam değişikliği yeni hedef oluşturur, düzeltmeler `version` değerini artırır.
- Panelin bir yerinde “Test projesi: `show_drafts` açık” bandı görünür.
- Yönetici kullanıcıların AI konuşmalarını göremez.
- Panel yalnız `VITE_SUPABASE_URL` ve `VITE_SUPABASE_ANON_KEY` kullanır.

---

## 13. Başlangıç içeriği

Claude Code içeriği kendisi JSON olarak yazar; bunun için Anthropic API kullanılmaz. Örnekler özgün olmalıdır. Çalışma soruları gerçek ÖSYM sorusu gibi sunulmaz.

**12 paket:**

| Alan | Paketler |
| --- | --- |
| Genel İngilizce | 1. Tanışma ve kendini anlatma · 2. Günlük yaşam ve planlar · 3. İstekler ve sorunlar |
| Yazılım | 1. Günlük toplantı ve ekip iletişimi · 2. Hatalar ve sorun giderme · 3. Kod inceleme ve değişiklikler |
| Mühendislik | 1. Teknik özellikler ve ölçümler · 2. Test ve sonuçlar · 3. Sorun açıklama ve çözüm önerme |
| YDS/YÖKDİL | 1. Araştırma ve bulgular · 2. Neden, sonuç ve karşıtlık · 3. Değişim, artış ve azalış |

**Her pakette:** 20 hedef kelime/ifade, bunlardan ayrı tanımlanmış 10 kullanılabilir cümle kalıbı, 2 kısa senaryo, seslendirilebilir 2 kısa okuma metni, 2 kısa yapı/gramer açıklaması, 1 yazma görevi. Ayrıca hedef başına en az 3, en az 2 farklı türde alıştırma ve her birine Türkçe açıklama.

**Toplamlar:** 240 hedef, 120 kalıp, 24 senaryo, 24 metin, 24 yapı açıklaması, 12 yazma görevi. Alanlar arasında ortak kelimeler olabilir; benzersiz sözcük sayısı ayrı raporlanır, toplam gibi sunulmaz.

**Sınırlar:**
- Mühendislik içeriği ortak teknik iletişimle sınırlıdır.
- YDS/YÖKDİL içeriği ortak akademik temeldir. Fen, Sağlık ve Sosyal uzmanlık paketleri yoktur ve tamamlanmış gibi gösterilmez.
- Her içeriğin 1–5 zorluk etiketi vardır. Bir paketin bütün seviyeleri kapsadığı iddia edilmez. Uygun içerik azsa bu gizlenmez; destek miktarı ve önerilen sıra ayarlanır.
- Ayrı anlamlar ayrı hedeftir: örneğin `stress` Genel'de “stres”, Mühendislik'te “gerilme” olarak iki ayrı hedeftir.
- Cümle Rehberi için her alanda durum ağacı (`situations`) doldurulur.

**Komutlar:**
- `pnpm content:validate` sıfır hatayla geçmelidir. Kontrol ettikleri:
  - paket ve toplam sayılar;
  - bütün referansların var olan kimliklere gitmesi;
  - zorunlu alanlar ve zorluk aralığı;
  - seçenekli sorularda tam olarak bir doğru cevap, tekrarlanmayan seçenekler ve her çeldiricinin gerekçesi;
  - boşluk doldurmada cevap yerleştirilince örnekle eşleşme;
  - kimliklerin tekilliği ve kararlılığı (daha önce yüklenmiş bir kimliğin silinmemesi);
  - seviye dağılımı ve benzersiz sözcük raporu.
- `pnpm content:bundle` → `apps/mobile/assets/content/`.
- `pnpm content:seed` → Supabase'e `draft` olarak, idempotent yükleme. Service-role anahtarı yalnız yerel `.env` dosyasından okunur.

Bütün içerik `draft` yüklenir. Otomatik kontroller insan incelemesi yerine geçmez ve öyle gösterilmez. İçerik inceleme ve yayımlama yönergesini `docs/content-guide.md` dosyasına yaz.

---

## 14. Kapsam dışı

Aşağıdakiler geliştirilmez ve boş ya da işlevsiz ekranları da eklenmez; yalnız gelecekte eklenebilecek sınırlar bırakılabilir:

- sesli AI görüşmesi, telaffuz puanlama
- fotoğraf veya PDF'den içerik çıkarma
- öğretmen paneli, arkadaş ve sosyal özellikler, liderlik tablosu
- ödeme ve abonelik
- içeriği hazırlanmamış diğer meslek alanları
- uzaktan anlık bildirim
- Apple girişinin açılması, TestFlight ve mağaza yayımı
- panelin internete açılması

---

## 15. Gizli bilgiler ve ortam değişkenleri

- Hiçbir anahtar, token veya parola koda, commit'e, test çıktısına ya da rapora yazılmaz. Kullanıcıdan sohbete anahtar yapıştırması istenmez.
- `.gitignore` şunları kapsar: `.env*` (`.env.example` hariç), `supabase/.temp`, `**/build`, `.dart_tool`, `node_modules`, `ios/Pods`, `*.jks`, `*.keystore`, `GoogleService-Info.plist`, `google-services.json`, `key.properties`.
- `.env.example` (değerler boş veya örnek):

```
# Mobil (flutter run --dart-define-from-file=apps/mobile/.env.json ile de verilebilir)
SUPABASE_URL=
SUPABASE_ANON_KEY=
GOOGLE_IOS_CLIENT_ID=
GOOGLE_WEB_CLIENT_ID=
FEATURE_APPLE_SIGN_IN=false
# Panel
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
# Yalnız yerel içerik yükleme komutu (asla istemciye girmez)
SUPABASE_SERVICE_ROLE_KEY=
# Edge Functions — Supabase Secrets ile ayarlanır, burada yalnız ad listesi
# ANTHROPIC_API_KEY, AI_PROVIDER, AI_MODEL_CHAT, AI_MODEL_EVAL, AI_DAILY_CHAT_GUEST, AI_DAILY_CHAT_USER,
# AI_DAILY_EVAL_GUEST, AI_DAILY_EVAL_USER, AI_MAX_INPUT_CHARS, AI_MAX_OUTPUT_TOKENS, AI_RATE_PER_MINUTE,
# ANON_SIGNUPS_PER_IP_PER_DAY, TURNSTILE_SECRET (isteğe bağlı)
```

- Anthropic anahtarı kullanıcının kendi terminalinde `supabase secrets set ANTHROPIC_API_KEY=…` ile veya Supabase panelinden girilir.

---

## 16. Kullanıcının yapması gereken dış kurulumlar

README'nin “Kurulum” bölümünde adım adım ve gereken yönlendirme adresleriyle yaz. Eksik olanları teslim raporunda listele.

1. **Mac araçları:** Flutter, Xcode, CocoaPods, Android Studio, Node 22 + pnpm, Supabase CLI, Docker Desktop, Deno, gh.
2. **Supabase projesi** `lingora-test` (Frankfurt). Authentication ayarları:
   - Anonymous sign-ins açık.
   - E-posta onayı açık.
   - Site URL ve Redirect URL: `com.beyzaacar.lingora://auth-callback`.
3. **Google Cloud:** OAuth izin ekranı; Web istemcisi (Supabase Google sağlayıcısına girilir); iOS istemcisi (bundle ID); Android istemcisi (paket adı + debug SHA-1). iOS için `Info.plist` URL şeması.
4. **Anthropic** (sonra): API anahtarı, Console'da harcama sınırı, Supabase Secrets.
5. **İsteğe bağlı:**
   - Cloudflare Turnstile.
   - Apple Developer Program (Apple girişi ve TestFlight için).
   - Gerçek kullanıcılar için özel SMTP. Supabase'in yerleşik e-postasının gönderim sınırı düşüktür; test için yeterlidir.
6. **Yönetici hesabı:** Panelde kullanılacak kullanıcıyı `insert into app_admins(user_id) values ('…')` ile ekleme (komut README'de hazır olsun).
7. **iPhone'a kurulum:** Xcode → Signing → kişisel ekip (Personal Team). Telefonda geliştirici güveni ve Developer Mode açılır. Kurulum 7 günde bir yenilenir.

---

## 17. Geliştirme sırası

Her adım kendi testleriyle kapanır. Her adımdan sonra `PROGRESS.md` güncellenir ve anlamlı bir commit yapılır.

1. Repo iskeleti, `.gitignore`, `.env.example`, `README` taslağı, `DECISIONS.md`, `PROGRESS.md`.
2. Supabase şeması, RLS, SQL fonksiyonları (`is_admin`, `consume_ai_quota`, kart yeniden hesaplama yardımcıları) ve pgTAP testleri (`supabase start` ile yerelde).
3. İçerik şeması ve doğrulayıcı, ardından 12 paketin içeriği (alan alan). Her alanın sonunda `content:validate` çalıştırılır.
4. Flutter çekirdeği: tema (açık/koyu, jetonlar, Inter), router, drift, içerik yükleme, ses denetleyicisi.
5. Alanlar: M01, sekmeler, M03, M02 (gerçek kuyruk sayılarıyla).
6. Saf Dart alan mantığı, testler önce yazılır: FSRS sarmalayıcısı, puan eşlemesi, oturum kurucu, cevap değerlendirici, seviye ayarı, değerlendirme algoritması.
7. Öğrenme oturumu (M05–M08, M12), 9 alıştırma türü, ipucu ve geri bildirim, yarım oturum.
8. Tekrar ekranı (M14), zorlandıklarım, değerlendirme (M13).
9. Senaryo (M09), Cümle Rehberi (M10), Oku ve Dinle (M11), seslendirme.
10. Koleksiyon (M17, M18), listeler, metinden aday çıkarma.
11. Kimlik (anonim, e-posta, Google, Apple bayrağı), outbox ve eşitleme, `merge-guest`, `delete-account`.
12. AI katmanı, kota, `ai-chat`, `ai-evaluate`; M15, M16 ve hata durumları (S3, S4, M20).
13. Profil, ayarlar, hedef, seri, rozetler, hatırlatıcı, erişilebilirlik geçişi (büyük yazı, VoiceOver etiketleri, azaltılmış hareket), durum ekranları (S1, S2, S5).
14. Yönetim paneli (A01–A05).
15. Son kontroller, dokümantasyon, bilinen eksikler, GitHub teslimi.

---

## 18. Test ve kabul koşulları

**Davranış testleri:**

| # | Kabul koşulu | Doğrulama |
| --- | --- | --- |
| 1 | Alan seçip hesap açmadan öğrenmeye başlama (ağsız dahil) | Widget + entegrasyon |
| 2 | İsteğe bağlı değerlendirmeyi atlama veya tamamlama | Birim + widget |
| 3 | İki alanda bağımsız çalışma (kuyruk, seviye, ilerleme) | Birim |
| 4 | Uygulama kapanınca yarım oturumun korunması | Entegrasyon (drift) |
| 5 | Kelime ve kalıp içeren oturumun tamamlanması | Widget/entegrasyon |
| 6 | İpucu ve yanlış cevapların tekrar planına etkisi | Birim (sabit tarihli FSRS senaryoları) |
| 7 | Kaydetmenin “öğrenildi” anlamına gelmemesi | Birim |
| 8 | Alan kaldırıp yeniden ekleyince kayıtların korunması | Birim + entegrasyon |
| 9 | Çevrimdışı cevapların çift kayıt olmadan eşitlenmesi | Entegrasyon (aynı outbox iki kez) + SQL |
| 10 | Misafir verisinin yeni ve var olan hesaba aktarılması | Edge Function testleri |
| 11 | Başka kullanıcının özel verisine erişimin reddedilmesi | pgTAP, her özel tablo |
| 12 | Yetkisiz kişinin panel işlemi yapamaması | pgTAP + panel testi |
| 13 | AI servis hatasında hazır öğrenme akışının sürmesi | Widget (sahte 502/429/503) |
| 14 | Anahtar yokken sahte AI yanıtı gösterilmemesi | Edge Function testi + widget |
| 15 | Bütün başlangıç içeriğinin yapısal doğrulamadan geçmesi | `pnpm content:validate` |

**Çalıştırılacak komutlar:** `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `flutter build apk --debug`, `flutter build ios --no-codesign` (Mac), `pnpm -C apps/admin lint && pnpm -C apps/admin test && pnpm -C apps/admin build`, `deno lint && deno test` (supabase/functions), `supabase test db`, `pnpm content:validate`.

**Elle kontrol listesi** (README'ye yaz; kullanıcı iPhone'da yapacak): uçak modunda ilk açılış; bir bölümü tamamlama; oturum ortasında uygulamayı kapatıp açma; koyu tema; en büyük yazı boyutu; VoiceOver ile alt menü ve tanıtım kartı; seslendirme.

---

## 19. Dokümantasyon

- `README.md`: proje özeti, gereksinimler, kurulum (§16), çalıştırma (mobil, panel, Supabase yerel/uzak), içerik komutları, test komutları, bilinen eksikler.
- `docs/architecture.md`, `docs/data-model.md`, `docs/srs.md`, `docs/sync-and-merge.md`, `docs/content-guide.md` (Taslak → İncelendi → Yayımlandı yönergesi), `docs/setup.md`.
- `PROGRESS.md` (son durum, test sonuçları) ve `DECISIONS.md`.

---

## 20. GitHub teslimi

1. `gh auth status` ile kimlik doğrulamasını kontrol et. Eksikse dur ve kullanıcıya `gh auth login` çalıştırmasını söyle; token isteme.
2. Kullanıcı adını `gh api user --jq .login` ile al. `lingora` reposu var mı bak: `gh repo view <kullanıcı>/lingora`.
   - Yoksa: `gh repo create lingora --private --source . --remote origin`.
   - Varsa: içeriğini kontrol et. Boş değilse ve bu projeye ait görünmüyorsa üzerine yazma; kullanıcıya sor. Force push yapma.
3. Commit'ten önce gizli bilgi taraması yap (`git diff --cached` içinde anahtar kalıpları; `.env` dosyalarının izlenmediğini doğrula).
4. Kod, geçişler, başlangıç içeriği, panel ve dokümantasyonu anlamlı commit'lerle ekle.
5. Kontrolleri çalıştır, sonuçları `PROGRESS.md` dosyasına ve teslim raporuna yaz.
6. `main` dalına push et ve repo bağlantısını paylaş.
7. GitHub'a yüklemek, uygulamayı mağazada yayımlamak veya bir servisi internete açmak demek değildir. Bunları yapma; ayrıca karar verilecek.

---

## 21. Bitiş raporu

İş bitince şu başlıklarla somut bir rapor ver:

1. **Çalışanlar:** cihazda veya emülatörde gerçekten çalıştırılanlar.
2. **Test edilenler:** komut, sonuç, test sayısı; çalıştırılamayanlar ve nedenleri.
3. **Yapılandırma bekleyenler:** Anthropic anahtarı, Google OAuth, Turnstile, Apple vb. ve her biri için kullanıcının yapacağı adım.
4. **Bilinen eksikler ve riskler.**
5. **Repo bağlantısı ve son commit.**

Gerçekleşmeyen bir şeyi gerçekleşmiş gibi raporlama.
