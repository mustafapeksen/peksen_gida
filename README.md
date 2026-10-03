# Pekşen Gıda

Tek satıcılı, tek depolu, Android öncelikli B2B gıda tedarik, saha satış, depo, dağıtım ve tahsilat projesi. **Faz 1 ve Faz 2 tamamlandı.** Analyze, 42 unit/widget testi, Android debug build ve emülatörde 1 integration testi başarılıdır; normal APK açılışı ve sınırlı görsel kontrol de yapıldı. Gerçek Auth/RBAC/RLS, Supabase şeması ve iş modülleri henüz uygulanmadı. 3 Ekim 2026 kabul kanıtları ve görsel kapsam sınırları [PROGRESS](docs/PROGRESS.md) içindedir.

Ana kaynak [Pekşen Gıda Teknik Tasarım ve Codex Geliştirme Planı v3](docs/Peksen_Gida_Teknik_Tasarim_v3.docx), 1 Ekim 2026 revizyonudur. Kaynak dosya korunur; tüm metin ve tablolar [SPEC](docs/SPEC.md) içinde bulunur. Formülü veya durum sınırı eksik konular karar kaydında açık tutulur.

## Belgeler

| Dosya | İçerik |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Çalışma düzeni, iş kuralları, mimari, komutlar ve işlem sınırları |
| [docs/SPEC.md](docs/SPEC.md) | Kaynağın 39 bölümü, tüm iş kuralları, yedi rol, ekranlar, veri modeli ve kapsam dışı maddeler |
| [docs/PLAN.md](docs/PLAN.md) | 17 faz, bağımlılıklar, kabul ölçütleri ve durumlar |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Kaynak kararları, Faz 2 teknik seçimleri T-01–T-06 ve çözülmemiş iş soruları |
| [docs/PROGRESS.md](docs/PROGRESS.md) | Son doğrulanan durum, komut sonuçları, engeller ve sıradaki görev |
| [docs/TESTING.md](docs/TESTING.md) | Yerel kurulum, rol senaryoları, kalite kapıları ve cihaz kontrolleri |
| [.env.example](.env.example) | Değersiz istemci ortam değişkeni şablonu |
| [.gitignore](.gitignore) | Yerel ayarlar, sırlar ve gelecek build çıktıları için ignore kuralları |

## Hedef mimari

Flutter + Riverpod + go_router, feature başına `data/domain/presentation` ve repository/service ayrımı kullanılır. Supabase Auth, PostgreSQL, RLS, RPC/Edge Functions, Realtime ve erişim kontrollü Storage backend'i oluşturur. Android push FCM, Faz 12 harita hedefi MapLibre'dır. Harita yalnız aktif teslimat aracını gösterir.

Roller: `customer`, `sales_operator`, `warehouse`, `accounting`, `driver`, `manager`, `owner`. Nakit/POS tahsilatı vardır; online ödeme, PDF fatura, SMS OTP, rota optimizasyonu, geocoding, iOS build ve çoklu depo/satıcı MVP dışında kalır. Tam liste SPEC §31'dedir.

## Mevcut ve planlanan klasörler

```text
peksen_gida/
  AGENTS.md
  README.md
  .gitignore
  .env.example
  pubspec.yaml
  pubspec.lock
  analysis_options.yaml
  android/
  lib/
    core/         # yapılandırma, tema, routing
    features/
      auth/       # yalnız giriş arayüzü
      preview/    # geliştirme rol/ekran envanteri
    shared/       # ortak önizleme ve durum bileşenleri
  test/           # Faz 2 unit/widget kabul testleri
  integration_test/ # Android açılış ve önizleme testi
  docs/
    Peksen_Gida_Teknik_Tasarim_v3.docx
    SPEC.md
    PLAN.md
    DECISIONS.md
    PROGRESS.md
    TESTING.md
```

Flutter iskeleti başlangıçta geçici klasörde üretilip gerekli dosyalar seçilerek depoya kopyalandı; oluşturucunun README ve `.gitignore` dosyaları kopyalanmadı. Yarıda kalan Faz 2 mevcut dosyalar üzerinden tamamlanır; proje yeniden oluşturulmaz. `integration_test/app_smoke_test.dart` giriş ve önizleme gezinmesini sınar. `supabase/migrations` ve sentetik seed Faz 3'te oluşturulacaktır. Tam hedef Flutter ağacı SPEC §28'dedir. Klasörlerin varlığı gerçek backend entegrasyonu anlamına gelmez.

## Ortam ve kurulum

2 Ekim 2026 Faz 2 araç tabanı Flutter stable `3.47.6`, Dart `3.13.5`, Android SDK `37.0.0` ve Android Studio JBR `25.0.3` olarak kaydedildi. Git `2.55.0.windows.5`; `flutter doctor -v` sorun bildirmedi ve Android lisansları kabul edilmiş. Geçici Android uygulama kimliği `com.example.peksen_gida`, görünen ad `Pekşen Gıda`dır; ticari yayın kimliği henüz belirlenmedi.

`pubspec.yaml` doğrudan `flutter_riverpod: 3.4.3` ve `go_router: 18.0.2` sürümlerini tam olarak seçer; `flutter_localizations` ve geliştirme bağımlılığı `integration_test` Flutter SDK'dan gelir. Çözülen paket sürümleri `pubspec.lock` içinde korunur. Paket sürüm kaynakları: [flutter_riverpod sürümleri](https://pub.dev/packages/flutter_riverpod/versions) ve [go_router sürümleri](https://pub.dev/packages/go_router/versions).

Son devam görevinde `emulator-5554` (Android 17 / API 37) yeniden bağlandı; Flutter ve ADB ile doğrulandı. Integration testi ve normal APK açılış kontrolü bu hedefte yapıldı. Fiziksel cihaz kabulü yapılmadı. Supabase CLI ve Docker Faz 1 tanılamasında PATH üzerinde bulunamadı; kullanılabilirlikleri Faz 3 öncesinde doğrulanmalıdır. Ayrıntılı araç yolları ve sonuçlar PROGRESS/TESTING içindedir.

Depo kökünde PowerShell ile:

```powershell
Set-Location D:\peksen_gida
git status --short --branch
rg --files --hidden -g '!.git/**'
flutter --version
flutter doctor -v
flutter devices
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter test integration_test/app_smoke_test.dart -d emulator-5554
flutter run -d emulator-5554
```

Önceki loglarda `flutter pub get`, `flutter analyze`, `flutter test` (**42/42**) ve `flutter build apk --debug` için çıkış kodu **0** doğrulandı; başarılı komutlar tekrarlanmadı. Bu görevde `flutter test integration_test/app_smoke_test.dart -d emulator-5554` **1/1 başarı ve çıkış 0** ile bitti. Normal uygulama APK'sı [peksen-gida-debug.apk](build/app/outputs/flutter-apk/peksen-gida-debug.apk), **188.813.782 bayt** (yaklaşık 180,07 MiB) olarak korundu. Standart `app-debug.apk` son integration çalıştırıcısının çıktısıdır; uygulama kurulumu için korunan dosya kullanılır. Loglar ve ekran görüntüleri `build/phase2-validation/` altındadır; Git dışında tutulur. Kalıcı sonuç özeti PROGRESS'tedir.

## Faz 2 geliştirme önizlemesi

Giriş ekranı yalnız arayüzdür; kimlik doğrulama, hesap oluşturma veya sunucu oturumu açmaz. Debug sürümdeki geliştirme önizlemesi yedi rolün menüsünü ve SPEC §23'teki 70 ekran bağlantısını sunar. Bağlantılar açıklayıcı ekran kabuklarına gider; sipariş, fiyat, stok, cari, tahsilat ve teslimat işlemi yapmaz. Rol seçimi yalnız bellekteki önizleme durumudur, kullanıcı yetkisi değildir.

Yollar: `/` giriş, `/login` aynı girişe yönlenen alias, `/preview` önizleme, `/preview/roles/:roleId` rol menüsü, `/preview/roles/:roleId/:screenId` ekran kabuğu ve `/preview/states/loading`, `/preview/states/empty`, `/preview/states/error` ortak durumlarıdır. Doğrudan alt ekran açıldığında da geri sırası ekran → rol menüsü → önizleme → giriştir. Eşleşmeyen yol kayıtlı `/not-found` rotasına gider; geçersiz rol/ekran/durum da Türkçe bulunamadı görünümünü gösterir. Bu görünümde dönüş eylemi veya Android sistem geri olayı girişe götürür. Önizleme hem girişte hem router'da `kDebugMode` ile kapatıldığından profile/release sürümlerinde açılamaz. Türkçe yerelleştirme ve Material 3 yeşil/krem tema kullanılır.

`test/app_test.dart`, kaynak menü envanterini, önizleme erişim sınırını, 70 ekran bağlantısını, Android sistem geri davranışını, geçersiz yolları ve küçük ekranda büyük yazı/klavyeyle erişimi sınar. `integration_test/app_smoke_test.dart` Android üzerinde giriş → önizleme → Depo → ürün ekran kabuğu, geri dönüş ve boş liste akışını çalıştırır. Otomatik testler tüm cihazlarda görsel kabul anlamına gelmez; kapsam TESTING'de, sonuçlar PROGRESS'tedir.

Release imzalama henüz yapılandırılmadı; şablondaki debug anahtarıyla release imzalama kaldırıldı. İmzalı yayın hazırlığı Faz 17'nin görevidir.

## Ortam değişkenleri

`.env.example` içindeki `SUPABASE_URL` ve `SUPABASE_ANON_KEY`, ileriki istemci entegrasyonu için adlandırılmış boş alanlardır. `SUPABASE_ANON_KEY` yalnız anon veya publishable istemci anahtarını taşıyabilir. Service role/secret key mobil uygulamaya konulmaz.

Backend entegrasyonu sırasında, mevcut `.env` yoksa aşağıdaki komutla yerel şablon oluşturulabilir. Bu komut Faz 1–2 kurulumunun bir parçası değildir; gerçek değerler depoya eklenmez:

```powershell
if (-not (Test-Path -LiteralPath .env)) {
  Copy-Item -LiteralPath .env.example -Destination .env
}
```

`.env` kendiliğinden yüklenmez; okuma/aktarma mekanizması entegrasyon görevinde uygulanıp doğrulanacaktır. FCM ve harita sağlayıcısı ayarları ilgili fazda tanımlanacak; bu şablon bunların kurulduğu anlamına gelmez.

## Devam

Faz 2'nin iskelet kabulü tamamlandı; engelleyici test/build hatası kalmadı. Görsel olarak giriş, klavyede iki alana erişim, rol seçim listesi, Depo/Ürünler örneği, yükleniyor/boş/hata ve örnek geri akışı incelendi. Diğer altı rolün ayrı menü/ekranları, farklı cihaz boyutları, Android'de büyük yazı ve fiziksel cihaz görsel kontrolü yapılmadı; bunlar TESTING'de ayrıca listelenir. Yedi rol/70 bağlantının tamamı widget testlerinde doğrulanmıştır. Geçen kontroller kod/bağımlılık değişmedikçe gereksiz yere tekrarlanmaz. Faz 3 yalnız yeni kullanıcı göreviyle başlayabilir; A-01–A-13 iş kararları açık kalır. Commit, push ve yayınlama yapılmaz.
