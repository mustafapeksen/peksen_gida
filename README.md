# Pekşen Gıda

**Faz 5 — 9 Ekim 2026:** Hesabım → Ürünler ve birimler üzerinden Warehouse/Manager/Owner taslak ürün ve satış birimleri oluşturabilir. Fiyatı belirleme, geçmişi okuma, satışa açma ve müşteri fiyatı hesaplama yalnız Manager/Owner ekranlarındadır. Warehouse/Accounting fiyat sınırları korunur. Fiyat hesabı Supabase RPC'sindedir; sepet/sipariş/stok rezervasyonu ve çeyrek önerisi eklenmedi. Yedinci migration gerekir; yerel kurulum ve son testler [TESTING](docs/TESTING.md), onaylı kurallar [F5-01](docs/DECISIONS.md) içindedir. Bu özellikler debug rol önizlemesinden ayrı gerçek oturum ister.

**Güncel durum — 9 Ekim 2026:** Faz 1–4 tamamlandı (yerel geliştirme kabulü). Auth/RBAC/RLS, e-posta koduyla kayıt/davet/kurtarma, Owner hesap yaşam döngüsü ve şifreli kalıcı oturum hazırdır. Android emülatöründe gerçek müşteri/çalışan oturumunun yeniden açılışta geri yüklenmesi, çıkış sonrası geri gelmemesi ve yeni ekranların küçük ekran/klavye/geri kontrolleri tamamlandı. Sonuçlar ve sınırlar [TESTING](docs/TESTING.md), açık kararlar [DECISIONS](docs/DECISIONS.md) içindedir. Faz 5 başlamadı; üretim SMTP/ilk Owner ve fiziksel cihaz kabulü ayrı kalır. Aşağıdaki eski faz durumları tarihçedir.

Yapılandırmasız çalıştırma ağsız debug önizlemesini korur. `.env.example` boş public config şablonudur. Yerel Supabase API adresi Android emülatöründe `http://10.0.2.2:55321`, host'ta `http://127.0.0.1:55321`; DB portu 55322'dir. Geçerli public config giriş/kayıt bağlantılarını açar. Rol önizlemeden alınmaz; `/account` gerçek oturum ve aktif DB profili ister. Oturum/PKCE verisi şifreli platform deposunda saklanır; Android yedekleme kapalıdır. Yeni parolalar en az 8 karakter, en çok 72 UTF-8 bayt olmalıdır. Yerel e-posta kodları Mailpit'te `http://127.0.0.1:55324` üzerinden görülür; kodları/logları paylaşmayın.

Sentetik seed parolaları bilinmez; manuel giriş için şifre depoya eklemeyin. Yerel Auth/SDK testi geçici rastgele parolayı yalnız bellekte kullanıp eski hash'leri geri yükleyen `supabase/tests/run-local-auth-check.ps1` ile yapılır. Komutlar ve sınırlar [Supabase README](supabase/README.md) içinde. İş ekranları halen geliştirme kabuğudur; Faz 5 modülü eklenmedi.

Tek satıcılı, tek depolu, Android öncelikli B2B gıda tedarik, saha satış, depo, dağıtım ve tahsilat projesi. **Faz 1–3 tamamlandı; Faz 3 kabulü migration + seed ve mevcut config/client/auth-state hazırlığı kapsamındadır.** 25 kaynak tablo ve 10 yardımcı tablo yerel DB'de doğrulandı. Gerçek giriş/RBAC izinleri ve sipariş/stok/tahsilat iş servisleri uygulanmadı. Açık hesap/işlem kararları [DECISIONS R-01–R-07](docs/DECISIONS.md), güncel kanıtlar [PROGRESS](docs/PROGRESS.md) içindedir. Faz 4 başlatılmadı.

Ana kaynak [Pekşen Gıda Teknik Tasarım ve Codex Geliştirme Planı v3](docs/Peksen_Gida_Teknik_Tasarim_v3.docx), 1 Ekim 2026 revizyonudur. Kaynak dosya korunur; tüm metin ve tablolar [SPEC](docs/SPEC.md) içinde bulunur. Formülü veya durum sınırı eksik konular karar kaydında açık tutulur.

## Belgeler

| Dosya | İçerik |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Çalışma düzeni, iş kuralları, mimari, komutlar ve işlem sınırları |
| [docs/SPEC.md](docs/SPEC.md) | Kaynağın 39 bölümü, tüm iş kuralları, yedi rol, ekranlar, veri modeli ve kapsam dışı maddeler |
| [docs/PLAN.md](docs/PLAN.md) | 17 faz, bağımlılıklar, kabul ölçütleri ve durumlar |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Kaynak kararları, T-01–T-11 teknik seçimleri ve A-01–A-14 açık soruları |
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
      auth/       # giriş arayüzü ve yalnız auth-state gözlemi
      preview/    # geliştirme rol/ekran envanteri
    shared/       # ortak önizleme ve durum bileşenleri
  test/           # 42 mevcut + 23 config/auth hazırlık testi
  integration_test/ # Android açılış ve önizleme testi
  supabase/       # config, ilk migration/seed, DB testleri ve README
  docs/
    Peksen_Gida_Teknik_Tasarim_v3.docx
    SPEC.md
    PLAN.md
    DECISIONS.md
    PROGRESS.md
    TESTING.md
```

Flutter iskeleti başlangıçta geçici klasörde üretilip gerekli dosyalar seçilerek depoya kopyalandı; proje yeniden oluşturulmadı. `integration_test/app_smoke_test.dart` giriş ve önizleme gezinmesini sınar. Faz 3'te iki migration, iki sıralı seed ve 19+97 pgTAP kontrolü yerel DB'de başarılıdır. 35 tabloda RLS açık ve istemci grant kapalıdır; izin veren policy yoktur. Tam hedef Flutter ağacı SPEC §28'de, [Supabase kurulum/şema envanteri ve sınırlar](supabase/README.md) ayrı kayıttadır.

## Ortam ve kurulum

**Son doğrulama — 4 Ekim onaylı şema görevi:** `flutter pub get`, `flutter analyze`, `flutter test --reporter expanded` (65/65), `flutter build apk --debug`, yerel `db reset`, identity 19/19 ve business 97/97 testlerinin tamamı çıkış **0**. Yeni kanıtlar `build/phase3-expanded-validation-20261004/` altında. Normal APK `build/app/outputs/flutter-apk/app-debug.apk`, **231.252.001 bayt**. Flutter kodu/paket/testleri korunur. Bu tur integration/görsel inceleme tekrar edilmedi. Aşağıdaki eski ortam/cihaz sonuçları geçmiş koşulara aittir; Docker engeli artık yoktur.

4 Ekim kullanıcı talebiyle Docker Desktop/Podman kurulmadan statik SQL incelemesi ve Flutter tekrar doğrulaması yapılır. DB kabul durumu **blocked by local Supabase runtime**: boş veritabanından migration, seed ve 19 DB testi çalıştırılamadı. Sonraki DB kontrolü için PC'de **Docker Desktop veya Podman** kurulup başlatılmalıdır; [TESTING](docs/TESTING.md) Docker'sız yapılabilen kontrolleri ve kurulum sonrası net komutları içerir. Statik incelemede SQL değişikliği gerektiren somut hata bulunmadı; SQL dosyaları korundu.

2 Ekim 2026 Faz 2 araç tabanı Flutter stable `3.47.6`, Dart `3.13.5`, Android SDK `37.0.0` ve Android Studio JBR `25.0.3` olarak kaydedildi. Git `2.55.0.windows.5`; `flutter doctor -v` sorun bildirmedi ve Android lisansları kabul edilmiş. Geçici Android uygulama kimliği `com.example.peksen_gida`, görünen ad `Pekşen Gıda`dır; ticari yayın kimliği henüz belirlenmedi.

`pubspec.yaml` doğrudan `flutter_riverpod: 3.4.3` ve `go_router: 18.0.2` sürümlerini tam olarak seçer; `flutter_localizations` ve geliştirme bağımlılığı `integration_test` Flutter SDK'dan gelir. Çözülen paket sürümleri `pubspec.lock` içinde korunur. Paket sürüm kaynakları: [flutter_riverpod sürümleri](https://pub.dev/packages/flutter_riverpod/versions) ve [go_router sürümleri](https://pub.dev/packages/go_router/versions).

Faz 2 sonunda `emulator-5554` üzerinde integration ve normal APK açılışı doğrulanmıştı. Faz 3'ün ilk taramasında Android yokken son taramada emulator-5554 bağlandı; güncel integration 1/1 geçti. Bu görevde görsel/fiziksel cihaz incelemesi yapılmadı. Supabase CLI `npx.cmd --yes supabase@2.119.0` ile kullanılabilir; Docker/Podman eksikliği yerel DB başlangıcını engelledi.

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

4 Ekim kullanıcı talebiyle yeniden çalıştırılan pub get ve analyze çıkış **0**, tam Flutter paketi **65/65 / çıkış 0**, debug build **çıkış 0**, emulator-5554 integration **1/1 / çıkış 0**. Önceki 42 test ve Faz 3'ün 23 testi değişmeden korunur. Bu koşunun normal APK'sı [peksen-gida-phase3-20261004-debug.apk](build/app/outputs/flutter-apk/peksen-gida-phase3-20261004-debug.apk), **231.252.001 bayt** olarak integration öncesi korundu. Standart `app-debug.apk` integration runner'a aittir. Önceki `peksen-gida-phase3-debug.apk` ve `peksen-gida-debug.apk` kopyaları korunur. Yeni kanıtlar `build/phase3-static-validation-20261004/`, önceki kayıtlar `build/phase3-validation/` ve `build/phase2-validation/` altındadır. Başarı APK varlığından değil komut bitişinden belirlenir. DB kabulü ve yeni görsel inceleme yapılmış sayılmaz.

## Faz 2 geliştirme önizlemesi

Giriş ekranı yalnız arayüzdür; kimlik doğrulama, hesap oluşturma veya sunucu oturumu açmaz. Debug sürümdeki geliştirme önizlemesi yedi rolün menüsünü ve SPEC §23'teki 70 ekran bağlantısını sunar. Bağlantılar açıklayıcı ekran kabuklarına gider; sipariş, fiyat, stok, cari, tahsilat ve teslimat işlemi yapmaz. Rol seçimi yalnız bellekteki önizleme durumudur, kullanıcı yetkisi değildir.

Yollar: `/` giriş, `/login` aynı girişe yönlenen alias, `/preview` önizleme, `/preview/roles/:roleId` rol menüsü, `/preview/roles/:roleId/:screenId` ekran kabuğu ve `/preview/states/loading`, `/preview/states/empty`, `/preview/states/error` ortak durumlarıdır. Doğrudan alt ekran açıldığında da geri sırası ekran → rol menüsü → önizleme → giriştir. Eşleşmeyen yol kayıtlı `/not-found` rotasına gider; geçersiz rol/ekran/durum da Türkçe bulunamadı görünümünü gösterir. Bu görünümde dönüş eylemi veya Android sistem geri olayı girişe götürür. Önizleme hem girişte hem router'da `kDebugMode` ile kapatıldığından profile/release sürümlerinde açılamaz. Türkçe yerelleştirme ve Material 3 yeşil/krem tema kullanılır.

`test/app_test.dart`, kaynak menü envanterini, önizleme erişim sınırını, 70 ekran bağlantısını, Android sistem geri davranışını, geçersiz yolları ve küçük ekranda büyük yazı/klavyeyle erişimi sınar. `integration_test/app_smoke_test.dart` Android üzerinde giriş → önizleme → Depo → ürün ekran kabuğu, geri dönüş ve boş liste akışını çalıştırır. Otomatik testler tüm cihazlarda görsel kabul anlamına gelmez; kapsam TESTING'de, sonuçlar PROGRESS'tedir.

Release imzalama henüz yapılandırılmadı; şablondaki debug anahtarıyla release imzalama kaldırıldı. İmzalı yayın hazırlığı Faz 17'nin görevidir.

## Ortam değişkenleri

`supabase_flutter: 2.18.0` eklendi. `.env.example`, `SUPABASE_URL` ile `SUPABASE_PUBLISHABLE_KEY` veya legacy `SUPABASE_ANON_KEY` için boş şablondur; iki anahtar birlikte kabul edilmez. Config yokken SDK başlatılmaz, önizleme ağsız çalışır. HTTPS gerekir; debug'da yalnız yerel host/127.0.0.1/::1/Android 10.0.2.2 adresleri HTTP kullanabilir. Service role/secret key mobil uygulamaya verilmez.

Geliştirme ortamı kullanılabilir olduğunda, mevcut `.env` korunarak şablon oluşturulabilir. Bu görevde gerçek değer girilmedi:

```powershell
if (-not (Test-Path -LiteralPath .env)) {
  Copy-Item -LiteralPath .env.example -Destination .env
}
```

```powershell
# Bağlı hedefi flutter devices ile seçin.
flutter run --dart-define-from-file=.env -d CIHAZ_ID
```

Dosya kendiliğinden yüklenmez veya asset olarak paketlenmez; `--dart-define-from-file` değerleri derlemeye aktarır. Bu değerler APK'dan okunabilir; yalnız public anahtar kullanılır. Config biçim kontrolü, sunucu bağlantısı veya RLS kanıtı değildir. SDK başlangıcı tek Riverpod provider'ında paylaşılır; auth repository yalnız session gözlemler. Giriş düğmesi kapalı kalır; parola gönderme/saklama, kalıcı session, refresh ve auth deep link bu fazda uygulanmaz. Debug durum bilgisi yükleme/hata halinde önizlemeyi kapatmaz.

Yerel DB komutları ve çalıştırılmayan kontroller [supabase/README.md](supabase/README.md) ve [TESTING](docs/TESTING.md) içindedir. Flutter başlangıcı [Supabase resmi SDK sözleşmesini](https://supabase.com/docs/reference/dart/initializing) izler; gerçek kimlik doğrulama Faz 4'ün işidir.

## Devam

Faz 3 migration/seed kabulü tamamlandı; sonraki faz için kullanıcı görevi beklenir. B-01–B-09 onayları ve T-12 şema karşılığı kayıtlıdır. Cari limit/varsayılan vade, kesin yuvarlama, tam durum/iade matrisi, çeyrek düzeltmeleri ve transaction/replay ayrıntıları R-01–R-07; oturum/üyelik konusu A-14'tedir. İlgili servis geliştirilmeden bu kararlar netleşmelidir. Faz 4'e geçilmedi. Son Flutter testleri önizlemeyi korur; yeni görsel/gerçek backend giriş kontrolü yapılmadı. Commit, push ve yayınlama yapılmaz.
