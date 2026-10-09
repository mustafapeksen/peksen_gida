# Pekşen Gıda doğrulama ve test planı

## Faz 7 doğrulaması — 9 Ekim 2026

| Komut | Sonuç | Çıkış |
| --- | --- | ---: |
| `flutter pub get` | Başarılı; paket/lock değişmedi | 0 |
| `flutter analyze` | No issues found | 0 |
| `flutter test --reporter expanded` | 142/142; 130 mevcut + 12 yeni | 0 |
| `flutter test test/sales_checkout_test.dart --plain-name "Direct customer switch" --reporter expanded` | Son eklenen regresyon 1/1; toplam 143 farklı Flutter testi | 0 |
| `flutter build apk --debug` | Built app-debug.apk; 18,5 saniye | 0 |
| `npx.cmd --yes supabase@2.119.0 db reset --local` | 9 migration + iki seed | 0 |
| Aynı CLI `test db --local supabase/tests/database/sales_checkout_test.sql` | 50/50 PASS | 0 |
| Aynı komutla `customer_checkout_test.sql` | 94/94 PASS | 0 |
| Aynı komutla `product_pricing_test.sql` | 73/73 PASS | 0 |
| Aynı komutla `auth_access_test.sql` | 119/119 PASS | 0 |
| Aynı komutla `account_scope_test.sql` | 85/85 PASS | 0 |
| `flutter test integration_test/customer_checkout_smoke_test.dart integration_test/sales_checkout_smoke_test.dart -d emulator-5554` | Customer + Sales 2/2 PASS | 0 |

**Son kabul:** F7-01 kapsamındaki Faz 7 tamamlandı. Native smoke, gerçek Android emülatöründe fixture repository ile Customer ve Sales akışlarını çalıştırdı; DB yetkileri ayrı pgTAP kanıtıdır. Normal APK integration öncesi `build/app/outputs/flutter-apk/peksen-gida-phase7-debug.apk` olarak korundu: **238.063.733 bayt**. Build/integration logları Built/All tests passed, EXIT_CODE: 0 ve END içerir. Public config verilmeden derlendi; .env değiştirilmedi.

**DB kapsamı:** 421 assertion; yeni Sales paketi aktif atama, creator-only ret, pasif müşteri/aktör, RLS müşteri/sipariş/fiyat gizleme, atama kaldırma/reassignment, replay yetkisi, taslak aktör ayrımı, raw yazma reddi, Customer ile aynı quote, eski fiyatta sıfır yazma, açık yeniden onay, snapshot, tek rezervasyon/history/audit ve sunucunun source/created_by üretimini doğrular. Yeni yetki F7-01'e göre eski auth paketindeki iki creator beklentisi daraltıldı. Normalizer/snapshot trigger'ın invoker ve kapalı EXECUTE sınırlarına iki assertion eklendi (117 → 119). Faz 3 identity/business, lifecycle/client Auth paketleri etkilenmediğinden bu tur tekrarlanmadı; geçmiş başarıları bu koşunun sonucu değildir.

**Flutter kapsamı:** 130 eski + 13 yeni = 143 farklı test. Tam koşudaki 142 testten sonra yalnız yeni doğrudan müşteri/sepet URL değişimi testi eklendi ve 1/1 geçti; uygulama kodu değişmediğinden başarılı build/tam test tekrar edilmedi. Son analyze 0. Sales liste/yükleniyor/hata/boş, altı diğer rol ret, tahmin edilen müşteri rotası, atamayı yenilemede verinin kalkması, müşteri değişiminde sepet ve taslak ayrımı, ortak fiyat onayı/gönderim, geri gezinme ve 320×568/klavye koşulunda gerçekten sepete ekleme. Mevcut 130 test (Customer, SDK retry, auth, preview, ürün/fiyat) korunur. Yeni integration smoke aynı Customer bileşenlerini gerçek Android widget/gezinti ortamında fixture repository ile çalıştırır; gerçek backend uçtan uca testi değildir.

**Kanıt ve düzeltmeler:** `build/phase7-validation-20261009/*.log` komut/bitiş/çıkış kodlarını taşır. İlk auth SQL koşusu eski geniş definer varsayımını yakaladı; ilk hata logu korundu. İlk küçük ekran testi lazy TextField bulamadı; kaydırma ve gerçek hit-test/sonuç assertionları ile düzeltildi. Başarısız ara koşular son kabul sayılmadı. Secret/.env okunmadı veya loglanmadı; yalnız sentetik yerel DB kullanıldı.

**Yapılmayanlar:** Manuel Android görsel inceleme, gerçek backend ile Sales saha akışının cihazda uçtan uca kontrolü, process-kill/kalıcı oturumun yeniden kabulü, gerçek cihaz/üretim ve çok bağlantılı stok stres testi. Cari/exposure, çeyrek/iskonto eşikleri ve yönetici onayından sonra stok/geçiş mantığı uygulanmadı/test edilmedi; F7-01 ve R-01–R-03 açık sınırlarıdır.

## Faz 6 doğrulaması — 9 Ekim 2026

| Komut | Sonuç | Çıkış |
| --- | --- | ---: |
| `flutter pub get` | Bağımlılık/lock değişmedi | 0 |
| `flutter analyze` | No issues found | 0 |
| `flutter test --reporter expanded` | 130/130; 113 eski + 17 yeni | 0 |
| `flutter build apk --debug` | Built app-debug.apk; 41,4 saniye | 0 |
| `npx.cmd --yes supabase@2.119.0 db reset --local` | Sekiz migration + iki seed | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/customer_checkout_test.sql` | 94/94 PASS | 0 |
| Aynı CLI ile `product_pricing_test.sql` | 73/73 PASS | 0 |
| Aynı CLI ile `business_foundation_test.sql` | 140/140 PASS | 0 |
| Aynı CLI ile `account_scope_test.sql` | 85/85 PASS | 0 |
| `flutter test integration_test -d emulator-5554` | 3/3 PASS: preview, Customer checkout, ürün yönetimi | 0 |

**Son durum:** F6-01 kapsamındaki Faz 6 kabulü tamamlandı. Yeni Customer Android smoke ürün/birim/miktar → sepet → değişen fiyatı ikinci kez onaylama → sonuç → sistem geri akışını sınar; mevcut iki smoke korunur. Test süreci bitişi `All tests passed / EXIT_CODE: 0 / END` ile kayıtlıdır. Kurulumlar arasında yapılan ayrı ADB activity sorgusu/başlatma denemesi paket yokken sonuç vermedi; manuel açılış/görsel kabul diye sayılmadı.

**APK:** Normal build integration öncesi `build/app/outputs/flutter-apk/peksen-gida-phase6-debug.apk` olarak korundu: **238.055.769 bayt**. Build başarı kanıtı logdaki Built / EXIT_CODE: 0 / END kaydıdır. Bu normal build public config verilmeden üretildi; .env değiştirilmedi.

**Kapsam:** 392 ilgili DB assertion. Customer/Sales ayrımı, pasif/anon/Warehouse/Accounting retleri; client fiyat/iskonto reddi, integer/minimum, farklı birimlerin stok talebinin birleştirilmesi, fiyat/dönüşüm/stok farkında sıfır yazma ve yeniden onay, aynı key replay, farklı payload ret, exact 0.125 kuruş snapshot, half-up kalem toplamlarının toplanması, normal rezervasyon, stok eksiğinde sıfır rezervasyon, history/audit ve son adım hatasında tam rollback. Eski migration/seed/testler değiştirilmedi; ilgisiz Phase4 onboarding testleri tekrar çalıştırılmadı.

**Flutter:** katalog/ürün/sepet/Customer rol koruması; min/pozitif integer; değişen fiyatı ikinci kez açık onaylama; taslak yükleme ve miktarda quote temizliği; küçük ekran/klavye; geri ve boş/hata/yükleniyor. SDK transport testi gerçek Supabase Dart SDK'sını yalnız sentetik loopback HTTP sunucusuna karşı kullanır; bilinmeyen cevapta şifreli depoda anahtar koruma, kullanıcı/müşteri izolasyonu, yeniden oluşturma ve kesin SQL ret sonrası düzeltme testlidir. Bu testte secure-storage platformu mock'tur; yeni checkout için Android process-kill veya gerçek backend UI kabulü sayılmaz.

**Koşu kayıtları:** `build/phase6-validation-20261009/*.log` komut/bitiş/çıkış taşır. İlk DB koşusu taslak temizliğindeki belirsiz `items` alanını buldu; nitelikli sütunla düzeltildi. Sonraki yeni testte pgTAP domain/numeric overload cast'i düzeltildi. İlk analyze lint'leri giderildi. SDK transport fixture'ında Flutter HTTP mock'u açık loopback override ile ayrıldı; assertion kaldırılmadı. İlk başarısız DB/analyze logları da korunur. Geçmiş 81 testlik ara koşu son kabul değildir; 94 testlik son dosya geçti.

**Sınırlar:** Android smoke fixture repository ile native UI/yönlendirme kabulüdür; gerçek Supabase yetkileri ayrı DB paketinde doğrulanır. Üretim/gerçek cihaz, yeni ekranların manuel görsel kabulü ve çok bağlantılı rezervasyon stres testi yapılmadı. Cari tutar/borç/exposure, çeyrek ve sonraki stok/onay iş akışları test kapsamına alınmadı; uygulanmadı.

## Faz 5 doğrulaması — 9 Ekim 2026

| Komut | Sonuç | Çıkış |
| --- | --- | ---: |
| `flutter pub get` | Başarılı; bağımlılık/lock değişmedi | 0 |
| `flutter analyze` | No issues found | 0 |
| `flutter test --reporter expanded` | 113/113; 97 eski + 16 yeni | 0 |
| `flutter build apk --debug` | Built app-debug.apk; 42,4 saniye | 0 |
| `npx.cmd --yes supabase@2.119.0 db reset --local` | Yedi migration + iki seed | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/product_pricing_test.sql` | 73/73 PASS | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/business_foundation_test.sql` | 140/140 PASS | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/account_scope_test.sql` | 85/85 PASS | 0 |
| `flutter test integration_test -d emulator-5554` | 2/2 PASS: mevcut preview ve yeni ürün/fiyat smoke | 0 |

**Kapanış:** Onaylı Faz 5 kapsamı tamamlandı. İlgili DB toplamı 298, Flutter 113, Android smoke 2 testtir. Normal debug APK **238.014.758 bayt**; standart `app-debug.apk` integration tarafından değiştirildiğinden normal uygulama için korunan `peksen-gida-phase5-debug.apk` kullanılmalıdır. Bu koşunun build'i public config verilmeden üretildi.

**Yeni DB kapsamı:** Warehouse fiyatsız taslağı/atomic birim doğrulaması, null fiyat ve satış kilidi; yalnız Manager/Owner fiyat yetkisi; tek history/audit ve idempotent replay, farklı payload/eski fiyat ret; exact 0.25 dönüşüm, taban minimumu, yarım kuruş ve kalem seviyesinde yuvarlama, overflow, kapalı birim; müşteri/Sales aynı fiyat, müşteri ayrımı, tarih başlangıcı; exact snapshotın saklanması/değişmezliği ve katalog/iskonto değişiminden korunması; pasif hesap, Accounting/Driver/anon ret. Yeni test transaction sonunda rollback olur, seed değiştirmez. Eşzamanlı iki bağlantıyla stres testi yapılmadı; fiyat RPC'sindeki kilit sırası F5-01'de belgeli, stale-write/replay davranışı DB testlidir.

**Yeni Flutter kapsamı:** float kullanmadan para/iskonto gösterimi, büyük integer sınırı ve exact dönüşüm taşıma; Warehouse fiyat gizliliği, dört yetkisiz rol ve oturumsuz doğrudan rota, fiyat formu/doğrulama/retry anahtarı, açık satış eylemi, profil erişimi yenilenince verinin kalkması, yükleniyor/hata/boş/yeniden dene, küçük ekran-klavye ile taslak oluşturma, backend quote sonucunun kullanımı ve miktar değişince eski sonucun temizlenmesi. Host widget fixture'ları gerçek Auth/DB kanıtı değildir.

**Koşu kaydı:** `build/phase5-validation-20261009/*.log` komut/başlangıç/bitiş/çıkış kodlarını taşır. İlk reset Docker engine kapalıyken 1 verdi; `docker desktop start` 0 sonrası reset 0. `.env` veya backend bağlantı yapılandırması değiştirilmedi. İlk pgTAP `has_column` çağrısının yanlış overload'u 1/73 hata verdi; açık dört parametreli kontrolle 73/73 geçti. İlk analizdeki süslü parantez lint'leri giderildi. İki yeni widget testinde fixture/kaydırma hedefi düzeltildi; assertion zayıflatılmadı. İlk başarısız Flutter ve DB logları ayrı saklandı.

**Korunan kapsam:** Önceki altı migration, iki seed, identity/business/auth_access/account_scope/account_onboarding test dosyaları ve pubspec/lock değişmedi. Ürün/para şeması ve Warehouse erişimine doğrudan temas eden business/account_scope paketleri yeniden çalıştırıldı. Identity 19, auth_access 117, lifecycle 54 ve yerel Auth SDK 13 başarılı Faz 4 kayıtları bu tur tekrar edilmedi; yeni sonuç gibi sunulmaz. Faz 4 manuel Android kabulü yeniden açılmadı.

**Android sınırı:** Yeni `product_management_smoke_test.dart` gerçek emülatörde ürün → fiyat formu → kaydet → sistem geri akışını deterministik repository ile sınar; gerçek Supabase fiyat yazma kanıtı değildir. DB testi gerçek yerel PostgreSQL hesap/yetki kanıtıdır. Yeni ekranların backend'e bağlı manuel görsel incelemesi, fiziksel cihaz ve üretim testi bu tur yapılmadı. Normal APK integration öncesi `build/app/outputs/flutter-apk/peksen-gida-phase5-debug.apk` olarak korunur; public config verilmedi, gerçek giriş için README'deki yerel çalıştırma yapılandırması gerekir.

## Faz 4 Android kapanış kabulü — 8–9 Ekim 2026

**Faz 4'ün kalan Android kabulü tamamlandı.** Kod/test/migration/seed değişikliği yok. Aşağıdaki eski “henüz yapılmadı” ifadeleri ilgili tarihlerin kaydıdır. Gerçek auth kontrolleri yerel Supabase'e bağlı normal debug APK üzerinde; otomatik preview smoke ise config verilmeden ayrı test APK'sıyla yapılır.

| Kontrol | Gözlenen sonuç / kanıt |
| --- | --- |
| Giriş ve kayıt | Gerçek müşteri kaydı, Mailpit e-posta kodu, müşteri profili ve e-posta/parola girişi başarılı (`01–08`, `14–16`). |
| Davet kabulü | Owner yetkili yerel davetten gerçek kodla kabul; hedef warehouse rolüyle Depo profili (`25–30`). Daveti üretme Edge çağrısıyla yapıldı; Android'de davet gönder düğmesiyle gönderim ayrıca denenmedi. |
| Kurtarma / parola ekranı | Gerçek kodla yeni parola kaydı ve yeni parolayla giriş (`17–23`); mevcut parola değiştirme ekranı ve Android geri dönüşü görüldü (`10–11`). |
| Kalıcı oturum | Müşteri ve çalışanda force-stop → yeniden açılış aynı doğru profili getirdi (`09`, `31`); tamamlanan çıkış → force-stop → açılış giriş ekranında kaldı (`12–13`, `32`). |
| Owner yönetimi | Hesap/davet listeleri, sentetik müşterinin pasifleştirme ve yeniden açma onayları, Pasif → Aktif sonuçları (`45–59`). Owner sonunda çıkış yaptı. |
| Küçük ekran / klavye | 720×1280, density 360 (320 dp genişlik); giriş/kayıt/davet/kurtarma alanları kaydırılarak erişilebilir, incelenen ekranlarda taşma görülmedi (`03–06`, `14`, `19–20`, `26`). Boyut/yoğunluk sonunda reset edildi. |
| Preview / geri | Müşteri menüsü/yer tutucu, Android sistem geri zinciri girişe kadar çalıştı (`36–42`); hesap yönetiminden geri hesap ekranına döndü (`58`). |

**Ortam olayı:** Uzun kesinti/zaman değişimi sonrasında logcat uygulama, System UI ve launcher için input-timeout ANR bildirdi; `33–34` ekranları bunu gösterir. Soğuk yeniden açılış (`am start -W`: Status ok, çıkış 0) sonrasında olay gözlenen akışlarda tekrarlanmadı. Bunun uygulama kaynaklı olmadığı kesin olarak kanıtlanmış değildir; tekrarlanırsa ANR trace ile ayrıca incelenmelidir. Olay gizlenerek kesintisiz başarılı koşu iddiasında bulunulmaz.

**Sınırlar:** Android emülatör kontrolü fiziksel cihaz/üretim SMTP/release kabulü değildir. Büyük yazı ölçeği bu manuel turda denenmedi; önceki widget testi kanıtı manuel kontrol yerine geçmez. OTP/parola/token ekran görüntülerine veya dokümanlara yazılmadı; sentetik hesaplar yerel DB'de kalır. İlk Owner'ın üretimde temini, genel üyelik aktarımı ve sonraki faz iş kararları açık kalır. RLS/yetki negatif senaryoları için 7 Ekim'in 415 DB ve 13 SDK testi korunur; bu tur kod değişmediğinden reset/DB/SDK komutları yeniden çalıştırılmadı.

| Bu görevde çalıştırılan komut | Sonuç | Çıkış |
| --- | --- | ---: |
| `flutter analyze` (8 Ekim) | No issues found | 0 |
| `flutter test --reporter expanded` (8 Ekim) | 97/97 | 0 |
| `flutter build apk --debug --dart-define-from-file=build/phase4-android-acceptance-20261008/public-config.json` (8 Ekim) | Built app-debug.apk; 55,7 s | 0 |
| `flutter test integration_test/app_smoke_test.dart -d emulator-5554` (9 Ekim) | 1/1 PASS; config verilmeden giriş/önizleme smoke | 0 |

Integration sonrasında korunan normal yerel APK tekrar kuruldu (`adb install -r`: Success) ve soğuk açılış `Status: ok` verdi. Cihaz test çalıştırıcısı yerine normal uygulamanın giriş ekranında bırakıldı. Bu testin görsel/gerçek auth kabulü yerine kullanılmadığı yukarıdaki ayrı kanıt tablosunda belirtilmiştir.

Loglar: `build/phase4-android-acceptance-20261008/`, COMMAND/EXIT_CODE/END kayıtları. Korunan normal APK: `build/app/outputs/flutter-apk/peksen-gida-phase4-local-20261008-debug.apk` (**237.978.068 bayt**). Bu dosya integration test APK'sından ayrıdır; yalnız public yerel config içerir. Önceki başarılı pub get tekrar edilmedi.

## Güncel F4-05/F4-06 — 7 Ekim 2026

İstenen üç düzeltme gerçek yerel Auth SDK ile doğrulandı. **Faz 4 bütünü cihaz kabulü bekliyor.** Android smoke ile yeni gerçek auth ekranlarının görsel/kalıcı oturum kabulü aynı şey değildir.

| Çalıştırılan komut | Sonuç | Çıkış |
| --- | --- | ---: |
| `flutter pub get` | Başarılı | 0 |
| `flutter analyze` | No issues found | 0 |
| `flutter test --reporter expanded` | 97/97 | 0 |
| `flutter build apk --debug` | Built app-debug.apk; assembleDebug 431,5 s | 0 |
| `npx.cmd --yes supabase@2.119.0 db reset --local` | Altı migration, iki seed | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/identity_foundation_test.sql` | 19/19 PASS | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/business_foundation_test.sql` | 140/140 PASS | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/auth_access_test.sql` | 117/117 PASS | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/account_scope_test.sql` | 85/85 PASS | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/account_onboarding_test.sql` | 54/54 PASS; toplam 415 | 0 |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File supabase/tests/run-local-auth-check.ps1` | Gerçek Auth/SDK 9/9 | 0 |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File supabase/tests/run-local-auth-check.ps1 -TestFile account_onboarding_client_test.dart` | Gerçek onboarding SDK 4/4 | 0 |
| `flutter test integration_test/app_smoke_test.dart -d emulator-5554` | Giriş/önizleme 1/1; görsel inceleme değil | 0 |

**Önkoşullar:** Docker Desktop Linux motoru, pinned CLI 2.119.0, yalnız sentetik `peksen_gida_phase3_local`; API 55321/DB 55322/shadow 55320/Mailpit 55324. Config değişikliğini almak için yerel stop/start başarılı yapıldı. Yerel e-posta onayı, kod şablonları ve Edge runtime açık olmalıdır. Reset → beş DB paketi → SDK scriptleri sırası izlenir; iki SDK scripti aynı anda çalıştırılmaz. SDK testleri yeni sentetik hesap/kuruluş/davet bırakır; tekrar temel DB testi öncesi reset gerekir. Scriptler gerçek hedefte kullanılmaz; kod/token/parola ve CLI status çıktıları paylaşılmaz.

**Yeni regresyonlar:**

- DB lifecycle 49→54: müşterinin role/kuruluş metadata'sını yükseltememesi, doğrulanmış e-posta, Manager sınırları, süresi dolmuş/iptal edilmiş/yetkisi düşmüş davet, kabul idempotency, anon erişim yasağı, yalnız kendi kabul boolean'ı, pasif profilde iş verisinin kapalı kalması, son Owner ve açık iş korumaları, kayıt geçmişi.
- Gerçek SDK 4 senaryo: PKCE kayıt→kod→kurtarma→parola değişimi; Manager Edge daveti→kod→DB rolü→farklı parola içeren tekrarın ilk parolayı değiştirmemesi; credential kaydı sonrası yarım kabulün aynı parolayla tamamlanması; iptal edilmiş davetin profil oluşturamaması. Kısa/72 UTF-8 baytı aşan parolanın backend tarafından reddi ve yanlış uzunlukta girdinin OTP'yi tüketmemesi de sınanır.
- Flutter 85→97: kayıt/davet/kurtarma formu, küçük ekran/klavye, yönetim rol sınırı, hata temizleme; ASCII/Unicode parola sınırı ve şifreli session/PKCE depo adaptörlerinde yeniden oluşturma, URL ayrımı, çıkış sıralaması. Host testlerinde native storage mock'tur; bu testler gerçek Android depolama kanıtı değildir.

**Bitiş kanıtları:** `build/phase4-onboarding-validation-20261007/*.log`; komut, başlangıç/bitiş ve çıkış kodu kaydedilir. İlk analiz/test ve SDK HTTP-override hataları düzeltildi, ilgili kontroller yeniden geçti. `auth-onboarding-http-failure.log` başarısız SDK koşusunu saklar. Mevcut testlerin assertion'ları zayıflatılmadı; scope testine yalnız son Owner'ı korumak için ek Owner fixture'ı kondu.

**Henüz yapılmadı:** Yeni auth ekranlarının Android görsel incelemesi; gerçek hesapla uygulamayı sonlandırıp açınca session restore ve logout sonrası kalıcı silinme; üretim SMTP/ilk Owner/gerçek cihaz kabulü. Manuel kontrol için yalnız public yerel config ile uygulamayı açın: kayıt→Mailpit kodu→hesap; Owner/Manager daveti→kabul; kurtarma; Owner pasifleştirme/açma. Her ekranda küçük boyut/büyük yazı/klavye ve sistem geri davranışını gözleyin. Uygulamayı zorla durdurup yeniden açın, doğru aktif DB profilinin geldiğini; çıkıştan sonra tekrar açınca hesap verisinin gelmediğini doğrulayın. Faz 5'e geçilmez.

**APK:** Normal build integration öncesi `build/app/outputs/flutter-apk/peksen-gida-phase4-onboarding-debug.apk` olarak korundu; **237.979.014 bayt**. Build'in gerçek bitişi `build-apk.log` içindeki Built/EXIT_CODE: 0/END satırlarıyla doğrulandı. Android SDK Platform 35/CMake 3.22.1 otomatik kuruldu; native-access uyarısı çıkışı bozmadı. Public config verilmedi; APK'nın auth backend ekranları görsel olarak doğrulanmış değildir. Emülatör Android 17/API 37, cihaz `emulator-5554`; integration bitişi de logda çıkış 0'dır.

## Önceki F4-04 doğrulaması — tarihsel

## Güncel F4-04 doğrulaması — 6–7 Ekim 2026

Üç onaylı karar için yeni migration ve 85 yeni DB regresyonu doğrulandı. **Faz 4 bütünü kapanmadı:** kayıt/davet ve kalıcı oturum bu devam görevinin tamamlanan üç kararından ayrı bekleyen işlerdir. Önceki dört migration, iki seed, identity/business ve Flutter kaynak/test dosyaları değişmedi. `auth_access_test.sql` içindeki 117 assertion korunur; Accounting'in satışçı oluşturucusuna dayalı 2 satır beklentisi onaylı yalnız atanmış 1 satıra daraltıldı.

| Komut | Sonuç | Çıkış |
| --- | --- | ---: |
| `flutter pub get` | Başarılı; lock değişmedi | 0 |
| `flutter analyze` | No issues found | 0 |
| `flutter test --reporter expanded` | 85/85 | 0 |
| `flutter build apk --debug` | Built app-debug.apk, 39,9 s assembleDebug | 0 |
| `npx.cmd --yes supabase@2.119.0 db reset --local` | Beş migration, iki seed | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/identity_foundation_test.sql` | 19/19 PASS | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/business_foundation_test.sql` | 140/140 PASS | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/auth_access_test.sql` | 117/117 PASS | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/account_scope_test.sql` | 85/85 PASS | 0 |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File supabase/tests/run-local-auth-check.ps1` | Gerçek yerel Auth/SDK 9/9; fixture hash'leri geri yüklendi | 0 |
| `flutter test integration_test/app_smoke_test.dart -d emulator-5554` | Android giriş/preview 1/1; görsel inceleme değil | 0 |

DB toplamı **361** testtir (19 + 140 + 117 + 85); önceki 276 test korunur. Yeni dosya rollback fixture'ları kullanır, seed'i değiştirmez. Kapsam: anonim çağrı retleri; yalnız Owner dönüşümü; eski üyeliklerin ve müşteri/sipariş/tahsilat geçmişinin korunması; başarısız dönüşümde rol/üyeliğin korunması; açık primary/assistant seferi, açık durak ve Sales ataması engelleri; dönüşümden sonra eski kuruluş erişiminin kesilmesi; Accounting atama/alan sınırı ve atama kaldırılması; Warehouse tüm 13 sipariş durumunda üç izinli durum sınırı, exact JSON alan listeleri ve ham fiyat/müşteri/finans/yazma retleri; pasif hesapların reddi.

**Kanıt ve tekrar ilkesi:** `build/phase4-scope-validation-20261006/` loglarında komut, END ve EXIT_CODE kayıtları bulunur. 6 Ekim'de tamamlanan kontroller dosyaları değişmeden 7 Ekim devamında tekrar edilmedi. Build başarı kanıtı logdaki Built ve çıkış 0'dır; APK'nın bulunması değildir. Normal APK integration öncesi `build/app/outputs/flutter-apk/peksen-gida-phase4-scope-debug.apk` olarak korundu (**231.265.828 bayt**); standart app-debug.apk test çalıştırıcısı tarafından değişebilir. Secret/config eklenmedi.

**Önkoşullar/komutlar:** Windows PowerShell, Docker Desktop Linux motoru; yalnız sentetik `peksen_gida_phase3_local`, API 55321 / DB 55322 / shadow 55320. Motor durmuşsa başlatın; Supabase kapalıysa `npx.cmd --yes supabase@2.119.0 start`. Sonra reset → identity → business → auth_access → account_scope → yerel Auth scripti sırasını [Supabase README](../supabase/README.md) üzerinden kullanın. Başarısız komutta ilerlemeyin; canlı hedefte reset yapılmaz. Script için yalnız süreç bazlı ExecutionPolicy Bypass kullanıldı.

**Kanıt sınırı:** SQL testleri gerçek anon/authenticated DB rolleriyle çalışır; yerel SDK testi gerçek Auth/RLS profil/refresh/logout davranışını sınar. Android smoke yalnız giriş/preview gezinmesini sınar, yeni dönüşüm/Accounting/Warehouse UI akışı veya görsel inceleme değildir. Çok oturumlu yarış, üretim Auth, e-posta/davet ve kalıcı oturum doğrulanmış sayılmaz. Manuel olarak public local config ile gerçek giriş/çıkış, hata/klavye görünümü ve fiziksel cihaz davranışı kontrol edilmelidir.

## Önceki Faz 4 erişim temeli — tarihsel

## Güncel Faz 4 kontrolleri — 6 Ekim 2026

Aşağıdaki sonuçlar Faz 3 tarihçesinden ayrıdır. Faz 4 erişim çekirdeği test edildi; **self-signup/çalışan daveti ve açık alan/üyelik sözleşmeleri tamamlanmadığından Faz 4 bütünü kapanmadı**. Faz 5 yapılmadı.

| Komut | Sonuç | Çıkış |
| --- | --- | ---: |
| `flutter pub get` | Bağımlılıklar çözüldü; paket sürümleri/lock değişmedi | 0 |
| `flutter analyze` | No issues found | 0 |
| `flutter test --reporter expanded` | 85/85 (65 mevcut kapsam + 20 yeni) | 0 |
| `flutter build apk --debug` | Built app-debug.apk; son assembleDebug 17,9 s | 0 |
| `npx.cmd --yes supabase@2.119.0 db reset --local` | Dört migration + iki seed | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/identity_foundation_test.sql` | 19/19 PASS | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/business_foundation_test.sql` | 140/140 PASS | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/auth_access_test.sql` | 117/117 PASS | 0 |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File supabase/tests/run-local-auth-check.ps1` | Gerçek yerel Supabase SDK/Auth: 9/9; eski parola hash'leri geri yüklendi | 0 |
| `flutter test integration_test/app_smoke_test.dart -d emulator-5554` | Android giriş/önizleme gezinmesi 1/1; gerçek Auth UI testi değil | 0 |
| `git diff --check` | Temiz | 0 |

Emulator-5554 cihaz listesinde Android 17 / API 37 olarak bağlı doğrulandı. Son integration normal build sonrasında çalıştırıldı; çıkış 0'dır. Yeni ekran görüntüsü/görsel inceleme yapılmadı. Gerçek yerel Auth SDK testi, önizleme Android testi ve görsel kabul birbirinin yerine sayılmadı.

**Yerel önkoşullar:** Depo kökü D:\peksen_gida, Docker Desktop Linux motoru, pinned CLI 2.119.0 ve sentetik peksen_gida_phase3_local projesi. API 55321, DB 55322, shadow 55320. Servisler kapalıysa önce `npx.cmd --yes supabase@2.119.0 start`; sonra reset ve üç DB testi sırasıyla. Başarısız adımdan sonra ilerlemeyin. Cloud link/db push yoktur. Eski 543xx portları Windows tarafından ayrılan aralıkla çakıştığından kullanılmaz. Güncel tekrar komutları [Supabase README](../supabase/README.md) başındadır.

**Loglar/başarısız ilk denemeler:** `build/phase4-validation-20261006/` altında komut, bitiş ve EXIT_CODE tutulur. İlk reset port hatası 1, ilk analyze iki curly-braces lint uyarısı 1, ilk auth-live CLI stderr yardımcı script hatası 1 olarak saklandı. Düzeltmelerden sonra ilgili kontroller 0 oldu. Üyelik RPC'si ve dispose regresyonu eklendikten sonra ilgili paketler tekrarlandı. JDK native-access uyarısı build'i başarısız yapmadı. Makine execution policy değiştirilmedi; yalnız script sürecinde Bypass kullanıldı.

### Kapsam ve testlerin neyi kanıtladığı

- **Identity 19 / business 140:** Eski tablolar, seed, roller, 7 P2 kısıtları dahil bütünlük regresyonları. Identity'de 3, business'ta 3 “policy/grant yok” beklentisi artık salt authenticated SELECT/anon ret/JWT subjectsiz sıfır satır/ham yazma ret olarak güncellendi; bütünlük testleri aynen kaldı. Testleri geçirmek için erişim modeli gizlenmedi veya politikalar test sırasında kaldırılmadı.
- **Yeni DB 117:** Yedi DB rolü, auth.uid subject'leri, Owner-only maaş, Manager atama sınırı/eski ayrıcalıklı hesabı ele geçirme reddi, metadata ile rol yükseltme reddi, müşteri/üyelik/fiyat/kalem/ödeme/inbox ayrımı, Sales ataması/oluşturucusu ve yeniden atamada eski erişimin kesilmesi, Accounting projection ve yönetme yasağı, pasif profil/üyelik/kuruluş, primary/assistant/atanmamış driver run/order/vehicle/GPS sınırı, müşteri profil+üyelik transaction rollback'i, rol/atama audit'i. Fixture'lar rollback olur, seed değişmez.
- **Flutter 85:** Önceki 65 kapsam + 20 yeni test. Yedi rol için giriş/çıkış ve korumalı rota; anonim doğrudan rota; preview Owner seçiminin gerçek yetki vermemesi; boş alan/çift gönderim/hassas hata; pasif profil/oturum hatası/yenilemede eski rolün temizlenmesi; geçersiz profil; giriş beklerken ekran dispose. Mevcut küçük ekran/klavye ve 70 preview bağlantısı testleri korunur. Bir eski “giriş her durumda kapalı” testi yeni işlevle tutarlı güncellendi.
- **Canlı yerel SDK/Auth 9:** Sekiz sentetik hesapta (yedi rol, iki müşteri) gerçek Supabase signInWithPassword → RLS profil → refresh → signOut; yanlış girişte sabit hata. Script runtime anahtarı/parolayı bellekte tutar, eski seed hash'lerini geri yükler. Gerçek parola/secret dosyaya yazılmaz. Zorla kesilirse sentetik yerelde reset çalıştırılmalı. Bu test Android UI üzerinden login veya üretim Auth kabulü değildir.
- **Şema sınırı:** İş transaction'ları, stok/ödeme yarışları, ürün/fiyat hesapları, GPS paylaşımı/retention veya e-posta gönderimi test edilmiş sayılmaz. Salt SELECT politikaları bu servisleri uygulamaz. Direct writes bütün rollerde kapalı; yalnız denetlenen identity/customer RPC'leri var.

Normal build `build/app/outputs/flutter-apk/peksen-gida-phase4-debug.apk` olarak korundu: **231.265.828 bayt**. Başarı son build çıkış 0'a dayanır. APK config verilmeden üretildi; giriş demosu için public local config gerekir. Standart app-debug.apk integration runner'a ait olabilir.

**Kalan manuel/kabul kontrolleri:** Android'de gerçek public config ile müşteri/çalışan giriş ve hata/klavye görsel incelemesi; farklı fiziksel cihazlar; gerçek e-posta/davet/kurtarma; kalıcı oturum ve hesap kapatma. Yeni ekranların görsel kabulü yapılmadı. Yerel SQL ve SDK testleri üretim güvenlik incelemesinin yerine geçmez. F4-03 tamamlanmadan Faz 4'ün tamamı “tamamlandı” değildir.

## Önceki Faz 3 kayıtları — tarihsel


## Güncel sonuç — Faz 3 yedi P2 bütünlük düzeltmesi, 4 Ekim 2026

Üç migration ve iki değişmemiş seed boş yerel DB'ye başarıyla uygulandı. **Identity 19/19**, **business 140/140** (eski 97 assertion aynen + yeni 43 regresyon), **Flutter 65/65** başarılı. Tablo sayısı 35; yeni tablo, client grant veya RLS izin politikası yok. Yeni migration: `supabase/migrations/20261004000200_phase3_integrity_fixes.sql`.

| Komut | Sonuç | Çıkış kodu |
| --- | --- | --- |
| `npx.cmd --yes supabase@2.119.0 db reset --local` | Üç migration + iki seed başarılı | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/identity_foundation_test.sql` | 19/19 PASS | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/business_foundation_test.sql` | 140/140 PASS | 0 |
| `flutter analyze` | No issues found | 0 |
| `flutter test --reporter expanded` | 65/65 geçti | 0 |
| `flutter build apk --debug` | Built app-debug.apk | 0 |
| `git diff --check` | Temiz | 0 |

Her komutun son çıktısı/EXIT_CODE/bitiş zamanı `build/phase3-integrity-validation-20261004/` loglarında tutulur. İlk koşular başarılı; tekrar gerekmedi. JDK native-access uyarısı build'i başarısız yapmadı. APK normal debug uygulamasıdır; önceki integration runner çıktısı üzerinden başarı varsayılmadı. Çalıştırma önkoşulları ve CLI 2.119.0 yerel hedefi önceki bölümle aynıdır; reset üç migration'ı tarih sırasıyla uygular. Test fixture'ları rollback olur, seed dosyaları değişmez.

### Eklenen regresyonlar

| Bulgu | Negatif kontrol / korunması gereken geçerli davranış | Adet |
| --- | --- | ---: |
| 1 | Onaylı sayım kalemine ekleme/değiştirme/silme ve iki yönde taşıma reddi; bekleyen sayım düzenleme ve tam metadata ile onay kabulü | 7 |
| 2 | Kapalı veya atama geçmişi olan seferde araç değişimi reddi; ended_at/flag temizlendikten sonra kilit sürer; ilk durak kilitler; kullanılmamış sefer ve aynı araç no-op kabulü | 9 |
| 3 | False customer/driver, yanlış tür-bayrak ve finalization reddi; başarısız false olaydan sonra aynı slot/key ile gerçek customer olayı, geçerli driver/resolution kabulü | 10 |
| 4 | Kalemin aynı veya farklı müşterinin başka siparişine taşınması reddi; aynı order_id no-op kabulü | 3 |
| 5 | Eksik decided_by/decided_at ile approved/rejected ve doğrudan completed INSERT reddi; tam karar kabulü ve kanıtın sonra korunması | 7 |
| 6 | Başka siparişe/self previous_stop_id reddi; aynı siparişin önceki durağı kabulü | 3 |
| 7 | Başka ürünün sayımına veya stok hareketine dayanan düzeltme/telafi reddi; aynı ürün referansları kabulü | 4 |

Negatif örnekler yanlış kısıta takılmayacak şekilde seçildi: önceki durak testlerinde aday kayıt kapalıdır (aktif-stop unique engeli devreye girmez); sipariş kalemi taşıma testinde iade FK'sı bulunmayan kalem kullanılır; true driver bayrağıyla finalization ayrıca sınanır. Eski 97 assertion'ın metni değiştirilmedi; dosya sonuna 43 kontrol eklendi. Korunan 31 dosyada SHA-256 farkı yoktur.

**Bu turun sınırı:** Çok oturumlu yarış, yeni Android integration/görsel inceleme veya gerçek backend giriş testi yapılmadı. Sayım/araç trigger'larının satır kilitleri var; bu kayıt eşzamanlı transaction testi yapıldığını iddia etmez. Gerçek aktör yetkisi, çift onay akışı, sipariş/fiyat/stok/ödeme transaction'ları ve yeni iş formülü eklenmedi. R-01–R-07/A-14 açık; Faz 4 başlamadı. Faz 3 migration/seed/DB test kabulü korunuyor. Aşağıdaki 97 testli tablolar önceki koşuların tarihsel sonuçlarıdır.

## Önceki Faz 3 kabulü — 4 Ekim 2026 onaylı iş şeması (97 test)

**Migration/seed kabulü tamamlandı:** 25 kaynak + 10 yardımcı tablo boş yerel DB'ye kurulup sentetik kayıtlarla doğrulandı. Identity migration/seed/19 test korundu. Flutter kodu/testleri değişmeden kullanıcı tarafından istenen tekrar kontrolleri çalıştırıldı. Eski ortam blokajı geçerli değildir; aşağıdaki önceki görev sonuçları tarihçedir.

| Komut | Bitiş sonucu | Çıkış |
| --- | --- | --- |
| `npx.cmd --yes supabase@2.119.0 db reset --local` | İki migration ve sıralı iki seed başarılı | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/identity_foundation_test.sql` | 19/19 PASS | 0 |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/business_foundation_test.sql` | 97/97 PASS | 0 |
| `flutter pub get` | Bağımlılıklar çözüldü; lock değişmedi | 0 |
| `flutter analyze` | No issues found | 0 |
| `flutter test --reporter expanded` | 65/65 başarılı | 0 |
| `flutter build apk --debug` | Built app-debug.apk | 0 |

Loglar `build/phase3-expanded-validation-20261004/` altında, açık komut/başlangıç/bitiş/EXIT_CODE ile tutulur. İlk resetten sonra geçmiş koruma kısıtları genişletildiği için son reset yeniden yapıldı; iki DB testinin yukarıdaki sonuçları nihai migration'a aittir. DB/Flutter test başarısızlığı olmadı. PowerShell yardımcı scriptinin ilk execution-policy engeli Supabase komutuna ulaşmadı; sonraki süreçte `-ExecutionPolicy Bypass` kullanıldı, makine politikası değiştirilmedi. Pub sürüm bildirimi ve JDK native-access uyarısı komutları başarısız yapmadı.

**APK:** `build/app/outputs/flutter-apk/app-debug.apk`, 231.252.001 bayt; bu koşunun normal uygulama build'i. Eski APK kopyaları korundu. Build kanıtı dosya varlığı değil komut bitişi/çıkış 0'dır. Bu tur Android integration, yeni görsel kontrol veya gerçek Supabase login yapılmadı. Önceki 1/1 emulator-5554 sonucu eski kayıt olarak kalır; yeni görsel kabul sayılmaz.

### Yeni 97 DB testinin sınırı

- 35 tablo envanteri, RLS/kapalı grant/policy yokluğu; orijinal sekiz profil korunması.
- Tek depo, kategori/birim FK, exact dönüşüm; negatif/NaN/Infinity ve yanlış ürün birimi engeli.
- Generated available/sayım farkı, hareket toplamlarıyla seed stok mutabakatı, fazla rezervasyon/overpick engeli.
- Kalem fiyat/birim/iskonto/sabit miktar tutar snapshotı; katalog değişiminden bağımsızlık.
- Altı kritik olay türünde tekrar operation_key, sonuçlanmış karar key'inin korunması; immutable hareket/fiyat/status/audit/confirmation/düzeltme yapısı.
- Yanlış tahsilatı silme/ana tutarı değiştirme engeli, ayrı correction kaydı; actor/time/key zorunlulukları.
- Driver tek başına finalizes_delivery olamaz; iki aktif stop engeli, kapatıp yeniden atama ve eski satır koruması.
- Sipariş/müşteri/iade ilişkileri, tek 1–5 puan; belgeli ayar allowlist/tip/aralık ve sınırlı audit eylemleri.

Bu testler şema ve kısıt kabulüdür. **Fazla ödeme için kalan borç hesabı, payment_status senkronizasyonu, sipariş toplamının kalemlerden otomatik üretimi, rezervasyon/picking transaction'ları, yetkili çift teslim onayı, kümülatif iade sınırı, iskonto/vade hesaplama ve eşzamanlı işlem yarışları henüz çalışmaz veya test edilmiş sayılmaz.** Bunlar Faz 5–13 işlem testleridir. Faz 4 için gerçek rol izinleri ve Auth; Faz 12/14 için GPS/push; gerçek cihaz/görsel kabul ayrıca gerekir. Açık formüller R-01–R-07'de kayıtlıdır.

### Yeniden çalıştırma önkoşulları

Depo kökü, Supabase CLI 2.119.0, çalışan Docker Desktop Linux motoru, config'teki yalnız sentetik `peksen_gida_phase3_local` hedefi. Servisler kapalıysa önce `npx.cmd --yes supabase@2.119.0 start`; bu görevde servisler zaten çalıştığından tekrar start yapılmadı. Reset gerçek veri olmayan yerel DB'yi yeniden oluşturur; yeni seed yolu config'te `seed.sql` ardından `seeds/business_foundation.sql` olarak tanımlıdır. Yukarıdaki üç DB komutu sırayla çalıştırılır; hata halinde sonraki adıma geçilmez. CLI start/status çıktısındaki credential'lar paylaşılmaz. Tam komutlar ve ayar sözleşmesi [supabase/README.md](../supabase/README.md) başındadır.

## Önceki doğrulama kayıtları — tarihsel

**Kesinti sonrası kontrol:** Aynı 4 Ekim görevine devam edilirken yukarıdaki logların gerçek bitişleri ve EXIT_CODE değerleri yeniden okundu; migration/seed/test dosyaları sonuçlardan daha yenisiyle değiştirilmemiştir. Korunan identity dosyalarının, pubspec.lock ve DOCX'in hash'leri aynı; `git diff --check` çıkış 0. Başarılı DB/Flutter komutları bu salt okunur devam kontrolünde yeniden çalıştırılmadı. Yukarıdaki başarılar onay paketinin bu görevde tamamlanan koşularıdır; yeni/ikinci koşu olarak sunulmaz.

Kaynak: [Peksen_Gida_Teknik_Tasarim_v3.docx](Peksen_Gida_Teknik_Tasarim_v3.docx), özellikle §26–27, §33–37. Kayıt tarihi: 2 Ekim 2026; son durum kontrolü: 4 Ekim 2026.

Bu dosya Faz 1–3 kayıtlarını içerir. Flutter iskeleti, mevcut 42 test ve Android smoke testi korunur. Faz 3'te client/config/auth-state hazırlığı, 23 yeni Flutter testi, ilk kullanıcı–müşteri migration/seed dilimi ve 19 pgTAP kontrolü eklendi. **4 Ekim yerel DB doğrulaması: migration/reset/seed başarılı, 19/19 pgTAP PASS.** Gerçek Auth/RBAC/RLS izin matrisi ve iş modülleri aşağıda gelecek faz planı olarak kalır. Komutun burada listelenmesi başarı kanıtı değildir. Gerçek sonuçlar [PROGRESS.md](PROGRESS.md), teknik seçimler [DECISIONS.md](DECISIONS.md) içindedir.

## Faz 3 — 4 Ekim 2026, güncel yerel DB kabulü

**`blocked by local Supabase runtime` engeli giderildi.** Kullanıcının açtığı Docker Desktop, Linux motoruyla doğrulandı (Docker 29.8.1, Compose v5.5.1; engine erişimi çıkış 0). Yeni ve yalnız sentetik `peksen_gida_phase3_local` hedefinde aşağıdaki komutlar tamamlandı:

| Komut | Sonuç | Çıkış kodu |
| --- | --- | --- |
| `npx.cmd --yes supabase@2.119.0 start` | Yerel başlangıç başarılı | **0** |
| `npx.cmd --yes supabase@2.119.0 db reset --local` | Boş DB, mevcut migration ve seed ile yeniden kuruldu | **0** |
| `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/identity_foundation_test.sql` | **Files=1, Tests=19; Result: PASS** | **0** |

19 kontrolün tamamı geçti: üç tablo, yedi rol, sekiz sentetik hesap/identity, iki müşteri/üyelik, kısıtlar ve kapalı istemci erişimi. `pgTAP already exists` NOTICE hata değildir. SQL/test dosyaları değiştirilmedi. Loglar `build/phase3-db-validation-20261004/` altında, bitiş çıkış kodlarıyla ve credential satırları maskelenmiş olarak tutulur. Bu görev yalnız DB doğrulamasıdır; Flutter komutları yeniden çalıştırılmadı, önceki 65/65 ve Android 1/1 kabulü korunur. Yeni görsel kontrol veya Flutter'dan gerçek giriş testi yapılmadı.

**Faz 3 tamamlanmadı:** mevcut üç tablonun yerel kabulü tamamlandı; kaynak modeldeki diğer 22 tablo, eksik varlıklar ve iş örnekleri A-01–A-13 kararlarını bekliyor. DB temeli için runtime blokajı kapandı; kalan kapsam başarılı kabul edilmedi. Faz 4 başlamadı.

Son belge tamamlama adımında mevcut loglardan üç komutun çıkış 0 sonucu ve `Files=1, Tests=19 / Result: PASS` yeniden teyit edildi; komutlar tekrar çalıştırılmadı. Bu kabul yalnız mevcut identity/customer temelini kapsar; iskonto/cari formülleri, stok rezervasyon zamanları, sipariş durumları, para hassasiyeti ve eksik tablo/FK kararlarına beklenen sonuç eklenmedi.

## Faz 3 — 4 Ekim 2026, konteyner kurulmadan önceki doğrulama

**Tarihsel DB kabul durumu: blocked by local Supabase runtime.** Bu bölüm runtime kurulmadan önceki görevi anlatır; güncel başarı tablosu yukarıdadır. O görevde kullanıcı kurulum istemediği için boş DB, seed ve 19 pgTAP kontrolü çalıştırılmadı. Docker/Podman olmadan yapılabilecek kontroller ve tekrar kurulum yönergeleri aşağıda korunur.

| Kontrol | Docker/Podman olmadan durum |
| --- | --- |
| Migration/seed/test dosyalarının kaynakla ve birbirleriyle statik karşılaştırılması | Yapılabilir; aşağıdaki inceleme tamamlandı. SQL'in PostgreSQL tarafından kabul edildiği anlamına gelmez. |
| Sabit CLI sürümünün `start --help`, `db reset --help`, `test db --help`, `db lint --help` komutları | Yapılabilir; 2.119.0 üzerinde dört komut da çıkış 0. Yardım çıktısı çalıştırma kanıtı değildir. |
| Flutter pub get, analyze, unit/widget testleri, Android build | Supabase runtime gerektirmez. Yapılandırmasız uygulama SDK'yı başlatmaz; gerçek bağlantı sınanmaz. |
| Android integration testi | Bağlı Android hedef ve SDK gerekir; mevcut önizleme testi Supabase runtime gerektirmez. Görsel inceleme değildir. |
| `start`, `db reset --local`, `test db --local` | Bu yerel çalışma düzeninde runtime gerekir; çalıştırılmadı. Önceki start çıkış 1 kaydı korunur. |
| `db lint --local` | Çalışan PostgreSQL üzerinde denetim yapar; bağımsız SQL dosya ayrıştırıcısı değildir. Çalıştırılmadı. |

### Statik SQL incelemesi

- Migration adı sürümlü ve benzersizdir. Enum tam yedi kaynak rolünü içerir; üç tablonun alanları SPEC §25 ile eşleşir. FK oluşturma sırası, UUID kullanımı, üyelik unique kısıtı, RLS açılması ve istemci grant'lerinin kaldırılması incelendi. İş akışı/formül veya izin veren policy eklenmedi.
- Seed sırası Auth users → identities → profiles → customers → customer_users'dır. Sekiz benzersiz sentetik kullanıcı tüm rolleri, iki müşteri ve üyelik örneği müşteri ayrımını kapsar. `.invalid` e-postalar ve rastgele üretilen parola hash'leri kullanılır; gerçek sır yoktur. Migration/seed `begin`/`commit` ile çevrilidir; seed yalnız boş yerel DB için tasarlanmıştır.
- pgTAP dosyasında `plan(19)` ile 19 assertion eşleşir: 3 tablo, 1 rol listesi, 5 kayıt/ilişki sayımı, 1 sentetik e-posta, 2 RLS/policy, 2 constraint ve 5 erişim reddi kontrolü. Test `begin`/`finish()`/`rollback` düzenindedir; rol değişimleri geri alınır. Dosya `supabase/tests/database/` altında keşfedilebilir.
- Çalıştırma önkoşulları: Supabase'in yönettiği `auth.users`/`auth.identities`, `anon`/`authenticated` rolleri, `extensions` şeması, `pgcrypto` (`crypt`/`gen_salt`), pgTAP ve test bağlantısının extension oluşturma/rol değiştirme yetkisi. Bu sürümlerle çalışma uyumluluğu ve gerçek constraint/erişim sonucu runtime olmadan doğrulanamaz. Sıradan boş PostgreSQL veya Flutter testleri bu kabulün yerine geçmez.
- Statik incelemede migration/seed SQL'ini değiştirmeyi gerektiren somut hata bulunmadı. Komutlarda hedef `--local`, test yolu `supabase/tests/database/identity_foundation_test.sql` olarak açıklaştırıldı. Statik kontrol bir DB PASS sonucu değildir.

### Kullanıcının runtime kurduktan sonra çalıştıracağı komutlar

Windows'ta **Docker Desktop** kurup Linux containers motorunu başlatın veya **Podman** kurup Podman machine'i başlatın. İkisinden biri yeterlidir. Seçilen motorun CLI'ı PATH'te ve Docker API uyumlu çalışma ortamı Supabase CLI tarafından erişilebilir olmalıdır. Node.js/npx bu bilgisayarda zaten mevcut; ilk container image indirmesi için ağ ve yeterli disk alanı gerekir. Bu projedeki API/DB/shadow DB portları 54321/54322/54320 başka süreçlerce kullanılmamalıdır. [Resmî yerel kurulum](https://supabase.com/docs/guides/local-development/cli/getting-started).

PowerShell'de depo kökünde aşağıdaki bloğu çalıştırın. Her komuttan hemen sonra çıkış kodu denetlenir; hata olursa sonraki adıma geçilmez. `reset` yalnız `peksen_gida_phase3_local` projesinin yeniden üretilebilir sentetik yerel verilerini sıfırlamak içindir.

```powershell
Set-Location -LiteralPath 'D:\peksen_gida'
npx.cmd --yes supabase@2.119.0 start
if ($LASTEXITCODE -ne 0) { throw 'Supabase start başarısız; burada durun.' }
npx.cmd --yes supabase@2.119.0 db reset --local
if ($LASTEXITCODE -ne 0) { throw 'Migration/seed başarısız; burada durun.' }
npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/identity_foundation_test.sql
if ($LASTEXITCODE -ne 0) { throw 'DB testleri başarısız; burada durun.' }
```

Beklenen kanıt: migration ve seed tamamlanması, test özetinde **19 test / PASS**, her adımın çıkış kodu **0**. `--no-seed` kullanılmaz; testler seed kayıtlarına bağımlıdır. `init` yeniden çalıştırılmaz; `login`, `link`, `db push`, `--linked` veya `--db-url` gerekmez. Start/status çıktısındaki yerel anahtarları depoya/sohbete kopyalamayın. Komut sözleşmesi [CLI test db](https://supabase.com/docs/reference/cli/supabase-test-db), reset sırası [seed belgeleri](https://supabase.com/docs/guides/local-development/seeding-your-database) ve [pgTAP test düzeni](https://supabase.com/docs/guides/database/testing) ile karşılaştırıldı.

### 4 Ekim tekrar doğrulamasının sonucu

`flutter pub get`: **0**; `flutter analyze`: **No issues found / 0**; `flutter test`: **65/65 / 0**; `flutter build apk --debug`: **Built app-debug.apk / 0** (30,0 s). `flutter devices` çıkış 0 ile emulator-5554'ü doğruladı; `flutter test integration_test/app_smoke_test.dart -d emulator-5554`: **1/1 / 0**. Testler ve uygulama kodu değiştirilmedi. Dört CLI yardım komutu ve PowerShell metin envanteri de çıkış 0 verdi; bunlar DB çalıştırması değildir.

Kanıtlar `build/phase3-static-validation-20261004/` altındadır; tüm komutlar bitiş/çıkış koduyla kaydedildi. Normal APK integration öncesinde `build/app/outputs/flutter-apk/peksen-gida-phase3-20261004-debug.apk` adıyla korundu (**231.252.001 bayt**). Hash PROGRESS'tedir. JDK native-access uyarısı başarısızlığa yol açmadı. Yeni görsel kontrol veya gerçek backend bağlantısı yapılmadı. **DB testleri hâlâ çalıştırılmadı; Faz 3 tamamlanmadı.** Aşağıdaki bölümler önceki koşuların tarihsel kaydıdır.

## Faz 3 — 3 Ekim 2026 doğrulaması

4 Ekim devam kontrolünde aşağıdaki komutların gerçek log sonları ve çıkış kodları yeniden okundu. Uygulama/test kodu değişmediği için geçen kontroller tekrarlanmadı. Docker/Podman erişimi hâlâ yok; DB kontrolleri çalıştırılmış veya başarılı sayılmadı. Bu paragraf yeni bir Flutter test koşusu değildir.

`flutter pub get` **0**, `flutter analyze` **0 / No issues found**, `flutter test` **65/65 / 0**, `flutter build apk --debug` **0 / Built app-debug.apk (18,5 s)**. Son Dart kodunda 42 mevcut test ile 23 yeni test birlikte geçti. İlk denemelerde bulunan test double/abonelik/SDK depolama yaşam döngüsü hataları düzeltildi; ara başarısız veya durdurulan koşular başarı sayılmaz. İlk build C:/D: Kotlin cache hatasıyla çıkış 1 verdi; `kotlin.incremental=false` düzeltmesi sonrası başarılı oldu.

İlk `flutter devices` taramasında Android hedef yoktu; son taramada Flutter ve ADB çıkış 0 ile emulator-5554'ü doğruladı. `flutter test integration_test/app_smoke_test.dart -d emulator-5554` **1/1 / çıkış 0** ile tamamlandı (8 s). Yeni bağımlılıkla otomatik Android kontrolü yapıldı; bu görevde **görsel inceleme yapılmadı**. Supabase CLI init çıkış 0; start çıkış 1 (Docker/Podman yok). Migration/reset ve pgTAP çalıştırılmadı. Faz 3, DB ortamı ve kalan şema kararları nedeniyle tamamlanmış değildir.

Normal APK testten önce `build/app/outputs/flutter-apk/peksen-gida-phase3-debug.apk` adıyla korundu: 202.242.805 bayt. Standart `app-debug.apk` integration runner çıktısıyla değişti; Faz 2 APK'sı ayrı tutuldu. Kanıt logları ve hash PROGRESS'tedir.

### Yeni test kapsamı

- `test/supabase_config_test.dart` (16): boş, eksik ve çakışan config; public/legacy anon anahtar; secret/service_role/bozuk key reddi; HTTPS/URL doğrulaması; yerel HTTP debug sınırı; değerleri yazdırmayan tanılama.
- `test/auth_foundation_test.dart` (7): config yokken SDK çağrılmaması; eşzamanlı istemci okumasının tek başlangıcı paylaşması; gerçek SDK'nın ağsız/saklamasız başlangıcı; temizlenmiş hata; ilk session ve giriş/çıkış/error olayları; abonelik iptali; yükleniyor/hata durumunda preview; SDK hazırken girişin hâlâ kapalı olması. Widget testinde SDK isolate başlangıç/kapanışı gerçek async bölgede çalışır; ağ/auth başarısı taklit edilmez.
- `supabase/tests/database/identity_foundation_test.sql` (19, **çalıştırılmadı**): temel tablolar, yedi rol, 8 Auth/profile/identity, iki kuruluş/üyelik, sentetik adresler, RLS açık/izin politikası yok, FK/tek kullanıcı kısıtı, anon/authenticated erişimin kapalı kalması. Faz 4'ün rol bazlı erişim testleri değildir.

### Faz 3 çalıştırma düzeni

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter devices
# Yalnız bağlı Android hedef varsa:
flutter test integration_test/app_smoke_test.dart -d CIHAZ_ID
# Yalnız Docker uyumlu ortam hazırken, ayrılmış sentetik yerel hedefte:
npx.cmd --yes supabase@2.119.0 start
npx.cmd --yes supabase@2.119.0 db reset --local
npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/identity_foundation_test.sql
```

Şablonla ağsız çalıştırma: `flutter run --dart-define-from-file=.env.example -d CIHAZ_ID`. Gerçek geliştirme bağlantısı için ignore edilen `.env` kullanılır; URL ve yalnız bir public anahtar doldurulur. `.env` asset değildir, dosya kendiliğinden okunmaz. Client initialization bağlantı kontrolü sayılmaz. Gerçek URL/anahtar ile sunucu erişimi bu görevde denenmedi.

DB detayları ve seed sınırları [supabase/README.md](../supabase/README.md) içindedir. A-01–A-13 çözülmeden para/stok/sipariş beklenen sonucu veya tam şema kabulü yazılmaz. Loglar `build/phase3-validation/` altındadır. Kalan manuel kontrol: yapılandırmasız/hatalı config debug durumunun Android'de görsel görünümü; bağımsız test backend'i hazır olduğunda public config ile başlangıç. Mevcut smoke testi geçti; giriş düğmesinin kapalı kalması korunur. Gerçek auth testi Faz 4'e aittir.

## Faz 2 — 3 Ekim 2026 geçmiş doğrulama durumu

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

Hedefin kimliği farklıysa `flutter devices` çıktısı kullanılır. Geçen analyze, güncel 65 unit/widget testi ve build kod/bağımlılık değişmedikçe veya kullanıcı tekrar istemedikçe tekrarlanmaz. 4 Ekim görevinde kullanıcı açıkça tekrar doğrulama istedi. Yeni test/build hatası düzeltilirse ilgili kontrol yeniden çalıştırılır. Bitiş çıktısı ve gerçek süreç çıkış kodu ayrı kaydedilir; yarım kalan komut veya APK'nın varlığı başarı değildir. Debug build çıktısı `build/app/outputs/flutter-apk/app-debug.apk` konumundadır; release build bu fazda çalıştırılmaz.

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

CLI 2.119.0 ile üç tablonun migration/seed kurulumu ve 19 DB testi **4 Ekim 2026'da doğrulandı**. Yerel runtime engeli kapandı. Tekrar çalıştırma gerektiğinde Docker Desktop veya Podman açıkken, yukarıdaki ayrıntılı önkoşullar sağlanarak ve her adımın çıkış kodu kontrol edilerek:

```powershell
npx.cmd --yes supabase@2.119.0 start
npx.cmd --yes supabase@2.119.0 db reset --local
npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/identity_foundation_test.sql
```

`db reset --local`, **yalnızca bu proje için ayrılmış, yeniden oluşturulabilir sentetik yerel test veritabanında** boş DB'den migration+seed kurulumunu doğrular. Veri içeren mevcut/canlı ortama uygulanmaz; hedef ve veri niteliği önce doğrulanır. Son görevde reset/test çıkış 0 ile tamamlandı. Mevcut 19 test kapalı temel erişimini kapsar; ileride rol bazlı RLS testleri ayrı kullanıcı kimlikleriyle yapılır. Bu kapalı temel testi Faz 4 izin matrisi kabulü değildir. CLI status çıktısı ayrıcalıklı yerel anahtarlar içerebilir; depoya/sohbete kopyalanmaz.

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
