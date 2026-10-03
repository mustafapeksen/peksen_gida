# Pekşen Gıda doğrulama ve test planı

Kaynak: [Peksen_Gida_Teknik_Tasarim_v3.docx](Peksen_Gida_Teknik_Tasarim_v3.docx), özellikle §26–27, §33–37. Kayıt tarihi: 2 Ekim 2026; son durum kontrolü: 3 Ekim 2026.

Bu dosya Faz 1'de hazırlanmış, Faz 2'nin Flutter iskeleti ve testleriyle güncellenmiştir. Flutter projesi, `test/app_test.dart`, `integration_test/app_smoke_test.dart` ve `integration_test` SDK geliştirme bağımlılığı mevcuttur. Supabase migration/seed, gerçek Auth/RBAC/RLS ve iş modülleri henüz yoktur; bunlara ait aşağıdaki senaryolar **gelecekteki fazlar için plandır**. Komutun bu dosyada yer alması çalıştırıldığı veya başarılı olduğu anlamına gelmez. Gerçek komut sonuçları ve kabul durumu [PROGRESS.md](PROGRESS.md), SDK/paket seçimleri [DECISIONS.md](DECISIONS.md) T-01–T-06 içindedir.

## 3 Ekim 2026 doğrulama durumu

Önceki çalışmanın `build/phase2-validation/` altındaki logları ve çıkış kodları okundu. Başarılı analyze, 42 test ve normal debug build yeniden çalıştırılmadı; uygulama/test kodu ve paketler değiştirilmedi. Yeniden bağlanan emulator-5554 üzerinde mevcut integration testi çalıştırıldı; ardından korunan normal APK yeniden derlenmeden ADB ile açılıp örnek ekranlar incelendi.

| Komut | Sonuç | Çıkış kodu / kanıt |
| --- | --- | --- |
| `flutter pub get` | Başarılı | 0; `pub-get.log` |
| `flutter analyze` | No issues found | 0; `analyze.log` |
| `flutter test` | 42 geçti, 0 başarısız; All tests passed | 0; `widget-test.log` |
| `flutter build apk --debug` | Başarılı; Built app-debug.apk, 238,4 s | 0; `build-debug.log` bitişi doğrulandı |
| `flutter devices` | Son görevde emulator-5554, Android 17 / API 37 bağlı | 0; gerçek komut çıktısı |
| SDK `adb.exe devices -l` | emulator-5554 `device` durumunda | 0; `adb-devices-connected.log` |
| `flutter test integration_test/app_smoke_test.dart -d emulator-5554` | 1 geçti, 0 başarısız; All tests passed | 0; `integration-test.log` |
| SDK ADB `install -r` / `am start -W` | Normal APK kuruldu, soğuk açılış `Status: ok` | İkisi de 0; `apk-launch.log` |
| Görsel ekran incelemesi | Aşağıdaki örnek ekranlar incelendi | `visual-*.png`; `flutter run` ayrıca çalıştırılmadı |

Normal uygulama APK'sı: `build/app/outputs/flutter-apk/peksen-gida-debug.apk`, **188.813.782 bayt** (yaklaşık 180,07 MiB). Başarılı normal build'in çıktısı integration öncesinde aynı byte'larla bu ad altında korundu; standart `app-debug.apk` artık integration çalıştırıcısına aittir (162.112.543 bayt). Build kabulü dosya varlığına değil, bitiş çıktısı ve çıkış 0'a dayanır. JDK native-access uyarısı komutları durdurmamıştır. Loglar/build çıktıları ignore edilir; kalıcı sonuç özeti PROGRESS'tedir. **Faz 2 tamamlandı.** Bu sınırlı iskelet kabulü, tüm cihazlarda görsel veya gerçek backend kabulü değildir.

## Faz 1'de doğrulanan araç envanteri — tarihi kayıt

2 Ekim 2026'da araç tanılaması yapıldı; uygulama build veya test çalıştırılmadı. Kurulu Flutter sürümü aşağıda gözlendi, ancak projenin kullanacağı sürüm henüz sabitlenmedi.

| Kontrol | Gözlenen sonuç |
| --- | --- |
| Git | `2.55.0.windows.5` |
| Flutter / Dart | Flutter stable `3.47.6`; Dart `3.13.5` |
| `flutter doctor -v` | Çıkış kodu 0; “No issues found”. Android SDK `37.0.0`, lisanslar kabul edilmiş. |
| Android SDK | `C:\Users\Mustafa\AppData\Local\Android\sdk` |
| Java | Flutter doctor'ın kullandığı Android Studio JDK `25.0.3`; PATH üzerindeki Java Temurin `25.0.4.1`. |
| adb | PATH üzerinde bulunmadı; SDK içindeki `platform-tools\adb.exe` mevcut (`1.0.41`, paket `37.0.1`). |
| Android hedef | SDK içindeki adb ile `devices -l` çıktısında cihaz/emülatör yok. Flutter yalnızca Windows/Chrome/Edge hedeflerini görüyor. |
| Supabase CLI / Docker | PATH üzerinden bulunamadı. Bu sonuç sistemin her yerinde kurulu olmadıklarını kanıtlamaz. |
| SDK/JDK ortam değişkenleri | `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `JAVA_HOME` tanımsız; buna rağmen doctor Android araç zincirini doğruladı. |

Bu tablo Faz 1 görevinin anlık ortamını korur; güncel cihaz durumunu belirtmez. Faz 12/14/17 için gerçek cihaz gerekir. Faz 3 öncesi Supabase CLI ve seçilecek yerel çalışma ortamı ayrıca hazırlanıp doğrulanır.

## Faz 2 araç ve proje tabanı

2 Ekim 2026'da seçilen taban: Flutter stable `3.47.6`, Dart `3.13.5`, Android SDK `37.0.0`, Android Studio JBR `25.0.3`; doğrudan uygulama bağımlılıkları `flutter_riverpod: 3.4.3`, `go_router: 18.0.2` ve SDK'dan `flutter_localizations`. `integration_test` SDK geliştirme bağımlılığı da eklenmiştir. `pubspec.lock` korunur. Uygulama adı `Pekşen Gıda`, geçici kimlik `com.example.peksen_gida`dır.

Önceki devam kontrolünde hedef yoktu; son görevde `emulator-5554` (Android 17 / API 37) yeniden bağlı doğrulandı. Çalıştırmadan önce `flutter devices` ile hedef tekrar seçilir. Açılış kabulü yalnız cihaz listesine dayanmaz; integration testi, normal APK kurulum/açılış sonucu ve giriş görüntüsü kaydedildi. Fiziksel cihaz kabulü yapılmadı. Supabase CLI/Docker bu fazda kurulmaz veya kullanılmaz; Faz 1'deki PATH sonucu Faz 3'ten önce yeniden değerlendirilir.

## Kalite kapısı

Kaynak §34 gereği değişikliğe uygun kontrol çalıştırılır:

| Değişiklik veya kabul | Gerekli kontrol |
| --- | --- |
| Flutter kodu | `flutter analyze` ve ilgili unit/widget testleri. |
| SQL, RLS veya kritik backend işlemi | Veritabanı, yetki ve transaction testleri. |
| Tamamlanan kullanıcı akışı | Integration testi. |
| Mobil bağımlılık, platform ayarı veya tamamlanan faz | Android debug build. Faz 1'de uygulama bulunmadığından build uygulanabilir değildir. |
| Fiyat, stok, sipariş veya ödeme | İlgili regresyon ve eşzamanlılık/tekrar deneme senaryoları. |
| GPS, bildirim veya release kabulü | Gerçek Android cihazda kontrol; yalnızca emülatör veya mock yeterli değildir. |
| Her değişiklik | Ölü/tekrarlanan kod, TODO/FIXME, sırlar ve kapsam kontrolü; her TODO bir takip maddesine bağlı olmalı. |
| Hata düzeltmesi | Hatanın ilgili testi yeniden çalıştırılır. |

Rapor; tamamlanan kabul ölçütleri, değişen dosyalar, çalıştırılan komutlar ve sonuçları, çalıştırılamayan kontroller ve nedenleri, kalan riskler ve sonraki adımı içerir. **Çalıştırılmayan test başarılı sayılmaz.** Ortam engeli gerekli kontrolü önlüyorsa ilgili faz **doğrulama bekliyor** olarak kaydedilir. Sentetik ekran, gerçek backend entegrasyonu veya RLS doğrulaması sayılmaz.

## Yerel kurulum ve komutların uygulanma zamanı

1. Çalışma klasörünü, Git durumunu, AGENTS ve proje belgelerini okuyun; ilgisiz değişiklikleri koruyun.
2. Faz 2 öncesi Flutter/Dart, Android SDK/JDK, Android lisansları ve emülatör/cihaz durumunu inceleyin. Sürümleri seçip karar kaydına yazın. Araç mevcutsa bile proje yapılandırmasının doğrulandığı varsayılmaz.
3. Mevcut depo kökünde `flutter pub get` uygulayın. Faz 2 iskeleti geçici klasörde üretilip seçilerek birleştirilmiştir; yeniden oluşturma gerekiyorsa README, `.gitignore` ve belgeleri koruyun, `--overwrite` kullanmayın. Riverpod/go_router sürümleri ve lockfile mevcut proje kararlarıdır.
4. `.env.example` içindeki adları temel alın; gerçek yerel değerleri Git'e alınmayan yapılandırmada tutun. Ortam değişkenlerini Flutter'a taşıma yöntemi entegrasyon görevinde seçilir; Faz 2 uygulaması `.env` yüklemez. Mobil istemci yalnızca Supabase anon/publishable key kullanır. `service_role`, gerçek parolalar ve imzalama anahtarları depoya/sohbete yazılmaz.
5. Faz 3 öncesi Supabase CLI sürümü, yerel çalışma gereksinimleri ve yalıtılmış test veritabanı seçilir. Yerel servis yöntemi konteyner gerektiriyorsa ilgili çalışma ortamı ayrıca doğrulanır. Yalnızca sentetik test verisi kullanılır; bulut hesabı veya cihaz erişimi kendiliğinden var sayılmaz.
6. Migration/seed ve veritabanı test yapısı Faz 3–4'te oluşturulur. Komutlar seçilmiş CLI sürümü ve proje yapılandırmasıyla doğrulanır. Canlı veritabanı migrationı, kalıcı veri silme ve yayınlama ayrıca yetkilendirilir.

### Okuma ve ortam tanılama komutları

Aşağıdakiler ileriki görevlerde yeniden kullanılacak komutlardır. Bu tur gerçekten çalıştırılanların sonuçları PROGRESS'tedir.

```powershell
Get-Location
git status --short --branch
git ls-files
git diff --check
Get-Command git,flutter,dart,java,adb,supabase -ErrorAction SilentlyContinue
```

İlgili araç bulunduğunda Faz 2–3 tanılaması:

```powershell
flutter --version
dart --version
flutter doctor -v
flutter devices
java -version
adb devices -l
supabase --version
```

Bu makinede `adb` PATH'te olmadığından mevcut SDK ile karşılığı aşağıdadır; SDK konumu değişirse yeniden keşfedilir:

```powershell
& 'C:\Users\Mustafa\AppData\Local\Android\sdk\platform-tools\adb.exe' devices -l
```

### Flutter kabul komutları — Faz 2 ve sonrası

Mevcut Flutter projesinde depo kökünden çalıştırılır:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter devices
# Yalnız bağlı Android hedef için; CIHAZ_ID gerçek kimlikle değiştirilir:
flutter test integration_test/app_smoke_test.dart -d CIHAZ_ID
flutter run -d CIHAZ_ID
```

`emulator-5554` son doğrulanan Android hedefidir. `flutter test` unit/widget testlerini kapsar; SDK integration testi cihaz üzerinde ayrı çalıştırılır. Son görevde başarıyla biten komut:

```powershell
flutter test integration_test/app_smoke_test.dart -d emulator-5554
```

Hedefin kimliği farklıysa `flutter devices` çıktısı kullanılır. Geçen analyze, 42 unit/widget testi ve build kod/bağımlılık değişmedikçe tekrarlanmaz. Yeni test/build hatası düzeltilirse ilgili kontrol yeniden çalıştırılır. Bitiş çıktısı ve gerçek süreç çıkış kodu ayrı kaydedilir; yarım kalan komut veya APK'nın varlığı başarı değildir. Debug build çıktısı `build/app/outputs/flutter-apk/app-debug.apk` konumundadır; release build bu fazda çalıştırılmaz.

### Faz 2 mevcut unit/widget senaryoları

Dosya: `test/app_test.dart`. Aşağıdaki testler gerçek kimlik doğrulama veya iş işlemlerini değil, iskeletin görünüm ve yönlendirme sözleşmesini doğrular:

| Senaryo | Beklenen davranış |
| --- | --- |
| Kaynak rol/ekran envanteri | SPEC §23'ten bağımsız test beklentisiyle yedi rol ve 70 ekran karşılaştırılır; her rolde ekran kimlikleri benzersizdir; `order_operator` yeni rol değildir. |
| Giriş önizlemesi | E-posta/parola alanlarına sentetik değer girilse de “Giriş yap” devre dışı kalır; oturum başlatılmaz. |
| Önizleme kapalıyken erişim | Önizleme düğmesi yoktur; `/preview`, durum ve Owner dahil alt yollar doğrudan açılsa da girişe yönlenir. Başlangıç alt yolu da kontrol edilir. |
| Giriş alias'ı | `/login` tek giriş yolu `/` üzerine yönlenir. |
| Yedi rol menüsü | Yedi rolün 70 bağlantısının tamamına kaydırılarak erişilir; her ekran kabuğu açılır, başlığı/rota adresi doğrulanır ve menüye dönülür. |
| Riverpod arayüz durumu | Rol seçiminden geri dönülünce önizleme son seçilen rolü hatırlar. Bu kalıcı rol veya yetki testi değildir. |
| Doğrudan alt yol ve geri | Ekran bağlantısından rol menüsü → önizleme → giriş sırasıyla hem arayüz düğmesi hem Android sistem geri olayıyla dönülür. |
| Ortak durumlar | Yükleniyor, boş ve hata görünümü açılır; önizlemeye dönüş çalışır. Sürekli yükleniyor animasyonu gerçek isteğin bitmesi gibi beklenmez. |
| Hata görünümü eylemi | Örnek eylem boş liste görünümüne gider; gerçek sunucu yeniden denemesi değildir. |
| Geçersiz adresler | Bilinmeyen yol, rol, ekran ve durum “Sayfa bulunamadı” gösterir; eylem veya Android sistem geri ile girişe dönülür. Başlangıç ve açık uygulamada query içeren bilinmeyen bağlantı, önizleme açık/kapalı senaryoları korunur; boş rota listesinden doğan StateError regresyonu denetlenir. |
| Küçük ekran ve klavye | `320×568` mantıksal piksel ve `2×` yazıda yedi rolün tüm 70 hedefi, ortak durumlar ve bulunamadı ekranı sınanır. Ayrıca `220` piksel klavye inset'i altında iki giriş alanına erişme/metin girme ve framework taşma hatası oluşmaması kontrol edilir. |

Önizleme kapalı testleri debug test sürecinde erişim ayarını kapatır; profile/release APK çalıştırma testi sayılmaz. `kDebugMode` router koşulu ayrıca kod incelemesiyle kontrol edilir. Test koşulları dışında kalan ekran boyutları veya cihazlarda görsel kontrol yapılmış sayılmaz.

### Faz 2 mevcut Android integration senaryosu

`integration_test/app_smoke_test.dart`: uygulamayı başlatır, giriş düğmesinin devre dışı olduğunu denetler; giriş → geliştirme önizlemesi → Depo → ürün ekran kabuğu → menü/önizleme geri dönüşü → boş liste → giriş akışını çalıştırır. Son görevde Android üzerinde **1 test geçti, çıkış 0**. Widget testlerindeki 42 başarıya dahil değildir; gerçek backend işlemi veya tek başına görsel kabul kanıtı değildir.

### Faz 2 Android açılış ve görsel kontrol kapsamı

Bağlı emülatörde `flutter run -d emulator-5554` veya önceden doğrulanmış APK'nın SDK ADB ile kurulup açılması kullanılabilir. Son görevde ikinci yöntem seçildi; normal build tekrarlanmadı. `adb -s emulator-5554 install -r build/app/outputs/flutter-apk/peksen-gida-debug.apk` ve `adb -s emulator-5554 shell am start -W -n com.example.peksen_gida/.MainActivity` çıkış 0 ile bitti. Bu makinede PATH yerine yukarıda belirtilen SDK `adb.exe` yolu kullanıldı. Ekran görüntüleri `adb exec-out screencap -p` ile alınıp incelendi. Emülatör: 1080×2400, 420 dpi, Android yazı ölçeği 1,0. Faz 2 emülatör kontrolü GPS/FCM/release gerçek cihaz kabulünün yerine geçmez.

3 Ekim 2026 son görsel kontrolü:

- [x] Normal APK açılışı, Türkçe giriş, devre dışı giriş düğmesi ve gerçek oturumun bağlı olmadığı açıklaması (`visual-login.png`).
- [x] Mevcut emülatör boyutunda Android klavyesi açıkken e-posta/parola alanlarının görünür ve odaklanabilir olması (`visual-keyboard-email.png`, `visual-keyboard-password.png`).
- [x] Yedi rolün seçim listesi, Depo menüsünün görünen bölümü ve Ürünler örnek ekranı; normal üst geri/Android sistem geri ile dönüşler (`visual-preview*.png`, `visual-warehouse.png`, `visual-product-placeholder.png`, `visual-back-*.png`).
- [x] Yükleniyor, boş liste ve hata görünümleri; hata → boş liste ve önizleme/girişe dönüş örnekleri (`visual-loading.png`, `visual-empty.png`, `visual-error.png`, `visual-state-return.png`, `visual-final-login.png`).
- [ ] Diğer altı rolün ayrı menü/ekranlarının ve Depo'nun tüm satırlarının tek tek görsel incelemesi. Tüm 70 bağlantının davranışı widget testlerinde geçti.
- [ ] Farklı ekran boyutları ve Android büyük yazı ayarıyla görsel inceleme. 320×568/2× yazı kabulü widget testine dayanır.
- [ ] Fiziksel cihaz ve release/profile görsel kontrolü; ilgili sonraki fazlarda ele alınır.

Görüntüler `build/phase2-validation/` altındadır; ayrıntılı gözlem listesi PROGRESS'tedir. Önceki `emulator-screen.png` yalnız Android ana ekranıdır; yeni `visual-*.png` kanıtlarıyla karıştırılmaz. Bilinmeyen rota regresyonu widget testinde geçti; bu tur cihazda görsel olarak denenmedi. Yukarıdaki yapılmayan ek görsel kontroller, tamamlanan iskelet/test/build/Android açılış kabulünün kapsam sınırlarını gösterir; yapılmış sayılmaz.

### Supabase kabul komutları — Faz 3 ve sonrası

CLI sürümü, yerel servisler, proje yapılandırması ve test altyapısı seçildikten sonra kesinleştirilecek komut taslağı:

```powershell
supabase start
supabase status
supabase db reset --local
supabase test db
```

`supabase db reset --local`, **yalnızca bu proje için ayrılmış, yeniden oluşturulabilir sentetik yerel test veritabanında** boş veritabanından migration+seed kurulumunu doğrulamak içindir. Veri içeren mevcut veya canlı ortama uygulanmaz; önce hedef ve veri niteliği doğrulanır. Bu tur çalıştırılmaz. `supabase test db`, uygun SQL test altyapısı/test dosyaları eklendikten ve seçilen CLI ile doğrulandıktan sonra kullanılır; şu an mevcut çalışan test paketi olduğu iddia edilmez. RLS testleri ayrı kullanıcı kimlikleriyle yapılır; yalnızca ayrıcalıklı bağlantıyla çalıştırılmış SQL, müşteri veya çalışan erişiminin güvenli olduğunu kanıtlamaz.

### Faz 1 belge doğrulaması — tarihi kontrol listesi

- Dokuz istenen dosyanın varlığı, yerel bağlantıları ve okunabilirliği kontrol edilir.
- Kaynak DOCX'in değişmediği doğrulanır.
- SPEC'in kaynak iş kuralları, roller, ekranlar, veri modeli ve kapsam dışı maddeleri taşıdığı kontrol edilir.
- PLAN'daki 17 faz/kabul ölçütü kaynak §33 ile karşılaştırılır.
- DECISIONS'daki açık iş kararlarının varsayım/formül olarak uygulanmadığı kontrol edilir.
- Komutların planlanan/çalıştırılan ayrımı, Faz 1 durumu ve Faz 2 sınırı kontrol edilir.
- `git diff --check` çalıştırılır; yeni ve henüz izlenmeyen dosyalar bu komutun kapsamına otomatik girmez, ayrıca incelenir.
- Gerçek sır, uygulama dosyası veya istenmeyen kaynak değişikliği olmadığı kontrol edilir. Commit, push ve yayınlama yapılmaz.

## Karar bağımlı test beklentileri

Kaynak §37'nin aşağıdaki kararları [DECISIONS.md](DECISIONS.md) içinde kesinleşmeden sayısal sonuç veya durum geçişi icat edilmez:

| Konu | Test verisi/beklenen sonuç için gerekli karar |
| --- | --- |
| İskonto | Son üç ayın takvim aralığı, alışverişsiz haftalar, teslim/ödeme uygunluğu, iadeler; 50K/70K/100K toplam mı ortalama mı? Bunlar yalnızca test eşikleridir. |
| Cari | Referans limit formülü, borcun oluşum anı, doğrulanmamış tahsilat, kısmi ödeme ve fazla tahsilat. Uyarı ve kullanıcının devam edebilmesi sabittir. |
| Stok | Rezervasyonun başladığı durum, picked miktarının reserved içindeki yeri, fiziksel düşüm, iptal/iade telafisi. Kaynaktaki `available_qty = physical_qty - reserved_qty` tutarlılığı ve tek rezervasyonun iki kez tüketilmemesi korunur. |
| Sipariş | Ana status, ödeme statusu ve exception/talep eşlemesi; failed/returned geçişleri; Order Operator rolünün yedi rolle eşlemesi. |
| Veri modeli | Eksik tablolar/FK'ler, çalışan daveti, cihaz tokenları, tek depodaki warehouse_id; snapshot alan adları ve metin/tablo farkları. |
| GPS | Güncel/geçmiş ayrımı, saklama/silme süresi, eski konum uyarısı, erişim bitişi ve harita sağlayıcısı. |
| Para ve güvenilir işlem | TL ve birim dönüşüm hassasiyeti, yuvarlama noktası, idempotency ve transaction kilitleme. |

Kesinleşmiş davranışlar için test tasarlanabilir; açık karara bağlı doğrulama, karar kimliği ve bekleme nedeni ile kaydedilir. Açık kararı mock formülle örtmek kabul değildir.

## Yedi rol senaryosu — uygulanacak

Ortak önkoşul: Faz 3'te sentetik yedi rol hesabı, birbirinden bağımsız en az iki müşteri kuruluşu, örnek ürün/stok/sipariş ve gerektiğinde farklı driver/sefer kayıtları hazırlanır. Test hesabının rolü veritabanından gelir; istemcideki rol etiketi yetki kanıtı değildir.

| Rol | Pozitif akış | Olumsuz/yetki kontrolü |
| --- | --- | --- |
| `customer` | E-posta/şifre ile kayıt sonrası doğrudan aktif olma; kendi katalog/fiyatı, integer miktar ve ürün minimumu, sepet/sipariş, cari uyarıda devam onayı; kendi aktif araç takibi; teslim onayı/uyuşmazlık; teslimden sonra 1–5 yıldız, reason code ve isteğe bağlı yorum. | Başka müşterinin fiyat/sipariş/GPS kaydı okunamaz. Client fiyatı backend fiyatının yerine geçmez. Teslim edilmemiş sipariş ve aynı sipariş için ikinci puan reddedilir. Rol veya maaş verisine yetkisiz erişim reddedilir. |
| `sales_operator` | Gerekli müşteri profilini seçme; müşteriyle aynı özel fiyat; ortak OrderService üzerinden `source=sales_operator` ve doğru `created_by`; eksik/alternatif ürün koordinasyonu; cash/POS tahsilatta gerçek `collector_user_id`. | Gereksiz müşteri verisine erişim sınırı; istemci fiyatını kabul ettirememe; yetkisiz fiyat değişimi veya rol/maaş erişiminin reddi. Operasyon için gerekli veri sınırı karar kaydından alınır. |
| `warehouse` | Ürün oluşturma, fiyat değişim geçmişi/audit; hazırlama kuyruğu ve bekleniyor/toplandı/eksik; mal kabulü; stok hareketleri; sayım oturumu/fark/not. | Manager/Owner onayı olmadan sayım düzeltmesi uygulanamaz. Stok hareketi geçmişi değiştirilemez. Rol, maaş ve ilgisiz işlemlerde yetki aşılamaz. |
| `accounting` | Tahsilat ve gerçek collector kaydını inceleme/doğrulama; müşteri cari kaydı ve cari uyarı/onayı; fiyat yönetimi, finansal kayıtlar ve raporlar. | Tekrar doğrulama/tekrar isteğin çift finansal kayıt üretmemesi; Owner-only maaş/prim erişiminin ve yetkisiz rol değişiminin reddi. Açık ödeme kuralları sonuçları karardan alınır. |
| `driver` | Kendine bağlı primary/assistant sefer ve duraklar, yükleme, sıra değişikliği, yola çıkış, GPS, ulaşma/teslim onayı ve opsiyonel uyuşmazlık kanıtı. | Başka driver'ın bağlı olmadığı sefer/durak/sipariş/GPS kayıtlarına erişim reddi. Müşteri onayı yokken tek başına normal teslim kesinleştirememe; Manager exception gerekir. Driver normal tahsilatçı sayılmaz. |
| `manager` | Operasyon görünümü, fiyat/stok/dağıtım, çalışan hesabı, sayım onayı, realtime durak sırası, GPS sorunu, uyuşmazlık çözümü, kampanya, puan aggregate ve kayıtlarla tutarlı raporlar. | Maaş/prim verisine erişim reddi; karara bağlanmamış durum geçişini doğrudan UPDATE ile atlatamama. Manager'ın çalışan oluşturma yetkisi Owner-only veriye erişim sağlamaz. |
| `owner` | Manager ekranları ile finans, ayarlar, audit ve maaş/prim; değişikliklerin audit kaydı. | Diğer altı rolün Owner-only verilere erişemediği karşı test; Owner işlemlerinin de kayıt/audit ve transaction tutarlılığını koruması. |

Kaynak §7 saha akışı ayrıca uçtan uca çalıştırılır: Sales Operator müşteri adına sipariş → Warehouse toplama/eksik bildirim → müşteriyle alternatif kararı → araç/sefer/yükleme → Driver yola çıkış/GPS → çift teslim onayı → puan → gerçek collector ile tahsilat → Accounting doğrulaması. Müşteri uygulamasından siparişle aynı backend iş kurallarını kullandığı karşılaştırılır.

## Fiyat, stok, sipariş ve ödeme regresyonları — uygulanacak

- **Fiyat:** İstemcinin değiştirilmiş fiyat/iskonto değeri backend hesabını geçersiz kılamaz. Katalog/sepet açıkken fiyat değişmesi açıklayıcı sonuç verir. Sipariş fiyat snapshotları sonraki fiyat değişiminden etkilenmez. Yetkili dört rolün fiyat değişiminde eski/yeni fiyat, kullanıcı, zaman ve gerekçe kaydı doğrulanır. Müşteri ve Sales Operator aynı müşteri fiyatını görür. Birim dönüşümü, integer miktar, ürün minimumu ve stok yok görünümü kontrol edilir.
- **İskonto/cari sınırları:** Kararlar alındıktan sonra dönem sınırı, boş hafta, eşik sınırı ve iade örnekleri eklenir. Cari aşım uyarısı ve “Devam etmek istiyorum” onayı/audit kontrol edilir; otomatik bloklama eklenmez. Kısmi/fazla/doğrulanmamış tahsilat beklenen sonuçları karar metninden alınır.
- **Stok yarışı:** Aynı ürüne eşzamanlı müşteri/saha siparişleri ve tekrar istekler yürütülür; stok tutarsızlığı veya aynı rezervasyonun iki kez tüketilmesi oluşmamalı. Rezervasyon, pick, yükleme, iptal/iade, mal kabulü ve onaylı sayım hareketleri kararlaştırılan aşamalarda test edilir. `inventory_movements` değiştirilemez geçmişi ve `available_qty` tutarlılığı doğrulanır; transaction hata alırsa yarım işlem kalmamalı.
- **Sipariş yarışı:** Aynı sipariş için eşzamanlı/tekrar durum isteği, değişiklik/iptal talebi ve alternatif yanıtı test edilir. İzinli geçişler history/audit üretir; yetkisiz doğrudan status UPDATE reddedilir. Hazırlanmış/loaded/out_for_delivery siparişin doğrudan değiştirilmesi engellenir. Alternatif reddi yalnızca ilgili item'ı kaldırır; kabul yeni item ve history üretir; miktar değiştirme seçeneği test edilir.
- **Tahsilat yarışı:** Aynı tahsilat isteğinin yeniden gönderilmesi ve eşzamanlı doğrulama çift ödeme/finansal kayıt üretmez. Cash/POS, sipariş/tutar/yöntem/gerçek collector/tahsil zamanı/doğrulayan/durum/not ve audit kontrol edilir. Başarısız transaction kısmi doğrulama bırakmaz; idempotency anahtarı ve kilitleme yöntemi teknik karardan gelir.
- **Teslim/puan yarışı:** İki onayın sırası ve tekrarları, uyuşmazlık, Manager çözümü ve uygulamayı açmayan müşteri exception akışı test edilir. Teslim edilmeyene puan verilmez; eşzamanlı puan isteklerinde sipariş başına bir puan korunur. failed/returned beklentileri durum kararından alınır.
- **Audit:** Fiyat/iskonto, sipariş durum/değişiklik/iptal, stok düzeltme/sayım onayı, ödeme doğrulama, cari aşım/onay, rol/permission, maaş/prim, kampanya ve uyuşmazlık çözümü için kayıt doğrulanır.

## RLS ve dosya erişimi olumsuz testleri — uygulanacak

UI menüsünün gizlenmesi yeterli değildir; tablo/API/RPC/Realtime/Storage yollarında yetki kontrol edilir. RLS olmayan hassas tablo production-ready sayılmaz.

- Customer A kimliği ile Customer B fiyat/sipariş/konum kaydını kimlik değiştirerek okuma veya değiştirme girişimi reddedilir; kendi customer_id sınırı korunur.
- Sales Operator için operasyon gereği dışındaki müşteri/sipariş erişimi reddedilir; ayrıntı matrisi uygulamadan önce karara bağlanır.
- Driver A, atanmadığı başka run/stop/order/GPS verisine erişemez; primary ve assistant ataması ayrı doğrulanır.
- Customer yalnızca kendi aktif teslimatının son konumuna erişir; başka müşteri, biten sefer ve geçmiş konum erişimi kapalıdır. Erişim bitiş zamanı GPS kararına göre test edilir.
- Owner dışındaki altı rolün maaş/prim tablosu ve ilgili API/rapor üzerinden okuma/yazma girişimleri reddedilir.
- Müşteri veya yetkisiz çalışan `profiles.role`, permission ve doğrudan sipariş status değişikliğiyle yetki yükseltemez. RPC yetkilendirmesi de sınanır.
- Yetkisiz fiyat yönetimi ve client fiyat manipülasyonu reddedilir; fiyat backend'de yeniden hesaplanır.
- Teslimat kanıt dosyası yalnızca yetkili operasyon taraflarınca erişilebilir; başka müşteri/driver ve oturumsuz istek erişemez. URL ve nesne yolu değiştirme girişimleri denenir. Kanıt yükleme normal teslimatta zorunlu değildir.
- Mobil kaynak, yapılandırma ve APK içinde `service_role`, gerçek parola veya imzalama sırrı bulunmaz. Sır taraması sonucu gizli değeri rapora/sohbete dökmez.

## Gerçek Android cihaz kontrol listesi — Faz 12, 14 ve 17

Aşağıdaki maddeler henüz çalıştırılmamıştır. Her kayıtta cihaz/model, Android sürümü, uygulama sürümü, izin durumu, ağ koşulu, tarih ve gözlenen sonuç tutulur.

- [ ] Debug/release kurulum ve uygulama açılışı; müşteri/çalışan oturumu ve örnek sipariş akışı.
- [ ] Kritik işlem sırasında internet yokken işlemin yapılmaması ve anlaşılır hata; bağlantı geri geldiğinde tekrar denemenin çift kayıt üretmemesi.
- [ ] Konum yalnızca `out_for_delivery` sırasında aktif; ekran kapalıyken/background takip sürüyor.
- [ ] Başlangıç 10–15 saniye hedefi gözleniyor; bağlantı/pil koşullarına bağlı adaptif davranış kayıtlı. Hedef ölçüm, kesin servis garantisi diye sunulmuyor.
- [ ] İlk konum izni reddi ve sonradan izin kapatma; Driver'a tekrar izin akışı, Manager'a GPS uyarısı.
- [ ] Bağlantı kesilmesi/yeniden gelmesi; son güncelleme zamanı ve kararlaştırılan eski konum uyarısı.
- [ ] Harita yalnızca araç marker'ı ve son güncelleme zamanını gösteriyor; müşteri kendi aktif aracını görebiliyor. Rota optimizasyonu/geocoding eklenmiyor.
- [ ] Teslimat/sefer bitince paylaşım duruyor; müşteri erişimi ve saklama/silme davranışı GPS kararına uyuyor.
- [ ] FCM hedef kullanıcı/rol ve kampanya hedef müşteri grubu doğru; normal fiyat değişimi herkese bildirim göndermiyor.
- [ ] Bildirim geçmişi ve deep link, uygulama açık/arka planda/kapalıyken doğru yetkili ekrana gidiyor.
- [ ] Kaynak §22'deki tüm olaylar kapsanıyor: yeni sipariş, onay, alternatif, hazırlanıyor, teslimata hazır, yola çıktı, GPS sorunu, uyuşmazlık, teslim edildi, büyük indirim, cari limit aşımı.
- [ ] Bildirim kaybı sipariş işlemini geri almıyor; yinelenen gönderim kontrolü çalışıyor.
- [ ] Çift teslim onayı, Manager exception/uyuşmazlık çözümü ve tek puan kontrolü gerçek akışta çalışıyor.

## Release kapısı — yalnızca Faz 17

Faz 16 güvenlik/uçtan uca kabulü tamamlanmadan release kabulü verilmez. İmzalama yapılandırması ve anahtar saklama yöntemi ayrıca hazırlanır; gerçek anahtar depoya veya sohbet metnine yazılmaz. Yapılandırma tamamlandığında planlanan üretim komutu:

```powershell
flutter build apk --release
```

Bu komut şu anda uygulanabilir değildir ve çalıştırılmamıştır. Release build almak tek başına yayınlama değildir; yayınlama ayrıca yetkilendirilir. Kabul için imzalı APK üretimi, gerçek cihazda kurulum/oturum/sipariş/bildirim/GPS, sürüm bilgisi, kurulum adımları ve yedekleme adımları belgelenir. Açık engelleyici hata kalmamalıdır.
