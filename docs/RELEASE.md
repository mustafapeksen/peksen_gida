# Android release hazırlığı

14 Ekim 2026 — Faz 17 yalnız hazırlık. Kalıcı paket kimliği, release anahtarı ve HTTPS kabul ortamı hazır değil. `com.example.peksen_gida` / `0.1.0+1` korunur; bunlar onaylanmış yayın kimliği/sürümü değildir. İmzalı release APK üretilmedi, dağıtım/yayın yapılmadı. Faz 16'nın yerel testi kabul edilse de bütün kabul ve önceki fiziksel/üretim açıkları kapanmadı.

## İmzalama ve yapılandırma

Gradle yalnız aşağıdaki süreç ortam değişkenlerini okur. Değerleri `.env`, `dart-define`, `gradle.properties`, `key.properties`, kaynak dosyası, komut satırı argümanı veya loga koymayın. CI kullanılırsa korumalı secret store'dan sürece aktarın; yerelde parola yöneticisi veya oturum içi güvenli giriş kullanın. Değerler bu belgede verilmez.

| Ortam değişkeni | Amaç |
| --- | --- |
| `PEKSEN_ANDROID_KEYSTORE` | Depo dışında mevcut anahtar dosyasının mutlak yolu |
| `PEKSEN_ANDROID_KEYSTORE_PASSWORD` | Keystore parolası |
| `PEKSEN_ANDROID_KEY_ALIAS` | Release anahtarının alias'ı |
| `PEKSEN_ANDROID_KEY_PASSWORD` | Anahtar parolası |

Eksik/boş imzalama yapılandırması `preReleaseBuild` aşamasında hata verir. Dosyanın mevcut, mutlak ve depo dışında olması gerekir. Bilinen debug alias/dosya adı reddedilir; bu ad kontrolü tek başına sertifika kimliği kanıtı değildir. Son APK'nın sertifika SHA-256 değeri aşağıdaki bağımsız kontrolle doğrulanır. Debug build imzalama değerleri olmadan çalışır; release hiçbir zaman debug imzasına veya imzasız dağıtım çıktısına düşmez. Gerçek anahtar bulunmadığından doğru parola/alias ile pozitif imzalama henüz denenmedi.

Anahtar sahipliği, saklama/yedek sorumlusu ve kalıcı paket kimliği dağıtım öncesinde onaylanmalıdır. Anahtar üretimi bu tur yapılmaz. Anahtarı, paroladan ayrı erişim kontrollü ve şifreli yedekleyin; kontrollü bir ortamda geri yükleme denemesi yapmadan “yedeklendi” kabul etmeyin. Keystore kaybını yeni bir anahtar üretmekle sessizce çözmeyin: mevcut kurulumların güncellenebilirliği imza kimliğine bağlıdır.

Public uygulama config'i `.env.example` şablonundan ignore edilen ayrı `.env.release` dosyasına hazırlanır. Yalnız HTTPS Supabase URL + publishable/anon istemci anahtarı; onaylanmış HTTPS harita stili ve varsa Firebase public Android kimlikleri kullanılır. Service role, sunucu kimliği veya imzalama parolası APK'ya giremez. Dart define değerleri APK'dan çıkarılabilir. Release LAN HTTP'yi kabul etmez; debug XML istisnaları release'e taşınmaz. Harita/Firebase eksikken bunların gerçek kabulü yapılmış sayılmaz.

## Üretimden önceki kapılar

1. Kalıcı applicationId ve sürüm onayı alınır. `pubspec.yaml` sürümü `versionName+versionCode` biçimindedir; aynı uygulamanın güncellemesinde versionCode artırılır. Bu tur artış yapılmadı.
2. HTTPS backend ve önceki migration/RLS'lerin hedef ortamda varlığı, Auth e-posta yapılandırması, Storage ve server worker/scheduler gereksinimleri doğrulanır. Bu belge cloud migration veya canlı veri reset yetkisi vermez.
3. Faz 16 açık kabuller; GPS, harita lisansı, özel kanıt UI ve Firebase/FCM gerçek cihaz sonuçları ayrı ayrı kapatılır. Hazır olmayan servisler için sahte kabul üretilmez.
4. İmza sahibinin korumalı ortamında aşağıdaki derleme çalıştırılır. `--verbose`, Gradle `--debug`, ortam dökümü veya secret içeren transcript kullanılmaz. Derleme logları paylaşılmadan denetlenir.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define-from-file=.env.release
# Başarılı komutun çıkış kodunu kaydedin; eski APK varlığını kanıt saymayın.
```

Beklenen çıktı `build/app/outputs/flutter-apk/app-release.apk`. Android SDK build-tools içindeki `apksigner.bat verify --verbose --print-certs` ile imza doğrulanır; sertifika SHA-256 parmak izi imza sahibinin önceden doğruladığı değerle eşleştirilir. SDK `aapt.exe dump badging` ile paket, versionCode/versionName ve `application-debuggable` yokluğu kontrol edilir. Paketlenmiş manifestte `usesCleartextTraffic=false`, `allowBackup=false`, tracking service `exported=false` ve debug ağ kaynağının yokluğu ayrıca kontrol edilir. Build başarılı olsa bile bu kontroller yapılmadan artefakt dağıtıma hazır sayılmaz.

APK'nın SHA-256 özeti, boyutu, commit, Flutter/Dart sürümü, paket/sürüm, sertifika parmak izi ve test kabul listesi erişim kontrollü release kaydında tutulur. APK/keystore/yerel config Git'e eklenmez. CI secret değerleri kayda alınmaz. Önceki APK aynı imzayla güncellenebilir kopya olarak tutulur; daha düşük versionCode ile downgrade zorlanmaz, geri dönüş gerekirse kontrollü ileri sürüm hazırlanır.

## Cihaz kurulum ve veri koruma

- Önce doğru cihaz `adb devices` ile seçilir; başka açık proje veya kişisel uygulamaya dokunulmaz.
- Aynı paket ve aynı imza için `adb -s CIHAZ_ID install -r APK_YOLU` kullanılır. İmza uyuşmazlığında durulur; `uninstall`, `pm clear` veya downgrade ile aşılmaz. Geliştirme debug imzası ile gerçek release imzası farklıdır; mevcut debug kurulumu üstüne release zorlanmaz. Ayrı kabul cihazı/profili ya da ayrıca onaylı veri geçişi gerekir.
- Integration testlerde `flutter test integration_test/app_smoke_test.dart -d CIHAZ_ID --no-uninstall` kullanılır. Öncesinde o cihazın aynı imzalı APK'sı saklanır ve sonunda `adb install -r` ile geri yüklenir. Bu debug smoke, release modu kabulü değildir.
- APK kopyası kullanıcı verisi/Android Keystore yedeği değildir. Android backup mevcut güvenlik ayarlarıyla kapalı kalır. Şifreli oturum başka cihaza kopyalanmaz; yeni cihazda tekrar giriş yapılır. Belirsiz gönderim/yerel taslak bulunabilecek cihaz kaldırılmadan önce mevcut uygulama akışıyla işlemler kontrol edilir.

Release cihaz kontrol listesi: temiz kurulum ve aynı imzayla güncelleme; gerçek giriş/OTP ve yeniden açılışta oturum; Customer/Sales sipariş ve yetki sınırı; bildirim izin/token/ön plan/arka plan/kapalı uygulama hedefi; GPS izin, ekran kapalı takip ve durdurma; logout; dar ekran/klavye/geri tuşu. Uygun koşulları bulunmayan maddeler **yapılmadı** kaydedilir. Bu tur bu liste tamamlanmadı.

## Backend ve kanıt yedekleri

İş kayıtlarının esas kaynağı backend'dir; telefon APK'sı veritabanını veya Storage nesnelerini içermez. Yetkili işletim sorumlusu DB, Auth'a ait gerekli veriler, özel Storage kanıt nesneleri ve runtime yapılandırmasını sağlayıcının desteklediği yöntemlerle ayrı yedekler. DB dump tek başına dosya nesnelerinin yedeği değildir. Yedekler kişisel/ticari veri içerebilir; şifreli ve erişim kontrollü tutulur, Git/log/sohbete konmaz. Saklama süresi/RPO/RTO bu tur uydurulmaz; işletim kararı bekler.

Geri yükleme önce ayrı izole ortamda; migration sürümü, kayıt sayıları, rol/RLS, Auth oturumu ve özel dosya erişimiyle sınanır. Canlı veriyi ezme veya silme bu hazırlığın parçası değildir. Yerel `supabase db reset --local` yalnız sentetik geliştirme verisi içindir; yedek alma/geri yükleme yöntemi değildir. Üretim backup/restore tatbikatı yapılmadı.

Kaynaklar: [Flutter Android release ve imzalama](https://docs.flutter.dev/deployment/android), [Android imzalama ve güncelleme kimliği](https://developer.android.com/studio/publish/app-signing), [Android sürümleme](https://developer.android.com/studio/publish/versioning). Bunlar teknik kurulum referanslarıdır; projenin imza ve işletim kararlarının yerine geçmez.
