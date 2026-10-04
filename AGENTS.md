# Pekşen Gıda çalışma kuralları

**4 Ekim 2026 güncellemesi:** Kullanıcının onaylı B-01–B-09 kararları eski kaynak kurallarından önce gelir; ayrıntılar DECISIONS T-12/R-01–R-07'dedir. Supabase runtime engeli kapandı. Yeni business migration/seed ile 25 kaynak tablo + 10 yardımcı tablo bulunur; identity 19/19 ve business 97/97 DB testi geçti. Aşağıdaki önceki üç tabloluk/ortam bekleyen kayıtlar tarihçedir. Gelecek iş servisleri için kalan kararlar vardır; gerçek Auth/RBAC/RLS veya sipariş/tahsilat işlem servisleri bu görevde yapılmaz.

## Amaç ve mevcut aşama

Pekşen Gıda, tek satıcılı ve tek depolu, Android öncelikli B2B gıda tedarik, saha satış, depo, dağıtım ve tahsilat sistemidir. Flutter mimarisi gelecekte iOS'a genişleyebilir; MVP'de iOS build yoktur.

Faz 1–3 tamamlanmıştır; Faz 3 kabulü **Supabase migrations + seed ve mevcut güvenli config/client/auth-state hazırlığı** ile sınırlıdır. Kullanıcının onayladığı B-01–B-09 kararlarıyla 25 kaynak tablo ve 10 yardımcı tablo kuruldu. Mevcut preview/routing/65 Flutter testi korunur; DB 19+97 test, pub get/analyze/debug build çıkış 0. Gerçek giriş/kayıt, Auth/RBAC/RLS izin politikaları ve iş transaction servisleri yapılmadı. R-01–R-07/A-14 ilgili sonraki fazlardan önce karara bağlanır. Faz 4 için yeni görev beklenir; bu tur başlatılmaz. Commit, push ve yayınlama yapılmaz. Şema kabulü uygulamanın veya üretim hazırlığının tamamlandığı anlamına gelmez.

## Kaynaklar ve devam düzeni

1. Önce çalışma klasörünü, `git status --short --branch` çıktısını, mevcut dosyaları ve geçerli `AGENTS.md` talimatlarını incele. İlgisiz değişiklikleri koru.
2. [Ana tasarım](docs/Peksen_Gida_Teknik_Tasarim_v3.docx), [SPEC](docs/SPEC.md), [PLAN](docs/PLAN.md), [DECISIONS](docs/DECISIONS.md), [PROGRESS](docs/PROGRESS.md) ve [TESTING](docs/TESTING.md) dosyalarını oku. Kaynağı okuyamıyorsan kapsamı tahmin etme; engeli açıkça bildir.
3. DOCX ana tasarımdır; SPEC aynı kapsamın Markdown aktarımıdır. Çelişkiyi sessizce çözme: kullanıcıya bildir, karar kaydına geçir. Kaynak DOCX'i bu hazırlık görevi kapsamında değiştirme.
4. Her görevin amacı, kapsamı, bağımlılıkları, kabul ölçütleri ve doğrulama komutları belirli olsun. Önce küçük çalışan uçtan uca akış, ardından aynı rolün diğer ekranları geliştirilir.
5. İş sonunda karar ve ilerleme kayıtlarını güncelle. Tamamlanan ölçütleri, dosyaları, komut/sonuçları, çalıştırılamayan kontrolleri ve nedenlerini, riskleri ve sonraki somut görevi raporla. Sohbet hafızasını proje kaydı yerine kullanma.

## Korunacak iş kuralları

- Roller yalnızca `customer`, `sales_operator`, `warehouse`, `accounting`, `driver`, `manager`, `owner` olarak tanımlıdır. Kaynaktaki `Order Operator` ifadesinin eşlemesi açıktır; sekizinci rol ekleme veya kendiliğinden yetki atama.
- Müşteri e-posta/şifre ile kaydolur ve doğrudan aktif olur. MVP'de kuruluş başına tek kullanıcı olsa da `customer_users` korunur. Çalışan hesaplarını Owner/Manager oluşturabilir; rol veritabanında tutulur.
- Sipariş miktarı integer olur; ürünün ambalaj/gramaj metni miktarla karıştırılmaz. Global minimum sipariş tutarı yoktur; ürün bazlı minimum miktar vardır. Stoksuz ürün katalogda `Stok Yok` olarak kalır.
- Warehouse ürün oluşturabilir. Başlangıçta Warehouse, Accounting, Manager ve Owner fiyat değiştirebilir. Eski/yeni fiyat, aktör, zaman ve gerekçe kaydedilir.
- Fiyatı backend yeniden hesaplar; client fiyatı güvenilir kabul edilmez. Müşteri ve onun adına çalışan Sales Operator aynı fiyatı görür. Sipariş fiyat snapshotları geçmiş fiyatı korur; kaynakta farklı yazılmış alan adları uygulama öncesinde kararlaştırılır.
- B-04/B-05: İskonto takvim çeyreğindeki müşteri onaylı net teslimat toplamından önerilir; ödeme şartı yoktur, iadeler düşülür. Manager/Owner onayı sonraki çeyrekte etkilidir. Para integer kuruş, yuvarlama kalem seviyesidir. 50K/%4, 70K/%6, 100K/%8 test eşikleridir; gömülmez. Gerçek eşikler, cari limit formülü ve kesirli kuruş/yuvarlama yönü açık kalır.
- B-01/B-03: Cari limit aşımı Manager/Owner onayına gider; onay submitted, ret rejected olur. Draft/rejected rezervasyon üretmez. Aşım kararı audit/history üretir; limit formülü hâlâ açık, hesap backend'dedir.
- `customer_app` ve `sales_operator` aynı OrderService/backend transaction akışını kullanır. Kaynak ve oluşturan kullanıcı kaydedilir.
- Sipariş geçişleri history/audit üretir; yetkisiz doğrudan status UPDATE yasaktır. Hazırlanmış/loaded/out_for_delivery sipariş doğrudan değiştirilemez; değişiklik/iptal ve alternatif akışları SPEC'e bağlıdır.
- B-02: `available_qty = physical_qty - reserved_qty`; submitted rezervasyonu artırır, picked fiziksel ve rezervi azaltır, kalemin picked_qty değerini artırır. Kısmi picking vardır; sipariş miktarı aşılmaz. İptal/iade telafi hareketidir; sayımı Manager/Owner onaylar. Hareket geçmişi immutable'dır, aynı işlem iki kez uygulanmaz. Kilitli iş transaction'ları sonraki fazdadır.
- Tek sefer tek araçla ilişkilidir; primary/assistant driver desteklenir. Siparişin iki araca bölünmesi MVP'de kapalıdır.
- GPS yalnızca `out_for_delivery` sırasında paylaşılır, teslimat/sefer sonunda kapanır. Müşteri sadece kendi aktif teslimatının son konumunu görür. Harita araç marker'ı ve son güncellenme zamanını gösterir; rota optimizasyonu/geocoding yoktur.
- B-06: Normal teslimat Driver ve Customer onayıyla kesinleşir. Uyuşmazlık veya müşteri onayı yerine exception çözümü Manager/Owner yetkisindedir. Tek driver girişi borç oluşturmaz. Fotoğraf/imza/QR zorunlu değildir; opsiyonel kanıt erişim kontrollü Storage'dadır.
- B-03/B-06: Tahsilat nakit/POS'tur; Sales Operator ve sefere atanmış iki driver da giriş yapabilir; fiili tahsil eden kaydedilir. Accounting doğrular. Kısmi ödeme vardır, fazla ödeme yoktur. Kayıt silinmez, düzeltme/telafi eklenir. Online ödeme ve genel müşteri avansı yoktur.
- Müşteri yalnız Driver'ı, teslim edilmiş sipariş başına bir kez, 1–5 yıldızla puanlar. Maaş/prim yalnız Owner erişimindedir.
- Normal fiyat değişimi toplu bildirim değildir; Manager/Owner hedef gruplu kampanya olayı oluşturabilir. FCM ve bildirim geçmişi/deep link kapsamda kalır.
- Offline kritik işlem, SMS OTP, PDF fatura, çoklu satıcı/depo, tam satın alma/tedarikçi yönetimi ve ileri muhasebe ERP MVP kapsamına eklenmez. Tam kapsam dışı liste SPEC §31'dedir.

## Mimari ve klasörler

Mevcut dosyalar kökte `AGENTS.md`, `README.md`, `.gitignore`, `.env.example`, Flutter `pubspec.yaml`/`pubspec.lock` ve araç yapılandırması; `docs/` altında kaynak DOCX ve beş Markdown kaydıdır. Faz 2'de `lib/`, `android/`, `test/` ve `integration_test/` oluşturulmuştur. `integration_test/app_smoke_test.dart` Android giriş ve önizleme gezinmesini sınar; `supabase/` Faz 3 yerel temelini taşır (aşağıdaki güncel bölüm). Flutter oluşturucusu başlangıçta geçici klasörde çalıştırılmış, gerekli iskelet dosyaları seçilerek kopyalanmıştır; mevcut README ve `.gitignore` oluşturucu çıktısıyla değiştirilmemiştir. Yarıda kalan Faz 2 mevcut dosyalardan sürdürülmüş, proje yeniden oluşturulmamıştır.

Hedef düzen (Faz 2'deki iskelet ileriki fazlarda genişletilecek):

```text
lib/
  core/       # auth, config, errors, networking, routing, theme,
              # permissions, notifications, realtime, location
  features/   # auth, customer, products, pricing, orders, inventory,
              # delivery, payments, ratings, employees, reports, owner
    <feature>/
      data/
      domain/
      presentation/
  shared/
    widgets/
    models/
test/
integration_test/ # Faz 2 Android açılış ve önizleme testi mevcut
supabase/     # Faz 3: sürümlü migrations, sentetik seed ve DB testleri
docs/
```

Faz 2'de `lib/features/auth/presentation` yalnız giriş arayüzünü, `lib/features/preview/domain` kaynak rol/ekran envanterini ve `lib/features/preview/presentation` geliştirme önizlemesini taşır. Bu preview feature gerçek müşteri, stok, fiyat veya yetkilendirme modülü değildir. SPEC §28'deki iş feature'ları ancak kendi fazlarında uygulanır.

Riverpod, go_router ve repository/service ayrımı korunur. Supabase Auth e-posta/şifre; PostgreSQL ana veri; RLS yetki; RPC/Edge Functions kritik business transaction; Realtime sipariş/teslimat/GPS; Storage gerekli teslimat kanıtı; FCM Android push içindir. Faz 12 harita hedefi MapLibre'dır; sağlayıcı/retention kararı ayrıca doğrulanır.

İş kurallarını widget'lara dağıtma. Fiyat/stok/sipariş/ödeme işlemlerini backend transaction içinde yürüt. Migrationları sürümlü tut; rol denetimini yalnız menü gizlemeye bırakma. İdempotency, kilitleme, TL/yuvarlama ve birim hassasiyeti kararlarını uygulamadan önce kaydet. Mock ekranları gerçek backend entegrasyonu olarak raporlama.

## Faz 3 mevcut hazırlık

**Güncel kapsam:** `20261004000100_business_foundation.sql`, `seeds/business_foundation.sql` ve `tests/database/business_foundation_test.sql` eklendi; ilk identity migration/seed/19 test korunur. Şemada 35 tablo RLS açık ve istemci grant kapalıdır; hiçbir izin veren policy yoktur. Yalnız yapısal bütünlük/immutable geçmiş trigger'ları vardır, gerçek workflow RPC'si yoktur. Bu bölümün aşağıdaki 3/4 Ekim ortam engeli ve üç tablo ifadeleri önceki görevlerin tarihsel kaydıdır; son kabul PROGRESS/TESTING'in başındadır.

4 Ekim 2026 kullanıcı talebi: Docker Desktop/Podman şimdilik kurulmaz. Statik migration/seed/test incelemesi ve CLI komut sözleşmesi doğrulaması yapılır; DB kabulü **blocked by local Supabase runtime** olarak kalır. Kullanıcı ayrıca Flutter doğrulamalarının tekrarını istemiştir; güncel sonuçlar PROGRESS/TESTING'de önceki koşulardan ayrı tutulur. Runtime kurulduğunda yalnız sentetik yerel hedefte TESTING'deki `start → db reset --local → test db --local` akışı kullanılır.

4 Ekim tekrar koşusunda pub get/analyze/debug build çıkış 0; unit/widget 65/65 ve emulator-5554 integration 1/1 çıkış 0. Statik SQL incelemesi/CLI yardım kontrolleri tamamlandı; migration, seed ve DB test kodu korunmuştur. Normal APK bu koşu için `peksen-gida-phase3-20261004-debug.apk` adıyla saklandı (231.252.001 bayt); aşağıdaki önceki APK/başlangıç kayıtları 3 Ekim geçmişidir. DB komutları bu tur çalıştırılmadı ve görsel inceleme yapılmadı.

`supabase/` artık mevcuttur: yerel config, `migrations/20261003000100_identity_foundation.sql`, `seed.sql`, `tests/database/identity_foundation_test.sql` ve [kurulum kaydı](supabase/README.md). Kaynak veri modelinin yalnız `profiles/customers/customer_users` dilimi yazıldı; diğer tablolar karar bekler. RLS açık, istemci grant'leri kapalı ve izin veren policy yoktur; bu Faz 4 yetkilendirmesi değildir. Yedi rol için sekiz sentetik Auth/profile kaydı ve iki kuruluş hazırlanır. Gerçek parola yoktur; seed DB'de çalıştırılmadı.

`lib/core/config/supabase_config.dart` build-time public config'i denetler, `core/networking/supabase_bootstrap.dart` SDK başlangıcını paylaşır. `features/auth/data/domain/presentation` yalnız oturum gözlem repository/provider'larını taşır; giriş düğmesi kapalıdır. Debug önizlemesi korunur. Oturum saklama/yenileme ve auth deep link kapalıdır. `supabase_flutter: 2.18.0` eklendi; teknik sınırlar T-07–T-10/A-14'tedir. `.env` asset değildir; `--dart-define-from-file=.env` ile aktarılır, değerler APK'dan çıkarılabilir; yalnız public anahtar verilir.

Supabase CLI `npx.cmd --yes supabase@2.119.0` ile kullanılabilir. Yerel `start`, Docker/Podman bulunamadığı için çıkış 1 verdi. Migration/reset/DB testleri çalıştırılmadı; cloud link veya canlı migration yapılmadı. Faz 3'te pub get/analyze/build çıkış 0, Flutter testleri 65/65 (önceki 42 + yeni 23) çıkış 0'dır. İlk taramada Android yoktu; son taramada yeniden bağlanan emulator-5554 üzerinde mevcut integration testi 1/1 ve çıkış 0 ile geçti. Yeni görsel inceleme yapılmadı. Normal APK `peksen-gida-phase3-debug.apk` olarak korundu. Son komut sonuçları PROGRESS/TESTING'dedir.

## Kurulum ve doğrulama komutları

Komutlar depo kökünde PowerShell ile çalıştırılır. Ayrıntılı önkoşullar [TESTING](docs/TESTING.md) içindedir.

```powershell
git status --short --branch
rg --files --hidden -g '!.git/**'
git diff --check
flutter --version
flutter doctor -v
```

İskelet oluşturma veya yeniden üretme işlemlerinde mevcut dosyalar korunur; `--overwrite` kullanılmaz. Geçici uygulama kimliği `com.example.peksen_gida`, görünen ad `Pekşen Gıda`dır; yayın kimliği değildir. Flutter `3.47.6`, Dart `3.13.5`, Android SDK `37.0.0`, Android Studio JBR `25.0.3`; doğrudan uygulama paketleri `flutter_riverpod: 3.4.3` ve `go_router: 18.0.2` olarak seçilmiştir. `flutter_localizations` ve geliştirme bağımlılığı `integration_test` Flutter SDK'dan gelir; `pubspec.lock` korunur. Gerekçe ve sınırlar DECISIONS T-01–T-06'dadır.

3 Ekim 2026 son kabulünde **Faz 2 tamamlandı**. Önceki `flutter pub get`, `flutter analyze`, 42 unit/widget testi ve `flutter build apk --debug` kayıtları çıkış 0'dır; bu başarılı komutlar tekrarlanmadı. Bağlı Android emülatöründe mevcut integration testi de 1/1 başarı ve çıkış 0 ile tamamlandı. Korunan debug APK, yeniden derlenmeden ADB ile kurulup açıldı; gözlenen ekranlar ve görsel kontrol sınırları PROGRESS/TESTING'dedir. Bu sonuç gerçek backend veya üretime hazır uygulama kabulü değildir. Aşağıdaki komutların listelenmesi hepsinin bu tur çalıştırıldığı anlamına gelmez:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter test integration_test/app_smoke_test.dart -d CIHAZ_ID
# Manuel ekran kontrolü için:
flutter run -d CIHAZ_ID
```

Son görevde `emulator-5554` (Android 17 / API 37) Flutter ve ADB ile bağlı doğrulandı; önceki kontroldeki bağlantı yokluğu giderildi. `CIHAZ_ID` her çalıştırmada `flutter devices` çıktısından seçilir. Test çalıştırıcısı standart `app-debug.apk` dosyasını değiştirdiği için normal uygulama APK'sı önceden `build/app/outputs/flutter-apk/peksen-gida-debug.apk` adıyla korundu (188.813.782 bayt). Supabase yerel kurulum ve SQL/RLS test komutları TESTING'de önkoşullarıyla bulunur. Bu paragraf Faz 2 kabulünün tarihsel kaydıdır. Faz 3 yerel başlangıç/config durumu yukarıdadır; canlı veritabanına bağlanılmaz.

Geliştirme önizlemesi hem giriş görünürlüğünde hem router'da `kDebugMode` ile sınırlandırılır. Rol seçimi geçici arayüz durumudur; oturum, veritabanı rolü veya yetki sağlamaz. Release/profile sürümünde önizleme yolu kapalıdır. İmzalı release yapılandırması Faz 17'ye bırakılır; debug anahtarıyla release imzalama kullanılmaz.

Eşleşmeyen yollar `onException` üzerinden kayıtlı `/not-found` rotasına gider. Bulunamadı ekranında Android sistem geri olayı girişe döner; boş rota eşleşmesi üzerinden geri işlemine dönülmez. T-04'teki davranış için başlangıç bağlantısı ve açık uygulamada gezinme regresyonları korunur. Normal alt ekranlarda geri sırası ekran → rol menüsü → önizleme → giriştir.

## Kalite kapısı

Flutter değişikliğinde analyze ve ilgili unit/widget testleri; SQL/RLS değişikliğinde DB/yetki/transaction testleri; tamamlanan akışta integration testleri çalıştırılır. Mobil bağımlılık veya platform değişikliği ve uygulama fazı tamamlanınca Android debug build alınır. GPS, bildirim ve release kabulü gerçek cihaz ister. Fiyat, stok, sipariş ve ödeme regresyonları zorunludur. Ölü/tekrarlanan kod, TODO/FIXME ve sırları kontrol et; her TODO bir takip maddesine bağlı olsun. Düzeltmeden sonra ilgili kontrolü yeniden çalıştır.

Çalıştırılmamış test başarılı değildir. Uygulanabilir kontrol ortam nedeniyle çalışmıyorsa faz `doğrulama bekliyor` olur; `tamamlandı` yazılmaz. Faz 1'de yalnız doküman kapsamı ve repo bütünlüğü doğrulanmıştır. Faz 2'de analyze, ilgili unit/widget testleri, Android debug build ve seçilen Android hedefte açılış kontrolü gereklidir. Emülatör kabulü, Faz 12/14/17'nin gerçek cihaz kabulünün yerine geçmez.

## Hassas işlem sınırları

Gerçek parola, service_role/secret key, veritabanı parolası, FCM sunucu yetkisi ve imzalama anahtarı depoya veya sohbet metnine yazılmaz. APK yalnız anon/publishable istemci anahtarı alabilir; bu RLS'nin yerine geçmez. `.env` ve yerel kimlik bilgileri ignore edilir; örnek dosyada gerçek değer bulunmaz. Hassas tabloda RLS yoksa üretime hazır kabul etme; kanıt dosyaları da erişim kontrollü olmalıdır.

Kalıcı veri silme, canlı veritabanı migrationı ve yayınlama ayrıca kullanıcı yetkisi gerektirir. Bu görev commit/push/yayınlamayı açıkça yasaklar. Yetkili yerel geliştirme ve geri alınabilir doğrulama için her dosyada yeniden izin isteme. Karar bekleyen iş mantığına bağımlı kodu başlatma; bağımsız çalışmayı sürdürebilirsin.
