# Pekşen Gıda — Karar kaydı

## F16-01 — 13–14 Ekim 2026 uçtan uca test ve güvenlik incelemesi

Kullanıcı `a354f39` Faz 15 yerel kapsamını kabul etti. Kapsam yalnız PLAN Faz 16: yedi rol senaryosu, fiyat/stok/tahsilat yarışları, RLS ve dosya erişimi; yeni formül veya iş geçişi yoktur. Telefon bağlama sorusuna kullanıcı fiziksel cihazı bağlayacağını belirtti; `R5CW30NE8ZV` görüldü. Test APK'sından önce kurulu APK saklandı ve sonrasında geri yüklendi; SHA-256 eşleşmesi doğrulandı. Ancak bu koşularda Flutter'ın varsayılan test-sonu uninstall davranışı kapatılmadığından **yerel uygulama verisi/oturum korunamadı**: kurulum tarihi yenilendi, `shared_prefs` yok. APK yedeği veri/Android Keystore yedeği değildir; yeniden giriş gerekir. Bundan sonraki fiziksel integration komutları `--no-uninstall` kullanmalı ve aynı imzalı APK `adb install -r` ile geri yüklenmelidir. Yerel DB resetleri ayrıca sentetik fixture'ları/oturumları yeniler.

Yedi rol gerçek Auth/PostgREST zinciri, API dışından status/finans yazma kestirmesi olmadan mevcut servisleri kullanır. Android ekran senaryoları mock repository ile ayrı çalışır; bunlar gerçek Firebase, GPS veya dosya seçici kabulü değildir. Yerel SQL testleri, önceki gerçek Storage erişim kanıtı ve kaynak/config incelemesi birbirinden ayrı kaydedilir. Fiyat yarışında test yardımcısının Docker metin taşıması UTF-8 olarak sabitlendi; iş kodu/fiyat sözleşmesi değişmedi. Sales testinde koşulsuz ensureVisible yerine klavye açıkken gerçek hit-test ve sınırlı kaydırma kullanıldı; fiyat yeniden onayı/gönderim/geri gezinme doğrulamaları korunur.

**Açık kabul:** PLAN'ın tüm ilgili kabullerin kapanması önkoşulu halen karşılanmıyor: önceki uzun süreli GPS/üretim harita/assistant devri/otomatik fiziksel bitiş, fiziksel kanıt seçici/görseli ve gerçek Firebase/FCM kabulleri ayrı açık kalır. Failed/returned, stok telafisi, gerçek kalem revizyonu, tahsilat düzeltme/iptal, otomatik bordro/ödeme ve ayar yazma kapsamı genişletilmez. Yerel testlerin geçmesi üretim güvenlik sertifikası veya bu açık maddelerin kabulü değildir. Faz 17 başlatılmaz.

## F15-01 — 13 Ekim 2026 onaylı Manager/Owner raporları

- Kullanıcı Faz 14 yerel kapsamını `4a61a11` ile kabul edip yalnız PLAN Faz 15'i açtı. Manager/Owner rapor okur; diğer rollerin rapor erişimi yoktur.
- Başlangıç/bitiş günleri dahil Europe/Istanbul aralığı kullanılır. Siparişler oluşturulma tarihine göre seçilip **mevcut** durumlarıyla sayılır. Teslimat adedi ve sipariş toplamı, mevcut kesinleşme olgusunun tarihine göre raporlanır. Bunlar kâr/ciro veya tarihsel durum rekonstrüksiyonu değildir.
- Tahsilatlar tahsilat tarihine göre, mevcut `recorded` ve `verified` durumları ayrı gösterilerek toplanır. Bu iki grup birbirini dışlar; doğrulama tarihi kullanılmaz. Düzeltme/iptal/net muhasebe raporu açılmaz.
- Stok fiziksel/rezerve/kullanılabilir taban miktarlarıyla **anlık** gösterilir. Farklı ürün/birim miktarları birbirine eklenmez. Driver puanları **tüm zamanların** adet/aritmetik ortalama/1–5 dağılımıdır; otomatik performans/prim formülü yoktur.
- Yalnız Owner çalışan+ay başına tek manuel maaş/prim kaydı oluşturur veya gerekçeyle düzeltir. Tutarlar negatif olmayan integer kuruştur. Değişiklik geçmişi ve audit atomiktir; aynı istek tekrarı ikinci kayıt üretmez. Eski revision gönderimi çakışma olarak reddedilir. Kayıt silme, otomatik bordro/prim, ödeme veya muhasebe işlemi yoktur. Mevcut eski kayıtlar korunur; önceki değişiklik geçmişi uydurulmaz.
- Owner audit ekranı yalnız aktör/olay/kayıt/zaman projection'ını okur; ham JSON ve hassas içerik göstermez. Yeni sistem ayarı düzenleme yetkisi açılmaz. Mevcut Owner ham tablo SELECT politikaları korunur; ham yazma grant'i açılmaz.
- Teknik sınırlar: tarih filtreli tek rapor çağrısı aynı veritabanı snapshot'ından hesaplanır; maaş düzeltmelerinde revision kontrolü, aktör/anahtar/payload tekilliği ve kilit kullanılır. Sonucu belirsiz maaş isteği aktör/proje ayrımlı şifreli saklanır; yeniden gönderim kullanıcının açık eylemidir, offline işlem kuyruğu değildir.

Faz 12 uzun süreli/izin kaldırma/otomatik fiziksel bitiş/üretim harita/assistant devri; Faz 13 fiziksel kanıt görseli ve saklama/failed-returned/telafi; Faz 14 gerçek Firebase/push kabulü ayrı açık kalır. Gerçek revizyon, tahsilat düzeltme/iptal ve açık çeyrek kuralları uygulanmaz. Faz 16 açılmaz.

## F14-01 — 13 Ekim 2026 onaylı bildirim sınırları

Kullanıcı alıcı ve kampanya kararlarını onayladı. PLAN Faz 14 FCM notifications kapsamıdır; Faz 15 açılmaz. Firebase projesi henüz yoktur: yerel altyapı uygulanır, gerçek FCM ve fiziksel Android kabulü açık kalır.

- SPEC §22 yalnız mevcut olay kaynaklarından üretilir. Sales aktif atanmış müşteri; Driver açık atanmış sefer/durak; Accounting mevcut F4/F10 atanmış müşteri projection sınırında kalır. Accounting için yeni bireysel atama modeli eklenmedi; mevcut şemada müşterinin Sales atamasının bulunması bu kapsamı belirler. Manager olaylarını Owner da alır. Yeni rol veya iş geçişi yoktur.
- Push metni geneldir; data yalnız bildirim ve alıcı kimliğidir. Sipariş/fiyat/konum/kanıt veya key taşınmaz. Açılışta oturum alıcısı, canlı DB yetkisi ve istemci iç-rota izin listesi tekrar denetlenir. Geçmiş ve okundu RPC'leri yalnız sahibine açıktır; eski Owner genel notifications okuması da bu tablo için daraltıldı. Diğer Owner/RLS yetkileri değişmedi.
- Manager/Owner mevcut aktif ürün, açıkça seçilmiş aktif müşteriler ve gerekçe ile duyuru oluşturur. Fiyat/iskonto değişmez; normal fiyat değişimi olay üretmez. Aynı aktör/anahtar/payload tek kampanyadır; farklı payload reddedilir. Sonucu belirsiz istek aktör/proje ayrımlı şifreli saklanır ve açık tekrar edilir; offline kampanya kuyruğu yoktur.
- Bildirim koleksiyonu iş transaction'ından sonra ayrı sunucu worker'ında çalışır. History, alternatif, atama ve kampanya kayıtları tekrar okunabilir; `(event_key,user_id)` ve `(notification_id,device_id)` tekildir. Migration öncesi olaylar geriye dönük yayınlanmaz. GPS izin/GPS-kapalı olayında koordinatsız bir olgu kaydedilir; aynı hata durumu yinelenmez, toparlanma sonrası yeni hata yeni olgudur. Bu yardımcı kayıt başarısız olursa tracking işlemi geri alınmaz; o GPS bildirimi kaybolabilir. Sipariş/stok/ödeme transaction'larına bildirim bağımlılığı eklenmedi.
- Cihaz tokenı private/RLS kapalı tabloda canlı Auth session'a bağlıdır. Kayıt açık izin eylemiyle yapılır; yenileme, çıkış ve paylaşılan cihazda kullanıcı değişimi ele alınır. Sender lease alırken aktif profil, güncel atama ve session yeniden kontrol edilir. Yeni cihazlara eski bildirimler push olarak doldurulmaz; kendi geçmişi okunabilir.
- Teknik tekrar sözleşmesi: `SKIP LOCKED`, iki dakikalık lease, altı deneme, üstel gecikme; invalid token temizliği, eski lease ACK reddi. Worker sınırlı grubu paralel gönderir. HTTP başarıdan sonra ACK kaybolursa tekrar mümkündür: FCM için exactly-once iddiası yoktur. Aynı Android tag/bildirim kimliği tekrarın aynı bildirimi hedeflemesini sağlar. Başarısız işler teşhis için korunur; yeni ticari durum üretmez.
- Firebase Android public config Dart define ve native string kaynaklarına birlikte aktarılır; boşsa FCM kapalı, preview/auth/inbox kullanılabilir. Sunucu kimliği yalnız Edge çalışma ortamındaki `FIREBASE_SERVICE_ACCOUNT_JSON` ile verilir; Flutter/env örneğine veya depoya konmaz. HTTP v1 kısa ömürlü OAuth kullanılır. Yerel worker CLI bellekte aldığı servis yetkisiyle çağrılır; mobil istemci worker çalıştıramaz.

**Hedef kayıt yönlendirmesi:** Customer/Sales sipariş bildirimi mevcut sipariş ekranını `order` UUID parametresiyle açar; yalnız hedef kart gösterilir ve açılır. Sales müşteri bağlamı korunur. Warehouse aynı parametreyle doğrudan Toplama sekmesindeki hedef kayda gider. Parametre erişim vermez; mevcut repository/RPC/RLS tekrar okur. Hedef kaybolmuşsa diğer kayıtlar gösterilmez, erişim/bulunamadı mesajı çıkar. İzin listesi dış URL, fragment, ek/tekrarlı query ve geçersiz UUID'yi reddeder. Alternatif ve ürün doğrudan kayda, diğer olaylar mevcut yetkili takip/sefer/teslimat/cari ekranına gider. İşlem sözleşmeleri değişmedi.

**Açık kabul:** Firebase proje/paket eşleşmesi, runtime sunucu kimliği ve güvenilir sunucu zamanlayıcısının üretim kurulumu; gerçek cihaz izin/token yenileme/ön plan/arka plan/kapalı uygulama push ve tıklama kabulü; üretim gönderim izleme/başarısız iş işletimi. Yerel testler bunları geçmiş saymaz. Faz 12/13 açık kabulleri, fiyatlama, teslimat veya stok kuralları bu fazda değiştirilmedi.

## F13-01 — 12 Ekim 2026 onaylı teslimat ve puanlama

**13 Ekim kapanışı:** Bu onayların yerel kapsamı 76 yeni DB assertion, 3 gerçek eşzamanlılık, gerçek Storage SDK ve Android smoke ile doğrulandı. Tam Flutter 243/243 ve eski 1.071 DB assertion korunur. Son komut/çıkışlar TESTING'dedir. Faz 14 açılmadı. Kanıt saklama/silme süresi ile failed/returned telafi sözleşmesi açık kalır; fiziksel dosya seçici/kanıt görseli ve F12 açık kabulleri bu testlerden türetilmez.

- PLAN Faz 13: çift onay, uyuşmazlık, yönetici çözümü, tek puan ve kontrollü kanıt.
- Açık sefer/durağa atanmış primary/assistant Driver `out_for_delivery → delivery_pending_confirmation`; kendi Customer kullanıcısı `Teslim aldım → delivered` veya gerekçeli `Teslim almadım → delivery_disputed` yapar.
- Manager/Owner yalnız bu iki bekleyen durumda gerekçeyle `delivered` çözümü verir. Kesinleşmede durak kapanır; teslimat olgusu, history/audit aynı transaction'dadır. Tek Driver olgusu borç üretmez; mevcut F10 hesapları kullanılır.
- **Ek kullanıcı kararı:** F10 açık-durak tahsilat sınırı korunur. Durak kapanınca Driver tahsilatı kapanır; Sales mevcut aktif atanmış müşteri sınırında tahsilata devam eder. Finance scope genişletilmez.
- Puan hedefi teslimat onayını fiilen başlatan primary/assistant Driver'dır. Yalnız kendi Customer kullanıcısı, kesinleşmiş delivered siparişte bir kez 1–5 puan; isteğe bağlı yorum ve geç geldi/davranış/ürün eksikliği/hasar/diğer nedenleri. Değiştirme/silme ve Driver puan okuması kapalı.
- Kanıt yalnız uyuşmazlıkta atanmış Driver için isteğe bağlı JPEG/PNG, en çok 5 MB; private Storage. Yalnız yükleyen Driver ve Manager/Owner okur. Customer/diğer roller ve dosya değiştirme/silme kapalı. Uygulama authenticated download kullanır. Saklama süresi/otomatik temizleme açık karardır; süre uydurulmaz.
- Failed/returned, gerçek revizyon, stok telafisi, tahsilat düzeltme/iptal ve çeyrek kuralları uygulanmaz. Faz 14 açılmaz. F12 uzun süreli GPS, izin/GPS kaldırma, fiziksel otomatik durma, üretim harita lisansı ve assistant kaynak devri açık kalır.
- Teknik: aynı aktör+anahtar+payload cevabı tekrar döner; farklı payload/aktör reddedilir. Kanıt rezervasyonu ile Storage upload ayrı işlemlerdir; dosya gönderilmediyse boş rezervasyon kanıt olarak gösterilmez. Offline kritik işlem kuyruğu yok; belirsiz RPC sonucu şifreli, aktör/proje ayrımlı istekle açık tekrar edilir.
- Dosya seçimi [Flutter file_selector](https://pub.dev/packages/file_selector), özel bucket sınırları [Supabase Storage](https://supabase.com/docs/guides/storage/buckets/fundamentals) sözleşmesini izler.

## F12-01 — 11 Ekim 2026 onayı; 12 Ekim doğrulama devamı

**12 Ekim fiziksel kabul hazırlığı:** Kullanıcı yerel fixture ile aktif primary sefer hazırlanmasını onayladı. Sabit yerel Docker DB'de yalnız mevcut authenticated Warehouse/Manager RPC'leri kullanıldı; telefondaki Driver gerçek oturumuyla yola çıkıldı. Auth/parola/seed/migration veya üretim yetkileri değiştirilmedi. Temel fiziksel izin/son nokta, 40 saniye ekran kapalı ve 25 saniye LAN kesintisi geçti; uzun süreli ve teslimat sonu kabulü bunlardan türetilmez. Test bitiminde kullanıcı durdurma akışıyla konum temizlenip servis kapatıldı; test seferi ve Driver oturumu korunur. Ayrıntılı kanıt TESTING başındadır. Yeni ticari karar yok.

**12 Ekim Driver UI açıklaması:** GPS izni sayfa açılışında değil, uygun primary sefer satırındaki **Konum paylaşımını başlat** eyleminde istenir. Workspace'in mevcut in_progress + açık out_for_delivery durak şartı korunur; yalnız planned atama paylaşım açmaz. Sefersiz/assistant açıklamaları yeni yetki veya durum geçişi değildir. İzin reddi yalnız takip sorunu üretir, sipariş/seferi değiştirmez. Yerel kabul seferi mevcut toplama→atama→yükleme→yola çıkış ekranlarıyla hazırlanır; seed tamamlanmış seferi aktifmiş gibi gösterilmez. Yeni ticari karar eklenmedi.

**12 Ekim LAN düzeltmesi:** Fiziksel yerel kabul için yalnız debug config'te literal RFC1918 HTTP adresleri kabul edilir. Android native HTTP istisnası debug kaynaklarında 192.168.0.100/emülatör/loopback ile sınırlıdır; global HTTP veya release/profile istisnası yoktur. IP değişikliği debug XML'e de uygulanır. `.env` build-time'dır; endpoint değişikliğinde tam run ve endpoint'e ayrılmış yeni oturum gerekir. Bu, üretim bağlantı politikasını veya rol yetkilerini değiştirmez. Seed parolaları bilinmez; kullanıcı mevcut e-posta kodlu kurtarma akışıyla kendi parolasını belirler. Kalıcı assistant ihtiyacı mevcut Driver daveti/sefer ataması ile çözülür, sekizinci rol veya yeni seed eklenmez.

- Faz 12 yalnız arka plan GPS, Realtime ve MapLibre'dır. Konumu yalnız aktif seferin primary Driver'ı gönderir; assistant kendi seferini okur. Assistant'a kaynak devri açık karardır.
- Hedef ölçüm aralığı 15 saniye; sefer başına yalnız son nokta; rota geçmişi ve kalıcı offline kuyruk yoktur. 60 saniye üzerindeki ölçüm eski olarak gösterilir. Yeniden bağlantıda yalnız yeni ölçüm gönderilir.
- Customer yalnız kendi açık/tamamlanmamış durağındaki `out_for_delivery` siparişi boyunca görür. Manager/Owner aktif seferleri, Driver kendi seferini görür; Sales/Warehouse/Accounting takip erişimi almaz. Sefer bitince veya paylaşılabilir sipariş kalmayınca son nokta silinir.
- İzin reddi/GPS kapanması sipariş durumunu değiştirmez; takip sorunu görünür. Servis Driver'ın görünür ekrandaki açık eylemiyle başlar, Android bildirimi gösterir. Process/task kapanınca otomatik yeniden başlatılmaz; kullanıcı yeniden başlatır. Bildirim izni de reddedilirse servis açılmaz. Bunlar iş durumunu değiştirmeyen teknik güvenlik sınırlarıdır.
- Aynı primary hesabın ikinci cihazından açık başlatma yeni, yalnız bellekte tutulan publisher kimliği üretir; önceki cihazın yazması reddedilir. Assistant'a devir değildir. Sunucu 60 saniyeden eski / 15 saniyeden fazla gelecekteki örnekleri kabul etmez; saat sapması takip hatası olarak ele alınır.
- Realtime özel kullanıcı kanalına yalnız `{changed:true}` bildirir; koordinat/rota/sipariş kimliği yayınlanmaz. Her okumada güncel RPC yetkisi uygulanır; bağlantı/hata durumunda eski harita gizlenir. Periyodik yenileme yedektir. Eski `driver_locations` geçmiş tablosuna yazılmaz; yeni private tabloda yalnız son nokta vardır.
- `MAP_STYLE_URL` HTTPS ve yapılandırılabilir; yalnız debug boş yapılandırmada MapLibre demo stili kullanılır. Üretim sağlayıcısı, lisansı/kotası ve gerçek Android ekran-kapalı kabulü açık kalır. Demo haritası üretim sağlayıcı kabulü değildir.
- Faz 13 teslimat kesinleştirme; cari/çeyrek, telafi, revizyon, tahsilat düzeltme/iptal, başlamış seferde ekip değişimi bu çalışmaya eklenmez.

Teknik uygulama: Realtime servis hatası iş transaction'larını geri almaz; konum silme hataları bastırılmaz. Kanal alıcısı haritaya girmeden sefer ekranından da kaydedilir. Oturum değişikliği uygulama kapsamında dinlenir ve native paylaşım durdurulur; oturum yokken otomatik provider retry kapalıdır. Bunlar yeni sipariş/ödeme/teslimat/stok kuralı getirmez.

Açık kabul: gerçek cihazda ekran kapalı takip, izin reddi/sonradan kaldırma, GPS kapanması, ağ kesintisi/geri gelmesi, logout/task kapanması ve sefer sonunda servis durması. Otomatik emülatör testi bunların yerine geçmez. Üretim stil sağlayıcısı/lisansı/kotası ve assistant GPS devri ayrıca karara bağlanacaktır. Android servis yaklaşımı [Android location foreground service](https://developer.android.com/develop/background-work/services/fgs/service-types#location), harita bağımlılığı [MapLibre Flutter](https://maplibre.org/flutter-maplibre-gl/) sözleşmesine dayanır.

### F11-01 — Onaylı araç, sefer ve atama sözleşmesi (11 Ekim 2026)

**Kapanış:** Onaylı yerel kapsam tamamlandı. Son kanıt: 79 yeni + 850 mevcut DB assertion, altı iki-bağlantılı yarış, 205 Flutter testi ve son daraltma sonrası ilgili 14 test, analyze/debug build ve emulator-5554 üzerinde 9 Android testi; çıkışlar 0. Ayrıntılı komut ve manuel kabul sınırları PROGRESS/TESTING başındadır. Bu kapanış yeni yetki/iş kuralı eklemez.

Kullanıcı Faz 10'u commit edilmiş kabul etti (`348e937`) ve üç Faz 11 sorusunun tamamını onayladı. Bu kayıt önceki “Faz 11 kapalı” ifadelerinden önce gelir. Kapsam PLAN faz 11: araç/sefer/durak ataması, primary/assistant erişimi, yükleme bağlantısı ve durak sırası. Faz 12 açılmaz.

- **Yetki ve kaynaklar:** Araç oluşturma/düzenleme/pasifleştirme, sefer oluşturma ve ekip/sipariş atama yalnız aktif Manager/Owner. Primary ve assistant aynı `driver` rolüdür; kendi seferlerini okuyup açık/tamamlanmamış durak sırasını değiştirir. Warehouse mevcut yükleme servisini kullanır; araç/sefer yönetimi veya fiyat yetkisi kazanmaz. Aynı araç veya driver, primary/assistant ayrımı olmadan, aynı anda bir açık seferdedir. Açık sefer aracı pasifleştirilemez. Ham yazma, anonim erişim ve diğer rollerin dispatch RPC erişimi kapalıdır.
- **Atama:** Yalnız tüm kalemleri toplanmış `picked` sipariş, planlanmış sefere atanır; sipariş `picked` kalır. Atama `assigned` sipariş geçişi üretmez. Yükleme öncesi yeniden atama Manager/Owner + zorunlu gerekçe ister; eski durak kapanır, yeni durak `previous_stop_id` ile geçmişe bağlanır. Kalem/fiyat/toplam/snapshot/stok değişmez. Loaded ve sonrasında yeniden atama yoktur; aynı sipariş iki açık durakta bulunamaz.
- **Yaşam döngüsü:** `planned → in_progress → completed`. Boş olmayan seferde bütün açık siparişler `loaded` ise atanmış iki Driver'dan biri atomik yola çıkışı başlatır; hepsi `out_for_delivery` olur. Manager/Owner Driver adına yola çıkamaz. Başlamamış ve açık durağı olmayan sefer `cancelled` olabilir; sahte başlangıç zamanı yazılmaz. Manager/Owner yalnız başlamış seferin bütün durakları kapalı ve bağlı siparişleri delivered/cancelled/rejected olduğunda seferi tamamlar. Kapatma teslimat onayı, durak kapatma, sipariş iptali veya stok işlemi yapmaz. Bunlar sonraki teslimat fazının olgularını gerektirir.
- **Sıra:** İstek açık/tamamlanmamış durakların tam permütasyonudur; eksik/tekrarlı/yabancı durak reddedilir. Tamamlanmış ve kapalı durakların sırası/geçmişi değişmez. Ekran açıkken 5 saniyelik RPC yenilemesi diğer kullanıcıların değişikliklerini getirir; bu PostgreSQL Realtime/GPS entegrasyonu değildir. GPS, konum izni ve Faz 12 altyapısı eklenmedi.
- **Tekrar, kilit ve audit:** Aktör/ekip Auth+profil satırları UUID sırasında paylaşım kilidi alır; bu hesap pasifleştirme/dönüşümüyle yarışmayı önler. Dispatch kaynak işlemleri tek transaction advisory kilidiyle serileştirilir; müşteri/sipariş kilitleri sefer/duraktan önce gelir ve Faz 9 yükleme/Faz 10 tahsilat kilit sırası korunur. Güncel rol/Driver ataması replay öncesi kontrol edilir. Aynı aktör/key/payload aynı sonucu verir; farklı payload reddedilir. Receipt, atama, durum/history ve `dispatch_changed` audit tek transaction'dadır. Çok siparişli yola çıkışta history anahtarı her sipariş olayı için ayrıdır; ortak istek anahtarı audit ve receipt ile ilişkilidir. Sunucu sonucu alınamayan istek proje/aktöre özel şifreli saklanır, yeni işlemden önce aynı payload/key ile çözülür. Offline işlem yetkisi değildir.
- **Tarihsel uyumluluk:** Yeni seferler `dispatch_managed=true` ile açık yaşam döngüsü constraint'ine tabidir. Eski serbest metinli sefer durumları tahmin edilmez veya dönüştürülmez; geçmiş okunur, yeni yaşam döngüsü RPC'si bu kayıtları değiştirmez. Yeni sefer ekibi oluştururken atanır; mevcut seferde driver değiştirme servisi yoktur. Atamasız planı iptal edip doğru ekiple yeni sefer oluşturmak mümkündür. Araç değişimi mevcut Faz 3 geçmiş korumasıyla yeni sefer/atama üzerinden temsil edilir. Önceki migration, seed ve test dosyaları korunur.

**Açık/kapsam dışı:** Başlamış/yüklenmiş seferde ekip değişiminin tarihçe ve yetki etkileri; eski seferleri yeni yaşam döngüsüne taşıma; durak tamamlama/teslimat kanıtı/uyuşmazlık çözümü Faz 11'de açılmaz. Mevcut çalışan rol yönetimi değiştirilmedi; takımın rolü sonradan değişmişse yeni atama/yola çıkış reddedilir. Açık durağı olmayan başlamamış planın iptali veya tüm kapanış şartlarını sağlayan seferin tamamlanması bu yüzden engellenmez; eski driver'a yetki verilmez. Gerçek kalem revizyonu, picking sonrası stok telafisi, stok yetersizliği onayı, tahsilat düzeltme/iptal etkileri, çeyrek/iskonto ve GPS kapsam dışıdır. F10 cari/exposure formülü ve yetkileri değişmedi. Otomatik Android fixture testi manuel görsel veya gerçek backend Android uçtan uca kabul değildir.


### F10-01 — Onaylı tahsilat, cari limit ve cari aşım kararı (11 Ekim 2026)

**Kapanış teyidi:** Onaylı Faz 10 yerel kapsamı tamamlandı. Mevcut bitiş logları 191 Flutter, 98 yeni + 752 mevcut DB assertion, üç eşzamanlılık senaryosu, debug build ve emulator-5554 integration **7/7**, çıkış **0** sonucunu doğrular. Bu kapanış yeni iş kuralı/yetki eklemez; aşağıdaki açık kapsam ve manuel kabul sınırları korunur. Ayrıntılar PROGRESS/TESTING başındadır.

Kullanıcı Faz 9'u commit edilmiş/kabul edilmiş saydı (`a11d662`) ve dört Faz 10 kararını açıkça onayladı. Bu kayıt eski “cari/exposure uygulanmaz”, “Accounting hiçbir yazma işlemi yapamaz” ve “Faz 10'a geçme” tarihsel ifadelerinden önce gelir. Accounting için tek yeni yazma yetkisi aşağıdaki denetlenen doğrulama RPC'sidir; ham tablo yazması açılmaz.

- **Tahsilat:** Yalnız `delivered` ve immutable müşteri+driver onayı veya yetkili finalizing resolution kaydı bulunan sipariş. Tek driver kaydı veya yalnız delivered statusu yeterli değildir. Finalizasyon olayı oluşturma/teslimat geçişleri bu fazda yoktur. Sales yalnız aktif atanmış müşteri; creator tek başına yetki değildir. Driver yalnız kapanmamış durak ve bitmemiş seferde mevcut primary/assistant atamasıyla kayıt açar. Nakit/POS, pozitif integer kuruş; fiili tahsil eden Auth aktörüdür. Borç = sipariş toplamı − recorded/verified tahsilat toplamı. Kısmi ödeme serbest, fazla ödeme reddedilir; doğrulama borcu ikinci kez azaltmaz. Manager/Owner'a tahsil etme veya Accounting yerine doğrulama yetkisi eklenmedi.
- **Accounting:** F4-04 atanmışlık sözleşmesi korunur: müşterinin `assigned_sales_operator_id` alanı doludur; ayrıca Accounting-personel atama modeli yoktur. Yalnız aktif ve atanmış müşterinin recorded tahsilatını doğrulayabilir; aktör/zaman/audit kaydedilir. Yeni açık alan listesi sipariş toplamı, kalan borç, vade ve tahsilat olgularıdır; kalem fiyatları/iskonto, maaş, audit, müşteri yönetimi açılmaz. Eski firma/iletişim/vergi/limit/vade projection'ı değişmez. Ham yazma ve anonim erişim kapalıdır.
- **Limit:** Yalnız Manager/Owner, müşteri başına sıfır veya pozitif integer kuruş tutarı ve zorunlu gerekçeyle girer. Eski/yeni limit ve aktör audit'tedir. Otomatik limit formülü ve limit silme servisi yoktur. `NULL` limit eski Faz 6 davranışını korur: `not_evaluated` uyarısı; sıfır veya sınırsız limit varsayılmaz. Açıkça girilen **0 gerçek limit** sayılır. Vade sırası mevcut tarih/snapshot → müşteri günü → açık `default_payment_due_days` ayarıdır; hiçbiri yoksa veya teslim zamanı yoksa tarih üretilmez. Tahsilat mevcut vade/delivery snapshotını değiştirmez; eksik snapshot için workspace yalnız güncel açık ayarlardan hesaplanan tarihi gösterir.
- **Exposure:** `delivered` kesinleşmiş siparişlerin kalan borcu + `submitted/picking/picked/assigned/loaded/out_for_delivery/delivery_pending_confirmation/delivery_disputed` tutarları, sipariş başına **bir kez**. `draft/pending_approval/rejected/cancelled` dışarıdadır. Aktif durumdaki ödeme gibi çelişkili eski veri; payment adjustment; disputed/cancelled tahsilat; disputed ödeme durumu veya kanıtsız delivered kayıt varsa sonuç **hesaplanamadı/inceleme gerekli** olur. Net düzeltme etkisi uydurulmaz; buna bağlı yeni tahsilat/doğrulama ve tanımlı limitli checkout reddedilir.
- **Checkout:** Müşteri kilidi altında mevcut exposure + yeni sipariş toplamı limite karşı kontrol edilir; eşitlik limit içidir. Fiyat/dönüşüm/stok farkında sıfır yazma ve açık yeniden onay sözleşmesi aynıdır. Yeterli stok + cari aşım `pending_approval`, sıfır rezervasyon ve `approval_kind=credit` üretir. Stok yetersizliğinde `approval_kind=stock` önceliklidir; cari uyarı da olsa kredi karar RPC'si açılamaz. Eski approval satırları `legacy` kalır; metinlerinden sebep tahmin edilmez. Gönderim müşteri borcu veya tahsilat oluşturmaz.
- **Cari karar:** Yalnız Manager/Owner; credit nedenli pending başvuru + pending_approval sipariş. Gerekçe/aktör/zaman zorunlu. Onay fiyat/kalemleri yeniden hesaplamaz; kayıtlı exact dönüşümler üzerinden aynı ürünün tüm birimlerini toplar ve stoğu kilitli yeniden kontrol eder. Yeterliyse rezervasyon/hareket/submitted/history/audit/receipt tek transaction; yetersizse sıfır yazmayla ret. Kararın reddi rejected yapar ve rezervasyon üretmez. Stock/legacy başvurular, gerçek kalem revizyonu ve picking sonrası telafi açılmaz.
- **Tekrar ve eşzamanlılık:** Auth/profil → UUID advisory → müşteri → sipariş/ödeme/başvuru → ürün sıralı inventory; Driver için sefer/durak paylaşım kilidi ve yeniden scope kontrolü. Müşteri kilidi tahsilat/limit/checkout/kararı seri hale getirir. Aynı aktör/key/payload aynı cevabı verir, farklı payload reddedilir; güncel rol ve tahsilat kapsamı replay öncesi kontrol edilir. `private.finance_receipts` RLS açık/EXECUTE ve ham erişim kapalıdır. Finans isteği gönderilmeden önce proje/aktöre özel şifreli yerel saklamaya yazılır; belirsiz cevapta yeni işlem engellenir, aynı istek geri yüklenir. Bu offline işlem yetkisi değildir.
- **Teknik olaylar:** `payment_verified` ve `credit_limit_changed` audit türleri yalnız bu onaylı işlemleri kaydetmek için eklendi. Önceki policy/grant'ler ve 12 migration/iki seed değiştirilmedi. Beş yeni public RPC: `record_payment`, `verify_payment`, `set_customer_credit_limit`, `decide_credit_approval`, `finance_workspace`; mevcut checkout yalnız kredi kontrolüyle genişletildi.

**Açık / kapalı kapsam:** disputed/cancelled tahsilat ve düzeltme/iptalin net borç etkisi kararsız; Manager/Owner için dahi bu işlemler açılmadı. Varsayılan vade değeri uydurulmadı; teslimat kesinleşirken vade snapshotını oluşturacak servis Faz 13'tedir. Stok yetersizliği onayı, picking sonrası telafi, gerçek kalem revizyonu, çeyrek/iskonto formülleri ve sefer atama/teslimat servisi bu fazda uygulanmaz. Yeni belirsiz yetki genişletilmedi. Gerçek Android/backend uçtan uca ve manuel görsel/üretim kabulü otomatik fixture testleriyle eşdeğer sayılmaz. Faz 11'e geçilmez; secret/commit/push yok.

### F9-01 — Onaylı depo/stok işlemleri (11 Ekim 2026)

Kullanıcı Faz 8'i commit edilmiş kabul ederek Faz 9'u açtı; üç açık sorunun tamamına **“Bu sınırlarla uygula”** yanıtı verdi. Aşağıdaki kararlar bu dilim için R-03/R-06'yı daraltır; eski “Faz 9'a geçme” kayıtları tarihçedir.

- Aktif Warehouse/Manager/Owner `submitted → picking` başlatır. Kısmi toplama pozitif integer **ilave satış miktarıdır**; sipariş kaleminin exact dönüşüm snapshotıyla taban miktar bulunur. Fiziksel ve rezerve stok aynı miktarda azalır, picked_qty artar. Tüm kalemler tamamlanınca `picking → picked`; miktar aşımı, başka sipariş kalemi ve tutarsız rezervasyon reddedilir. Fiyat/kalem miktarı/toplam/snapshot değişmez.
- `picked → loaded` yalnız tüm kalemler toplanmış, mevcut kapanmamış/tamamlanmamış durağa ve bitmemiş sefere atanmış siparişte çalışır; pasif araç kabul edilmez. Yükleme ikinci fiziksel düşüm üretmez. Atama servisi, `assigned` durumuna/sonrasına geçiş matrisi ve sefer/durak durum sözlüğü **Faz 11** için bekler; bu tur atanmışlık, mevcut FK/closed_at/ended_at alanları üzerinden denetlenir, yeni sefer statusu uydurulmaz. Driver yükleme yetkisi eklenmedi.
- Mal kabulü Warehouse/Manager/Owner'a açık: pozitif sonlu exact decimal miktar × güncel ürün birim dönüşümü; yuvarlama yok. Birim/dönüşüm/evrak notu/aktör/zaman ve received hareketi korunur; fiziksel/kullanılabilir stok artar, rezervasyon değişmez. Satışa kapalı ürünün stoğu alınabilir; bu işlem satışa açma veya fiyat yönetimi yetkisi değildir.
- Sayım girişini yalnız Warehouse yapar; yalnız Manager/Owner onaylar. Fiziksel taban miktarı sıfır veya pozitif exact decimal olabilir. UI ürün başına sayımı pending olarak gönderir; RPC birden çok ürünü atomik destekler. Gönderim stok miktarını değiştirmez. Onaya kadar fiziksel **veya rezerve** miktar değişmişse yeniden sayım gerekir; değişip eski değere dönme de inventory revision ile yakalanır. Sayılan fiziksel miktar mevcut rezervasyondan düşükse reddedilir. Onay, sayılan miktarı fiziksel stoğa uygular; sıfır farkta yapay hareket üretilmez. Audit eski/yeni stok ve oluşturan/onaylayan aktörleri kaydeder.
- İdempotency: aynı aktör/key/payload aynı cevabı verir; farklı payload `22023`, geçersiz yetki `42501`, eski sayım `40001`. Yetki replay öncesi canlı profilden denetlenir. Hareket/bakiye/picked/status/history/audit/receipt tek transaction; hata tamamını geri alır. Private receipt ve ham istemci yazmaları kapalıdır.
- Kilit sırası: Auth/profil → anahtar advisory → (siparişte müşteri → sipariş → kalemler) → ürün sıralı inventory; mal kabulünde ürün/birim → inventory; sayım onayında sayım → ürün sıralı inventory. Yüklemede bunları sefer/araç → durak izler. Gelecek atama/telafi servisleri bu sıraya uymalıdır. Çok bağlantılı dört yarış senaryosu ayrı testtedir; üretim yük testi değildir.
- Warehouse okuması açık alan listelidir; müşteri bilgisi/fiyat/iskonto/finans/serbest belge notu açılmaz. Manager/Owner aynı dar depo ekranını kullanır, önceki geniş okuma yetkileri değişmez. Accounting yazması, Customer/Sales checkout ve F8 karar/niyet sözleşmeleri korunur.

**Açık kalanlar:** Gerçek kalem revizyonu, picking sonrası iptal/iade telafisi, stok eksiğinde yönetici onayı sonrası rezervasyon, cari/exposure ve çeyrek/iskonto uygulanmaz. Eski revision içermeyen sayım fixture'ları otomatik onaylanmaz; yeni sayım gerekir. Pending sayımı düzenleme/ret/arşivleme ve eksik ürün bildiriminin ayrı olay/FCM sözleşmesi tanımlı değildir; yeni yetki eklenmedi. UI'da belirsiz cevap açık diyalogda aynı key/payload ile tekrar edilir; depo işlemleri için process-kill sonrası kalıcı yeniden deneme deposu bu dilimde yoktur. Sonuç belirsizken yeni işlem başlatılmamalı; hareket/sayım kaydı kontrol edilmelidir. Manuel cihaz/gerçek backend uçtan uca ve üretim kabulü ayrıdır. Faz 10'a geçilmez.

**11 Ekim 2026 — Faz 8 kapanış teyidi:** Son kullanıcı onayı F8-02'yi kesinleştirir: approved/rejected yalnız talep kararıdır; sipariş submitted kalır, kalem/fiyat/toplam/rezervasyon değişmez. Alternatif kabul/ret yalnız niyet kaydıdır. F8-01/F8-02 ile sınırlandırılmış yerel kapsam tamamlandı; gerçek kalem revizyonu ve picking sonrası stok etkili işlemler bekler. Bu kapanışta yeni iş kuralı veya yetki eklenmedi; Faz 9 başlatılmadı.

### F8-02 — Alternatif niyeti ve submitted talep kararı (10 Ekim 2026)

Kullanıcı F8-01 temelini koruyarak bu dilimi onayladı. Ek soruya kesin cevabı: **“Evet, yalnız karar kaydı; gerçek revizyon beklesin.”** Aşağıdakiler F8-01'in karar/alternatif servisi kapalı ifadelerinden önce gelir.

- Sales yalnız aktif atanmış müşterinin submitted kalemine ürün/birim ve pozitif integer miktarla alternatif niyeti sunar. Faz 5 quote minimum/birim denetimi kullanılır; teklif fiyat sabitlemez/stok ayırmaz. Aktif Customer kendi teklifini kabul/reddeder. Kabul, teklif ID'sine bağlı pending değişiklik talebi oluşturur. Ret asıl kalemi silmez. İki yanıt da alternatif audit olayı üretir. SPEC §11'in doğrudan kalem çıkarma/değiştirmesi bu açık onayla uygulanmaz.
- Yalnız aktif Manager/Owner, **submitted siparişteki pending talebi** approved/rejected yapar. Diğer 12 sipariş durumu kapalıdır. `approved` sipariş durum sözlüğünde yoktur; tamamlanmış talep yeni karara kapalıdır. Aynı UUID/aktör/payload replay'i ikinci karar üretmez; güncel yetki ve submitted sınırı replay sırasında da denetlenir.
- Karar yalnız talep kaydıdır: sipariş submitted, kalem/fiyat/exact snapshot/rezervasyon/finans aynı kalır. İptal talebinin onayı da otomatik iptal değildir. F8-01 Customer/Sales doğrudan submitted iptali gerçek iptal olarak ayrı kalır. UI bu ayrımı açıkça gösterir.
- Yeni kararlarda `decided_by`, `decided_at` ve boş olmayan `decision_note` zorunludur. Aktör/zaman sunucuda üretilir; tamamlanmış kayıt immutable'dır. NOT VALID check **varsa eski immutable kararlara hayali not yazmadan** yeni INSERT/UPDATE'leri denetler; geçmişe toplu not backfill'i yapılmaz.
- History'de `event_type=request_decided`, `request_id`, `request_decision` vardır. Bu olay submitted/submitted taşır, talep kararıyla aktör/not/status bakımından eşleşir; gerçek sipariş geçişi değildir. Normal status_changed olayında aynı durum hâlâ yasaktır. Composite FK aynı siparişi; unique request ID tek karar history'sini korur. Kullanıcının karar audit talebiyle B-08 izin listesine yalnız `order_request_decided` eklenir; order_applied=false kaydedilir.
- Karar/history/audit/private receipt atomiktir; audit hatası hepsini rollback eder. Auth/profil → advisory key → müşteri → sipariş → talep/teklif kilitleri mevcut checkout/iptal sırasıyla uyumludur. Aynı key farklı aktör/payload reddedilir. Ham yazma/genel SELECT/RLS genişletmesi yok; denetlenen RPC projection'ları vardır. Warehouse/Accounting sınırları korunur.
- Manager/Owner `/account/order-requests` kuyruğu ve notlu karar ekranı; Customer/Sales ortak siparişten alternatif ekranı vardır. Sales önerir, Customer cevaplar. Belirsiz ağ sonucunda açık diyalog aynı payload/key ile tekrar eder; offline kuyruk yoktur.

**Bekletilenler:** Gerçek kalem revizyonunun temsil/snapshot/yeniden fiyat onayı/rezervasyon farkı sözleşmesi, karşı miktar ve eski kalemin kapanışı; picking sonrası telafi; stok yetersizliği onayı sonrası rezervasyon ve kalan operasyon geçişleri. R-01/R-02 değişmedi. Bunlar F8-02 yerel kabulünün parçası sayılmaz; Faz 9'a geçilmez. Manuel/üretim kabulü ayrı kalır.

### F8-01 — Onaylı iptal ve talep dilimi (9–10 Ekim 2026)

Kullanıcı Faz 7'yi commit edilmiş/tamamlanmış kabul edip Faz 8'i yetkilendirdi. Bu turdaki açık cevapları kapsamı sınırlar:

- **Karar yetkisi:** Değişiklik ve iptal taleplerini yalnız Manager/Owner karara bağlayabilir. Bu, kaynaktaki belirsiz “Order Operator” ifadesinin bu iki talep türü için karşılığıdır; diğer operasyonlara genel yetki vermez. Alternatif uygulaması ve picking sonrası stok etkili onaylar **bekletilir**. Bu tur yalnız submitted iptali ve değişiklik/iptal talebi altyapısı uygulanır; talep karar RPC'si veya yönetim ekranı eklenmez. Manager/Owner mevcut RLS üzerinden talepleri okuyabilir; ham UPDATE dahil karar yazmaları kapalı kalır.
- **Doğrudan iptal:** Aktif Customer kendi kuruluşunun; aktif Sales yalnız halen atandığı aktif müşterinin `submitted` siparişini gerekçeyle iptal eder. Creator-only erişim yoktur. İşlem yalnız `submitted → cancelled` geçişidir; yeni durum veya başka geçiş seçilmez. Picking yapılmış/aktif durağı bulunan ya da rezervasyon kaydı tutarsız sipariş doğrudan iptal edilmez.
- **Stok/geçmiş:** Kayıtlı kalemin exact dönüşüm snapshotı ve rezervasyon hareketlerinin neti denetlenir. Her kalem için `released` hareketi, rezerv bakiyesi, durum geçmişi ve mevcut izin listesindeki stok/durum audit olayları tek transaction'dadır. Fiziksel stok, fiyat snapshotı, sipariş tutarı, borç/ödeme ve cari durum değişmez. Güncel fiyat veya güncel birim dönüşümü iptal miktarını belirlemez. Sonraki kalemde hata olursa önceki yazmalar da rollback olur.
- **Talep:** `submitted/picking/picked/assigned/loaded/out_for_delivery` için gerekçeli değişiklik niyeti kaydedilir. Submitted doğrudan iptal edilir; diğer sayılan durumlarda yalnız iptal talebi kaydedilir. Talep kalem/sipariş/rezervasyon değiştirmez; yapılandırılmış revizyon payload'ı veya alternatif uygulamaz. Karara bağlanmamış `draft/pending_approval/delivery_pending_confirmation/delivery_disputed` işlemleri kapalıdır; delivered için iptal yerine ayrı iade/uyuşmazlık kararı beklenir. Taleplerin kendi aktör/zaman/gerekçe kaydı vardır; B-08 audit izin listesine yeni olay uydurulmaz.
- **Teknik R-06 dilimi:** Auth → profil → işlem anahtarı advisory → müşteri → sipariş → sıralı kalem → sıralı inventory kilitleri; checkout kilit sırasıyla uyumlu. Private receipt aynı aktör/sipariş/eylem/gerekçe/UUID için aynı cevabı döndürür, farklı payload reddedilir; replay öncesi canlı yetki yeniden kontrol edilir. Anahtar kaybından sonra aynı aktörün aynı gerekçeli bekleyen talebi yeniden kullanılabilir. İkinci iptal yeni anahtarla da durum kontrolünde reddedilir. Ham istemci yazmaları açılmaz; yeni state RPC yalnız Customer/atanmış aktif Sales projection'ıdır.
- **Arayüz:** Customer/Sales ortak sipariş listesinde gerekçe ve açık onay, geçmiş/talepler, yükleniyor/hata/yeniden dene vardır. Belirsiz ağ sonucunda aynı açık diyalog aynı key/payload ile dener; gerekçe değiştirilemez. Diyalog kapanırsa sunucudan durum tekrar yüklenir. Bu yeni işlem için kalıcı çevrimdışı kuyruk/otomatik arka plan gönderimi eklenmez; DB çift stok etkisini engeller.

**Açık kalan kararlar:** Alternatif kabul/ret/miktar değişiminde eski kalemin tarihçesi ve aktifliği, toplam/snapshot revizyonu, yeniden fiyat onayı, rezervasyon farkı ve son kalemin çıkarılması; picking sonrası iptal/iade stok telafisi; stok yetersizliği onayı sonrası rezervasyon; tam geçiş matrisi ve failed/returned eşlemesi. R-01 çeyrek/iskonto ve R-02 cari/exposure değişmedi. Talep onay/ret işlem servisi ve yönetim ekranı bu turdaki daraltılmış kapsamda uygulanmadı; alternatif ve stok etkili onaylar karara bağlanmadan Faz 8 bütünü tamamlandı sayılmaz. Faz 9 başlamaz.

### F7-01 — Yalnız aktif atama ile saha siparişi (9 Ekim 2026)

Kullanıcı Faz 6'yı commit edilmiş/tamamlanmış kabul etti; Faz 7 kapsamını ve kesinti sonrası **yalnız atanmış + aktif müşteri** sınırını açıkça onayladı. Bu karar F4-02/F4-03/F6-01'in Sales için “atanmış veya oluşturduğu” ifadelerinden önce gelir.

- Sales Operator'ın `created_by` olması tek başına müşteriyi, fiyatını veya siparişlerini okuma/yönetme ve adına sipariş oluşturma yetkisi vermez. Müşterinin aktif olması ve `assigned_sales_operator_id=auth.uid()` gerekir; çalışanın DB profili de aktif Sales olmalıdır. Atama kaldırıldığında veya müşteri pasifleştirildiğinde RLS ve ortak servis erişimi kapanır. Başarılı eski checkout cevabını replay etme de yetki kontrolünden geçer.
- Dokuzuncu migration mevcut `private.sales_customer` yardımcısını daraltır. Mevcut RLS ve `quote_product`, katalog/sepet/taslak/checkout RPC'leri aynı yardımcıya bağlı olduğundan sınır yalnız ekranda uygulanmaz. `sales_checkout_customers` seçici için sadece ID/firma adını döndürür. Yeni genel SELECT/ham yazma izni yoktur; diğer rollerin sınırları genişletilmez.
- Eski Sales müşteri oluşturma RPC'si kaldırılmadı, otomatik atama da eklenmedi. Oluşturduğu atanmamış kuruluş, Owner/Manager mevcut atama işlemini yapana kadar Sales için kapalıdır. Bu faz yeni müşteri/atama yönetimi ekranı getirmez.
- Sales müşteri seçip **aynı Faz 6 repository/RPC ve katalog/ürün/birim/sepet/taslak/gönderim ekranlarını** kullanır. Kalıcı başlık hangi müşteri adına işlem yapıldığını gösterir. Fiyat/iskonto/dönüşüm/minimum, exact snapshot, half-up, stok rezervasyonu, değişiklikte açık yeniden onay ve idempotency sözleşmesi değişmez. `source=sales_operator`, `created_by=auth.uid()` sunucuda türetilir; Customer için `customer_app` kalır.
- Her aktör/müşteri için ayrı Riverpod scope vardır. Müşteriden çıkınca kaydedilmemiş bellek sepeti temizlenir; UI bunu açıkça bildirir. Sunucu taslağı ve şifreli bekleyen gönderim kaydı mevcut aktör/müşteri ayrımını korur. Başka müşteriye önceki sepet/fiyat/istek anahtarı taşınmaz. Atamayı yenile eylemi görünür veriyi tekrar doğrular; gerçek işlem anında her RPC güncel yetkiyi ayrıca kontrol eder. Realtime yetki yenilemesi eklenmez.

**Açık kalanlar:** R-02 cari/exposure/vade hesabı, R-01 çeyrek/iskonto eşikleri/geç iade ve R-03 yönetici onayından sonra stok/geçiş davranışları değişmedi. `not_evaluated` yalnız uyarıdır, borç/tahsilat veya limit onayı değildir. Yeni ticari formül/durum geçişi yok. Faz 8 başlamaz.

### F6-01 — Customer katalog/sepet/gönderim sınırı (9 Ekim 2026)

Kullanıcı Faz 5'i commit edilmiş ve tamamlanmış kabul edip Faz 6'yı yetkilendirdi. Son onaylar:

- Arayüz yalnız Customer içindir. Ortak Customer/Sales backend servisi hazırlanır; Sales müşteri seçimi ve saha ekranı **Faz 7'ye** kalır. Yetki canlı DB profil/üyelik/atama kontrolünden gelir; preview yetki sağlamaz.
- Cari formül/exposure R-02 netleşene kadar **kesin borç/tahsilat hesabı yapılmaz**. Yeni siparişte `payment_status=not_due`, `credit_check_state=not_evaluated`, `credit_warning=true` yalnız hesaplanmamış kontrol uyarısıdır; limit aşımı sonucu veya cari onayı değildir. Borç, vade, ödeme, exposure değeri veya eşik uydurulmaz. UI gönderimden önce ve sonra bu sınırı gösterir. Eski siparişlerde yeni alan NULL'dır; geçmişe dönük hesap yapılmaz.
- B-01/B-02'nin mevcut normal davranışı korunur: stok yeterliyse `submitted` ve yalnız rezervasyon; yetersiz/tanımsız stokta `pending_approval`, Manager/Owner için talep ve **hiç rezervasyon yok**. Kısmi rezervasyon/picking, yönetici onay/ret ekranı, iptal, teslimat ve ödeme yapılmaz. Yeni durum adı veya geçiş matrisi eklenmez. Stok yetersizliği onaylandıktan sonraki işlem R-03'te açıktır.
- Fiyat, iskonto, dönüşüm veya stok yeterliliği değiştiyse sunucu **hiç sipariş/rezervasyon yazmadan** `changed` ve önceki/güncel quote döndürür. Kalem birim fiyatı/dönüşümü ve toplam farkı gösterilir; ayrı “Güncel fiyatı onayla ve gönder” eylemi gerekir. Yeni onay sırasında tekrar değişirse aynı denetim tekrarlanır. Client quote'u tutar kaynağı değildir; sunucu F5-01 `quote_product` hesabını yeniden yürütür.
- Liste fiyatı/minimum taban birimde, satış miktarı pozitif integer, dönüşüm exact ve yuvarlamasızdır. Yalnız kalem sonunda half-up; sipariş toplamı yuvarlanmış kalemlerin toplamıdır. Exact final/list unit snapshot ve legacy gösterim snapshotı birlikte saklanır. Çeyrek önerisi/eşik/geç iade yapılmaz.

**Teknik taslak ve işlem sözleşmesi:** Düzenlenebilir taslak, `private.cart_drafts` içinde aktör + müşteri başına bir sepet (yalnız birim/miktar) olarak saklanır. Henüz ticari sipariş veya değişmez fiyat snapshotı değildir; stok ayırmaz, fiyat sabitlemez. Taslak yüklenince güncel katalog/fiyat denetlenir; silinmiş/pasif ürün sessizce atılmaz. Kesin sipariş ve snapshotlar yalnız açık fiyat onayından sonra tek transaction'da oluşur. Başarılı gönderim yalnız aynı içerikli taslağı temizler; diğer cihazdan daha yeni kaydı silmez.

**R-06'nın bu dilimi:** Auth → profil → request_key advisory → müşteri → sıralı kategori/ürün/birim → fiyatlama tablosu SHARE → sıralı inventory FOR UPDATE kilitleri; kilitlerden sonra yeniden fiyat/stok hesabı. Aynı ürünün farklı birimleri stok talebinde birleştirilir. Şimdilik dar fiyatlama tablosu SHARE kilidi eksik iskonto satırına eşzamanlı eklemeyi de engeller; ileriki iskonto yazma servisi öncesi aynı kilit sözleşmesi ve performans yeniden değerlendirilmelidir. Aynı aktör/müşteri/normalize sepet/onay ve UUID aynı cevabı döndürür; farklı payload anahtarı reddedilir. Yetki replay öncesi yeniden denetlenir. Sipariş/kalem, rezervasyon hareketi, history/audit ve private receipt atomiktir. Ham tablo yazması veya yeni genel SELECT policy açılmaz.

İstemci bilinmeyen gönderim sonucunu proje/kullanıcı/müşteri anahtarında mevcut şifreli depoya kaydeder; uygulama yeniden oluşturulunca aynı anahtar ve onayla devam eder. Bu **offline sipariş** değildir. Bilinen SQL rollback cevabı düzeltmeye izin verir; belirsiz ağ sonucu başka payload ile gönderilemez. SQL snapshot/receipt ve Flutter fixture/yerel SDK transport testleri ayrı kanıtlardır.

**Kalan kararlar:** R-02 cari/exposure/varsayılan vade; R-03 stok eksiğinde yönetici onayı sonrası rezervasyon ve sonraki geçişler; R-01 çeyrek/eşik/geç iade hâlâ açıktır. Üretim yükü ve çok bağlantılı eşzamanlılık stres kabulü bu tur yapılmaz. Customer dışındaki yeni arayüz/yetki eklenmez.

### F5-01 — Onaylı ürün/birim/fiyat kapsamı (9 Ekim 2026)

Kullanıcının bu görevdeki kesin kararları, SPEC'in tarihsel Warehouse/Accounting fiyat yetkisi ve B-05/R-04 belirsizliğinden önce gelir:

- Fiyat yönetimi yalnız aktif Manager/Owner. Warehouse fiyat okuyamaz/yazamaz, Accounting yazamaz. Warehouse fiyatsız (`NULL`, sıfır fiyat değil), satışa kapalı ürün ve satış birimlerini oluşturur; Manager/Owner fiyatı belirleyip ayrı adımda satışa açar. Mevcut ürünler değiştirilmez. Manager/Owner da aynı taslak akışını kullanır.
- Liste fiyatı ve minimum miktar taban birimine aittir. Pozitif integer satış miktarı × exact decimal dönüşüm = taban miktar; dönüşüm yuvarlanmaz. Minimum taban miktarla karşılaştırılır. Taban birimi kendi adıyla satışa sunulursa katsayı 1 olur. Float kullanılmaz.
- Satış biriminin kesin liste fiyatı = taban fiyat × dönüşüm; kesin final fiyat = bu tutar × (1 − yürürlükteki iskonto). Kalem toplamı kesin final fiyat × satış miktarından en yakın kuruşa, tam yarımda yukarı yuvarlanır. Sipariş toplamı bu fazda üretilmez; sonraki sipariş servisi yuvarlanmış kalemleri toplar.
- `order_items.exact_list_price_kurus_snapshot` ve `exact_final_price_kurus_snapshot` exact numeric alanlarıdır. Eski bigint `unit_price_kurus`/`final_unit_price_kurus` korunur; yeni snapshotlarda bunlar yalnız uyumluluk/gösterim için en yakın kuruş değeridir, kalem hesabının girdisi değildir. Yeni exact çiftinin tutarlılığı ve değişmezliği DB'de denetlenir; eski satırlar geriye dönük yeniden fiyatlanmaz. Bu, B-05'in tüm parasal alanları bigint tutma kuralına kullanıcı onaylı kesirli birim fiyatı istisnasıdır; ödenecek kalem tutarı hâlâ integer kuruştur.
- Müşteri iskontosu `effective_from` açısından Europe/Istanbul gününe göre seçilir; henüz yürürlükte kayıt yoksa kaynak normal liste fiyatı davranışı (%0) geçerlidir. Müşteri ve yetkili Sales aynı backend hesabını çağırır. Çeyrek önerisi/eşik hesabı/geç iade kuralları yapılmaz; R-01'in diğer maddeleri açık kalır.

**Teknik transaction sözleşmesi:** Fiyat değişiminde actor Auth satırı → operation_key advisory kilidi → ürün satırı kilidi sırası uygulanır. Aynı anahtar ve aynı aktör/ürün/eski fiyat/yeni fiyat/gerekçe aynı geçmiş ID'sini döndürür, ikinci audit üretmez; farklı payload `22023`, eski fiyat uyuşmazlığı `40001` verir. Bu R-06'nın yalnız fiyat değişimi dilimini kapatır. Kayıt oluşturma tek transaction ve sabit ürün UUID/SKU unique ile tekrarlı ürün oluşmasını engeller; başarılı replay cevabı vaat etmez. Ağ kesintisinde liste yenilenir. Satışa açma aynı güncel fiyatla tekrar edilebilir. Ham tablo yazma yetkisi açılmaz.

**Açık kalanlar / sınırlar:** Kategori oluşturma/düzenleme ve mevcut ürün/birim metadata değiştirme yetki ve geçmiş kuralları tanımlı değil; yeni yönetim yetkisi eklenmez. Mevcut aktif kategoriler seçilir, yeni ürünün birimleri oluşturma transaction'ında tanımlanır. Müşteri kataloğu/sepet/sipariş yazma Faz 6, çeyrek önerisi/gerçek eşikler ve geç iade R-01, sipariş revizyonu R-03, diğer transaction kilitleri R-06 kapsamında kalır. Quote stok ayırmaz, fiyatı sabitlemez; gelecek sipariş servisi aynı kurallarla transaction içinde yeniden hesaplamak zorundadır.

### F4-07 — Android kabulünün kapanışı (8–9 Ekim 2026)

F4-05/F4-06 iş ve yetki sınırları değişmedi. Gerçek Android emülatöründe kayıt/kod/davet/kurtarma, müşteri ve çalışan oturumunun process restart sonrası geri yüklenmesi ve tamamlanan çıkıştan sonra geri gelmemesi doğrulandı. Owner yönetiminde sentetik hesabı pasifleştirme/yeniden açma ve debug önizleme/geri gezinme gözlendi. Böylece aşağıdaki F4-06'nın Android kanıtı bekleyen maddesi kapandı; Faz 4 yerel geliştirme kabulü tamamlandı. Görsel kapsam, emülatörde gözlenen geçici ANR ve test sınırları TESTING'de kayıtlıdır.

Yeni rol, izin veya iş formülü eklenmedi. Üretim ilk Owner temini/SMTP, genel üyelik aktarımı ve ileriki faz kararları hâlâ açık; bu kapanış üretime çıkış kararı değildir. Faz 5 bu görevde başlatılmadı.

### F4-05 — Onaylı kayıt, davet ve hesap yaşam döngüsü (7 Ekim 2026)

Bu bölüm önceki kayıtlardaki “signup kapalı / oturum yalnız bellekte / hesap kapatma kararı bekliyor” ifadelerinden önce gelir. F4-01–F4-04 erişim sınırları değişmez.

**Kullanıcı onayları:** Müşteri kaydı yönetici onayı olmadan aktif kuruluş/profil/üyelik oluşturur; oturum için e-posta koduyla sahiplik doğrulanır. Çalışan daveti Owner/Manager'ın seçtiği DB rolüne bağlıdır ve e-posta koduyla kabul edilir. Owner tüm rolleri, Manager yalnız customer/sales_operator/warehouse/driver rollerini davet edebilir. Yalnız Owner hesap pasifleştirebilir/yeniden açabilir; son aktif Owner ve açık iş ataması olan çalışan kapatılamaz. Kayıtlar silinmez; müşteri kendi hesabını kapatamaz.

**Uygulama:** Altıncı migration `20261007000100_account_onboarding.sql`, 35 public tabloyu korur; yalnız `private.account_invitations` ekler. Auth kayıt trigger'ı müşteri rolünü sabitler; kullanıcı metadata'sıyla ayrıcalıklı rol veya mevcut kuruluş seçilemez. Davetler için denetlenen oluşturma/iptal/listeleme/kabul RPC'leri vardır. Kabul anında doğrulanmış Auth e-postası, daveti verenin güncel aktif rolü ve hedef kuruluş yeniden kontrol edilir. Hesap pasifleştirme üyelik/sipariş/finans geçmişini silmez; mevcut RLS pasif profilin veriye erişimini keser. Son Owner koruması rol düşürmeye de uygulanır. Açık iş sınırı F4-04'teki Sales ataması ve primary/assistant açık sefer/durak koşuludur.

**Teknik seçimler (yeni iş formülü değildir):** Yerel e-posta kodu 6 hane/60 dakika; bekleyen davet kaydı 24 saat geçerlidir. Kod e-posta şablonundan uygulamada girilir; SMS, OAuth veya auth deep link eklenmez. Local SMTP yalnız Mailpit'e gider. `invite-account` Edge Function, kullanıcı token'ını Auth `/user` ile doğrular; rolü SQL denetler. Gateway `verify_jwt=false` olması anonim yetki sağlamaz. Admin credential yalnız Supabase sunucu runtime ortamından okunur; Flutter'a/depo dosyasına yazılmaz. E-posta gönderimi başarısızsa bekleyen davet iptali denenir; yarıda kalan davet süre sonunda geçersizdir, kendiliğinden profil üretmez.

### F4-06 — PKCE, tekrar kabul ve parola sınırı düzeltmeleri (7 Ekim 2026)

- Flutter Auth akışı PKCE'dir. SDK doğrulayıcısı `SecurePkceStorage`, oturum ise `SecureSessionStorage` ile proje URL'sine göre ayrılan şifreli platform deposunda tutulur (`flutter_secure_storage: 11.2.0`). Düz metin yedeği yoktur; Android backup/device transfer kapalıdır. Otomatik refresh açık, URI yakalama kapalıdır. Kod doğrulaması gerçek SDK `verifyOTP` çağrısıyla yapılır; PKCE'yi kapatma yoluna gidilmez.
- Davet kabul RPC'si aynı kabul eden için ikinci profil/üyelik/audit oluşturmaz. İstemci `account_invitation_accepted()` ile yalnız kendi doğrulanmış kabul durumunu kontrol eder; tamamlanmış davetin tekrar gönderimi parolayı da değiştirmez. Bu boolean pasif profilde de okunabilir, başka veri/yetki açmaz. Auth parolası kaydedilip DB kabulü kesildiyse yalnız davet akışındaki `same_password` cevabı tekrar DB kontrolüne izin verir; diğer hatalar yutulmaz. İptal/süre/rol sınırları yine SQL'de uygulanır.
- Yeni parola yereldeki Auth minimumuyla aynı **en az 8 Unicode karakter, en çok 72 UTF-8 bayt** sınırına sahiptir. Kurtarma/davet girdisi kod tüketilmeden doğrulanır; uzun parola kesilmez. Gerçek SDK testinde backend'in kısa/çok baytlı uzun parolayı reddetmesi, aynı kurtarma koduyla düzeltilmiş girdinin kullanılabilmesi ve tekrar davetin ilk parolayı değiştirmemesi doğrulandı.
- Parola değiştirme mevcut parolayla yeniden giriş gerektirir; değiştirme/kurtarma sonrası global çıkış yapılır. Daha önce verilmiş erişim JWT'si süresi dolana kadar geçerli olabilir; global çıkış anında bütün erişim JWT'lerini iptal ediyor diye raporlanmaz. Profil pasifleştirmesi canlı RLS rol kontrolüyle uygulama verisini kapatır.

**Kalan açık/kanıt bekleyen noktalar:** Üretimde ilk Owner'ın güvenilir yönetici kanalıyla temini ve gerçek SMTP/teslim edilebilirlik henüz kurulmadı; canlı ortama geçiş yapılmadı. Genel üyelik aktarımı/pasif üyeliği yeniden açma, çoklu kuruluş ve Sales oluşturucu erişiminin iptali genişletilmedi. Dönüşüm RPC'si mevcut, dönüşüm yönetim arayüzü bu üç düzeltmenin kapsamında değil. Android'de gerçek hesabın uygulama sonlandırma/yeniden açma sonrası oturum dönüşü ve yeni auth ekranlarının görsel kabulü ayrıca bekler; host testlerindeki secure-storage mock'u cihaz kanıtı sayılmaz. Faz 4 bütünü bu kanıtlar olmadan kapatılmaz; Faz 5'e geçilmez.

**6 Ekim 2026:** Faz 4 başladı. Son kullanıcı rol atama/müşteri erişim onayları ve uygulama sınırları dosyanın sonundaki F4-01–F4-03'tedir; önceki Faz 3 kayıtları tarihçedir.

**Son bütünlük düzeltmesi (4 Ekim 2026):** Kullanıcının kapanış incelemesindeki yedi P2 bulguyu düzeltme talebi T-13 kapsamında uygulandı. Onaylı B-01–B-09 iş kuralları ve R-01–R-07 açık kararları değiştirilmedi. Yeni migration eski dosyalara dokunmadan korumaları güçlendirir; business DB paketi artık 140 testtir (97 eski + 43 regresyon).

**Güncel karar önceliği (4 Ekim 2026):** Kullanıcının B-01–B-09 onayları aşağıdaki eski kaynak kararlarını gerektiği yerde değiştirir. K-05/A-02'deki yalnız uyarıyla devam, A-03'teki belirsiz stok düşüm anı, K-09/A-13'teki driver tahsilat sınırı ve K-10/K-15'te yalnız Manager çözümü güncel uygulama kuralı değildir. Kaynak ve eski soru metinleri izlenebilirlik için korunmuştur; güncel cevaplar ve kalan sorular bu dosyanın sonundadır. DOCX değiştirilmez.

Kayıt tarihi: **2026-10-02** (Europe/Istanbul). Kaynak: [Pekşen Gıda Teknik Tasarım ve Codex Geliştirme Planı v3](Peksen_Gida_Teknik_Tasarim_v3.docx), revizyon tarihi 1 Ekim 2026. Bölüm numaraları kaynak DOCX'e aittir.

Bu kayıt Faz 1'de hazırlanmış, Faz 2'de iskeletin ve Faz 3'te config/client ile ilk migration/seed diliminin teknik kararlarıyla genişletilmiştir. Kaynakta karara bağlanmış kurallar ile henüz cevaplanmamış sorular ayrılmıştır. Açık maddeler onaylanmış varsayım değildir; formül, eşik yorumu, yeni rol veya durum geçişi seçilmemiştir. İş kurallarının tamamı [SPEC.md](SPEC.md), fazlar ve kabul ölçütleri [PLAN.md](PLAN.md) içindedir.

Kaynak §37 uyarınca ilgili iş kuralını uygulayan faz başlamadan karar kaydı tamamlanır. İlgili karardan bağımsız iskelet ve ekran hazırlığı ilerleyebilir. Faz 1'in tamamlanması, aşağıdaki soruların cevaplandığı veya uygulamanın hazır olduğu anlamına gelmez.

## Kaynakla kabul edilmiş kararlar

Aşağıdaki kayıtların tarihi 2026-10-02, durumu **Kabul edildi — kaynak kararı**dır. Bu tarih belgenin kararlarını depoya aktarma tarihidir; yeni ürün onayı değildir.

| ID | Karar | Gerekçe ve korunan kural | Kaynak | Etkilediği fazlar |
| --- | --- | --- | --- | --- |
| K-01 | Tek satıcı, tek depo; Android APK öncelikli Flutter/Supabase mimarisi. | Mevcut iş kapsamı korunur; gelecekte iOS'a açılabilecek yapı ilk sürümde iOS build anlamına gelmez. | §1, §28–29, §31 | 1–17 |
| K-02 | Riverpod, `go_router`, repository/service ayrımı ve her feature için `data/domain/presentation`; Supabase Auth e-posta/şifre, PostgreSQL, RLS, RPC/Edge Functions, Realtime, gerekli kanıtlar için Storage, Android push için FCM. | Kaynak mimari sözleşmesi; kritik fiyat/stok/ödeme işlemleri backend transaction içinde yürür. | §28–29, §36 | 2–17 |
| K-03 | `customer_app` ve `sales_operator` aynı OrderService/backend transaction'ını kullanır; fiyat backend'de yeniden hesaplanır. | İki ayrı sipariş mantığı kurulmaz, istemciden fiyat kabul edilmez; geçmiş fiyat snapshotları korunur. | §5, §8, §26 | 3–10, 16 |
| K-04 | Sipariş miktarı tam sayıdır; ambalaj/gramaj metadata'dır. | Adet/kg/koli/paket desteklenir; `1.82 kg` gibi sipariş girilmez. Dönüşüm hassasiyeti henüz açık karardır. | §4, §37 | 3, 5–9, 16 |
| K-05 | Cari limit aşımı uyarı üretir; otomatik bloklama yoktur; müşteri “Devam etmek istiyorum” diyebilir. | Limit backend'de hesaplanır; aşım ve devam onayı audit edilir. Formülün açık olması bu davranışı değiştirmez. | §6, §37 | 3, 6–7, 10, 16 |
| K-06 | İskonto eşikleri konfigürasyondadır; yaklaşık 50K=%4, 70K=%6, 100K=%8 yalnızca test eşikleridir. | `app_settings/pricing_rules` kullanılır; toplam/ortalama yorumu ve hesaplama formülü bu kayıtta türetilmez. | §5, §37 | 3, 5–7, 10, 16 |
| K-07 | `available_qty = physical_qty - reserved_qty`; stok hareket geçmişi immutable tutulur. | Fiziksel ve kullanılabilir stok ayrıdır. Rezervasyon, toplama ve düşüm zamanları A-03 ile netleştirilir; yeni stok formülü üretilmez. | §12, §37 | 3, 6–9, 11, 16 |
| K-08 | Yedi kaynak rol korunur; müşteri kendi verisini, driver kendine bağlı veriyi görür; maaş/prim yalnız Owner erişimine açıktır. | RLS olmayan hassas tablo production-ready sayılmaz. Mobilde yalnız anon/publishable key bulunur; `service_role` APK'ya konmaz. | §2, §26, §29 | 2–17 |
| K-09 | Normal tahsilat Sales Operator, yöntem nakit/POS, doğrulama Accounting; istisnai yetkili çalışan tahsilatında fiili collector kaydı zorunlu. | Driver normalde ödeme almaz; online ödeme ve fatura PDF MVP dışındadır. | §7, §19, §31 | 3–4, 7, 10, 16 |
| K-10 | Normal teslimat driver ve customer çift onayıyla tamamlanır; puanlama yalnız Driver için, 1–5 yıldız ve sipariş başına birdir. | Teslim edilmeyen sipariş puanlanamaz. Uyuşmazlık Manager tarafından çözülür. | §17, §20, §33 Faz 13 | 3–4, 8, 11–13, 16 |
| K-11 | GPS yalnız `out_for_delivery` sırasında aktiftir; müşteri kendi aktif teslimatının son araç konumunu ve güncelleme zamanını görür. | Başlangıç hedefi 10–15 saniyedir; adaptif aralık mümkündür. Sefer/teslimat sonunda paylaşım durur; süre ayrıntıları açık kalır. | §16, §30, §37 | 3–4, 11–12, 16–17 |
| K-12 | İlk sürüm internet olmadan kritik işlem yapmaz; kapsam dışı maddeler korunur. | Online ödeme, SMS OTP, PDF fatura, rota optimizasyonu, geocoding, iOS build, çoklu satıcı/depo, tam satın alma/tedarikçi yönetimi, ileri ERP, zorunlu fotoğraf/imza/QR ve siparişi iki araca bölme eklenmez. | §1, §31 | 2–17 |

### Kaynak §32'de varsayılan olarak kabul edilmiş sekiz karar

Kaynak başlığında “açık kararlar” ifadesi bulunmasına rağmen aşağıdaki değerler varsayılan olarak **kabul edilmiştir**; çözümsüz soru gibi yeniden açılmaz. Veri modeli ayrıntılarının eksik olması bu ürün kararlarını ortadan kaldırmaz.

| ID | Karar | Gerekçe ve korunan kural | Kaynak | Etkilediği fazlar |
| --- | --- | --- | --- | --- |
| K-13 | Sayım farkı onayı Manager/Owner yetkisinde. | Onay sonrası stok son miktarı güncellenir; yapan/onaylayan audit edilir. | §13, §32 | 3–4, 9, 15–16 |
| K-14 | §15: “Bir siparişin iki araca bölünmesi database modelinde desteklenebilir; MVP'de kapalı tutulur.” §32: “Veri modeli hazır, MVP kapalı”. | MVP'de kapalı olması kesindir. İki ifadenin model hazırlığına ilişkin kesinlik farkı ve bu hazırlığın kapsam/ayrıntısı A-06'da açıktır; bu kayıt kendiliğinden birini diğerinin yerine seçmez. | §15, §31–32 | 3, 11, 16 |
| K-15 | Müşteri uygulamayı açmazsa Manager exception approval gerekir. | Driver tek başına normal teslimatı kesinleştirmez. | §17, §32 | 3–4, 8, 13, 16 |
| K-16 | Uyuşmazlık fotoğrafı opsiyoneldir. | Normal teslimatta zorunlu fotoğraf, imza veya QR yoktur; kanıt kontrollü Storage'dadır. | §18, §31–32 | 3–4, 13, 16 |
| K-17 | Minimum sipariş tutarı yoktur. | Kaynak varsayılanında global minimum zorunluluğu tanımlanmaz. | §4, §32 | 5–7, 16 |
| K-18 | Minimum ürün miktarı ürün bazlıdır. | Ürün minimumu kontrol edilir. | §4, §24, §32 | 3, 5–7, 16 |
| K-19 | Büyük indirim bildirimi kampanya/indirim event'i ile oluşur. | Normal fiyat değişikliği herkese bildirim göndermez; hedef müşteri grubu ve deep link desteklenir. | §21–22, §32 | 3–5, 14–16 |
| K-20 | Müşteri kayıt sonrası doğrudan aktiftir. | İlk sürüm e-posta/şifre ile kendi kayıt akışını ve kuruluş başına tek kullanıcıyı korur; `customer_users` yine vardır. | §3, §32 | 3–4, 6, 16 |

## Faz 2 teknik kararları

Aşağıdaki kararların tarihi **2026-10-02**, kapsamı **Faz 2 arayüz iskeleti**dir. A-01–A-13 iş kararlarını kapatmazlar. Teknik seçim yapılmış olması test/build veya cihaz kontrolünün geçtiği anlamına gelmez; sonuçların kaydı PROGRESS'tedir.

### T-01 — Android adı, geçici kimlik ve mevcut depo kökü

- **Karar:** Kullanıcının açık talebiyle görünen ad `Pekşen Gıda`, geliştirme amaçlı `applicationId` ve namespace `com.example.peksen_gida` seçildi. Proje `D:\peksen_gida` kökündedir; iç içe ikinci proje klasörü oluşturulmadı.
- **Gerekçe:** Yayın kimliği henüz belirlenmedi. Mevcut dokümanların korunması için Flutter oluşturucusu geçici klasörde çalıştırıldı; gerekli Android/Flutter iskelet dosyaları seçilerek kopyalandı. Oluşturucu README ve `.gitignore` dosyaları mevcut dosyaların üzerine yazılmadı.
- **Sınır:** Bu kimlik ticari yayın kimliği değildir. Kalıcı kimlik, servis yapılandırmaları ve yayın hazırlığından önce kararlaştırılmalıdır. Kaynak DOCX değiştirilmez.
- **Durum / etki:** Kabul edildi — kullanıcı kararı; Faz 2, 3–4 ve 17 yapılandırması.

### T-02 — SDK ve bağımlılık tabanı

- **Karar:** Mevcut Flutter stable `3.47.6`, Dart `3.13.5`, Android SDK `37.0.0` ve Android Studio JBR `25.0.3` kullanılır. `pubspec.yaml` doğrudan uygulama bağımlılıklarını `flutter_riverpod: 3.4.3` ve `go_router: 18.0.2` olarak tam sürümle seçer. `flutter_localizations` ve Android açılış/önizleme testi için eklenen geliştirme bağımlılığı `integration_test` Flutter SDK'dan gelir; çözülen bağımlılıklar `pubspec.lock` ile korunur.
- **Gerekçe:** Kaynağın Riverpod/go_router mimarisini mevcut araç zinciriyle tekrar üretilebilir biçimde kurmak. Kararlı sürüm kaynakları: [flutter_riverpod sürümleri](https://pub.dev/packages/flutter_riverpod/versions), [go_router sürümleri](https://pub.dev/packages/go_router/versions). Bağımlılık çözümü `flutter pub get` ile yapılmıştır; analyze/test/build sonuçları ayrı kanıttır.
- **Sınır:** Supabase, konum, FCM veya ödeme paketi eklenmez; ortam değişkeni yükleme mekanizması bu fazda uygulanmaz. Sonraki sürüm yükseltmeleri yeniden doğrulanır.
- **Durum / etki:** Kabul edildi — teknik uygulama kararı; Faz 2 ve sonraki Flutter görevleri.

### T-03 — Debug ile sınırlı geliştirme önizlemesi

- **Karar:** “Geliştirme önizlemesi” yalnız debug modunda görünür. Giriş görünürlüğü ve router erişimi ayrı ayrı `kDebugMode` koşuluna bağlıdır. Router, `previewEnabled` override edilse bile profile/release sürümünde önizlemeyi açmaz; `/preview` ve alt yolları girişe yönlendirir.
- **Gerekçe:** Gerçek Auth/RBAC/RLS olmadan yedi rolün menüsünün incelenebilmesi. Riverpod `selectedPreviewRoleProvider` yalnız bellekte son seçilen rolü hatırlatır; oturum, veritabanı rolü veya yetki sağlamaz.
- **Sınır:** Giriş ekranı gerçek oturum açmanın bağlı olmadığını belirtir; giriş düğmesi devre dışıdır. Alanlar sunucuya gönderilmez veya kalıcı kaydedilmez. Gerçek yetkilendirme Faz 4'ün işidir.
- **Durum / etki:** Kabul edildi — kullanıcı gereksiniminin teknik karşılığı; Faz 2 ve Faz 4'e geçiş.

### T-04 — Yönlendirme ve geri davranışı

- **Karar:** `/` giriş yoludur; `/login` aynı yola yönlenir. İç içe go_router yolları `/preview`, `/preview/roles/:roleId`, `/preview/roles/:roleId/:screenId` ve `/preview/states/:kind` biçimindedir. Desteklenen durumlar `loading`, `empty`, `error`dur.
- **Gerekçe:** Doğrudan alt sayfa bağlantısında da ekran → rol menüsü → önizleme → giriş sırası kurulabilir. Geri düğmesi varsa önceki sayfaya döner; geçmiş bulunmazsa ilgili üst yola gider. Bilinmeyen yol, rol, ekran veya durum Türkçe “Sayfa bulunamadı” görünümünü ve girişe dönüş eylemini gösterir; hata sayfasında sistem geri davranışı girişe dönüştürülür.
- **Düzeltme ve kanıt:** go_router `18.0.2` eşleşmeyen URL için `errorBuilder` kullanıldığında boş `RouteMatchList` oluşturuyordu; Android geri işleyicisindeki `.matches.last` erişimi `StateError: Bad state: No element` üretiyordu. `onException` eşleşmeyen URL'yi kayıtlı `/not-found` yoluna taşır; geri olayı artık gerçek bir rota eşleşmesi üzerinde ele alınır. Geçersiz rol/ekran/durum parametrelerinin mevcut bulunamadı görünümü korunur. Başlangıç bağlantısı ve açık uygulamada bilinmeyen yola gitme testleri, Android sistem geri olayını göndererek girişe dönüşü ve exception oluşmamasını doğrular; önizleme kapalı durumu da kapsanır.
- **Sınır:** Bu rota parametreleri kaynak ekran envanterini seçer, backend yetkisi tanımlamaz. Android dış bağlantı/FCM deep link entegrasyonu bu fazda yoktur.
- **Durum / etki:** Kabul edildi — teknik uygulama kararı; Faz 2, sonraki ekran entegrasyonları ve Faz 14.

### T-05 — Release imzalama sınırı

- **Karar:** Android şablonunun release için debug imzası kullanma ayarı kaldırıldı. Faz 2 yalnız `flutter build apk --debug` hedefler; release imzası yapılandırılmadı.
- **Gerekçe:** Geliştirme çıktısının ticari imzalı yayın gibi sunulmasını önlemek ve gerçek imzalama anahtarlarını geliştirme deposundan ayrı tutmak.
- **Sınır:** İmzalı release kabulü ve anahtar saklama düzeni Faz 17'de hazırlanır; bu fazda release build, commit, push veya yayınlama yapılmaz.
- **Durum / etki:** Kabul edildi — teknik uygulama kararı; Faz 2 ve 17.

### T-06 — Türkçe tema ve kaynak ekran envanteri

- **Karar:** Material 3, ortak yeşil/krem renkler ve `tr_TR` locale kullanılır. Türkçe giriş/yükleniyor/boş/hata görünümleri ile SPEC §23'teki yedi rolün toplam 70 ekran girdisi korunur. Owner menüsü on Manager ekranına Finance, Salary/Bonus, Settings ve Audit Log karşılıklarını ekler.
- **Gerekçe:** Türkçe menüler kaynak ekranlarına izlenebilir biçimde eşlenir; kaynak İngilizce etiketler `sourceLabel` olarak tutulur. Kaydırılabilir içerik ve sınırlı genişlik giriş alanlarına küçük ekran/klavyede erişmeyi destekler.
- **Sınır:** Menü bağlantıları yalnız açıklayıcı ekran kabuklarıdır. Gerçek ürün, sipariş, stok, cari, tahsilat, GPS ve bildirim işlemleri yoktur. Tema ticari marka onayı, widget testi ise bütün Android cihazlarda görsel kabul anlamına gelmez.
- **Durum / etki:** Kabul edildi — teknik uygulama kararı; Faz 2 ve sonraki arayüz görevleri.

## Faz 3 teknik kararları — 3 Ekim 2026

### T-07 — Faz sınırı ve güvenli istemci yapılandırması

- **Karar:** PLAN/SPEC §33'te Faz 3 `Supabase migrations + seed`, Faz 4 `Auth + RBAC + RLS`dir. Kullanıcının Faz 3 talebindeki env/client/auth-state hazırlığı uygulanır; gerçek giriş, signup, rol yönlendirmesi ve izin veren RLS politikaları uygulanmaz.
- **Yapılandırma:** Flutter SDK'nın `--dart-define-from-file=.env` desteği kullanılır; dosya asset değildir. `SUPABASE_URL` ve yalnız bir `SUPABASE_PUBLISHABLE_KEY` veya eski `SUPABASE_ANON_KEY` alınır. Tamamen boş yapılandırma ağsız önizlemedir; eksik/çakışan değer hata durumudur. HTTPS gerekir; debug modunda yalnız localhost, 127.0.0.1, ::1 ve Android host köprüsü 10.0.2.2 için HTTP kabul edilir.
- **Sınır:** Secret/service_role ve bozuk anahtar biçimleri reddedilir. Eski JWT'de `role=anon` kontrolü yalnız yanlış anahtar kullanımını önler; imza/anahtar doğrulaması veya yetki kanıtı değildir. Build-time değerler APK'dan çıkarılabilir; gerçek sır bu mekanizmaya verilmez. Hata/config tanılamaları değerleri yazdırmaz. Gerçek proje değeri eklenmedi.
- **Bağımlılık:** Kararlı `supabase_flutter: 2.18.0` ve lockfile çözümü seçildi; Riverpod/go_router değişmedi. [Paket kaynağı](https://pub.dev/packages/supabase_flutter/versions/2.18.0), [SDK başlangıcı](https://supabase.com/docs/reference/dart/initializing).

### T-08 — Client başlangıcı ve yalnız oturum gözlemi

- **Karar:** Uygulama kapsamındaki Riverpod FutureProvider tek başlangıcı paylaşır. Config yokken SDK çağrılmaz; yükleme/hata önizlemeyi engellemez. Giriş ekranı gerçek gönderimi kapalı tutar. AuthRepository yalnız ilk session snapshot'ını ve sonraki SDK olaylarını izler; token, parola veya iş rolünü UI modeline taşımaz. Abonelik iptal edilince SDK dinleyicisi kapatılır. Session görünmesi yetki veya veritabanı rolü sağlamaz.
- **Saklama:** Faz 3'te `EmptyLocalStorage`, `persistSession=false`, `autoRefreshToken=false`, `detectSessionInUri=false` kullanılır. SDK'nın oturum saklama kapalıyken de açtığı varsayılan PKCE preferences depolaması kullanılmaz; PKCE yazması hata verir. Kalıcı oturum, code exchange ve yenileme Faz 4 hazırlığında A-14 ile ele alınır.
- **Hata:** SDK ayrıntıları UI/log'a taşınmadan sabit Türkçe hata üretilir. Sabit build yapılandırmasının hatasında otomatik sonsuz yeniden deneme yapılmaz. “İstemci hazır” server bağlantısı veya auth doğrulaması değildir. Router ve debug önizleme sınırı korunur.
- **Kaynak:** [Auth olayları](https://supabase.com/docs/reference/dart/auth-onauthstatechange), [SDK saklama seçenekleri](https://pub.dev/packages/supabase_flutter/versions/2.18.0). Bu teknik hazırlık Faz 4 kabulünü karşılamaz.

### T-09 — Karardan bağımsız migration ve seed dilimi

- **Karar:** Yedi değerli `app_role`, SPEC §25'teki `profiles`, `customers`, `customer_users` için ilk sürümlü migration hazırlandı. UUID PK/FK kullanılır; `profiles.id` Auth kullanıcısına bağlıdır. Müşteri kuruluşu başına tek kullanıcı `unique(customer_id)` ile korunur; üyelik tablosu ileriki genişleme için kalır. Silme cascade'i eklenmez. ID/rol/ad/firma adı ve active zorunludur; kalan kaynak metin alanları bu temelde nullable'dır, iş validasyonu icat edilmez. `active` başlangıcı true'dur; signup/çalışan oluşturma veya üyelik atama işlemi yoktur.
- **Geçici kapalı erişim:** Üç tabloda RLS açılır, public/anon/authenticated grant'leri geri alınır, izin veren policy yazılmaz. Bu, hazırlık verisini kapalı tutar; Faz 4 rol izin matrisi değildir. `user_metadata.role` otomatik profile rolüne dönüştürülmez. Müşteri üyeliği oluşturma/değiştirme denetimi A-14/Faz 4'te kalır.
- **Seed:** Yedi rol için sekiz sentetik Auth/profile/email-identity kaydı (iki customer), iki kuruluş ve iki üyelik. Yalnız `.invalid` e-posta alanı; her hesaba seed sırasında rastgele parola hash'i, kullanılabilir parola çıktı/depoda yok. Login testi iddiası yoktur. Seed yalnız boş, yeniden oluşturulabilir yerel ortam içindir; doğrudan tekrar çalıştırma idempotent değildir, `db reset --local` düzeni kullanılır.
- **Araç/hedef:** `npx.cmd --yes supabase@2.119.0`; PostgreSQL 17, `peksen_gida_phase3_local`. Başlangıçtaki konteyner engeli 4 Ekim 2026'da giderildi: Docker Desktop Linux motorunda local start ve db reset çıkış 0; migration/seed uygulandı, 19/19 pgTAP PASS ve çıkış 0. Canlı proje linki ve migrationı yapılmadı. Kanıtlar `build/phase3-db-validation-20261004/` altında; bu başarı yalnız üç tabloluk dilimi doğrular.
- **Ertelenenler:** Diğer 22 kaynak tablosu ve eksik varlıklar için A-01–A-13 bağımlılıkları sürer. Özellikle ürün/fiyat/para hassasiyeti, sipariş snapshot/durum, stok gösterimi, ödeme ve GPS şeması yazılmadı. Bu küçük dilim tam Faz 3 tamamlandı anlamına gelmez. A-01–A-13 kapanmaz.

### T-10 — Windows üzerinde Kotlin derleme uyumluluğu

- **Gözlem:** Yeni SDK'nın transitif Android plugin'leri ilk build'de `this and base files have different roots` hatası verdi; Pub cache C: sürücüsünde, depo D: sürücüsündedir. Hata url_launcher_android/shared_preferences_android Kotlin incremental cache kapanışındadır; ilk build çıkış 1.
- **Karar:** `android/gradle.properties` içine `kotlin.incremental=false` eklendi. SDK/Kotlin sürümleri veya global Pub cache taşınmadı, mevcut build kayıtları silinmedi. Bedeli Kotlin derlemesinin daha yavaş olabilmesidir. Aynı sürücü/upstream düzeltmesi doğrulanınca bu geçici ayar kaldırılabilir. [Kotlin derleme ve cache belgeleri](https://kotlinlang.org/docs/gradle-compilation-and-caches.html).
- **Doğrulama:** Son build sonucu PROGRESS'te tutulur; ayarın varlığı başarı kanıtı değildir.

### T-11 — Runtime olmadan doğrulama sınırı ve yerel test hedefi

- **İlk kayıt / karar:** 2026-10-04, runtime kurulmadan önceki görev. Kullanıcı o aşamada Docker Desktop/Podman kurulmasını istemedi; statik inceleme yapılıp veritabanı çalıştırma kabulü **blocked by local Supabase runtime** olarak kaydedildi. Uzak DB'ye bağlanarak veya sahte Auth şemasıyla kabul tamamlanmış gösterilmedi.
- **Komut:** CLI 2.119.0 `--help` çıktısında `db reset --local` ve `test db --local [path]` destekleniyor. Hedefi açık tutmak için test komutu `test db --local supabase/tests/database/identity_foundation_test.sql` olarak belgelenir; reset seed'i atlamaz. Her komutun çıkış kodu hemen kontrol edilir.
- **Sınır:** `db lint --local` çalışan veritabanı gerektirir; SQL dosyalarını runtime olmadan doğruladığı iddia edilmez. Docker Desktop (Linux containers) veya Podman (çalışan machine) kurulup başlatıldıktan sonra mevcut yerel komutlar denenir. İş kuralları, migration ve seed değiştirilmedi. Açık şema kararları kapanmadı.
- **Kaynak:** [CLI test sözleşmesi](https://supabase.com/docs/reference/cli/supabase-test-db), [yerel runtime önkoşulları](https://supabase.com/docs/guides/local-development/cli/getting-started), [seed sırası](https://supabase.com/docs/guides/local-development/seeding-your-database); kurulu sürümün yardım logları `build/phase3-static-validation-20261004/` altında.
- **4 Ekim sonraki doğrulama:** Kullanıcı Docker Desktop'ı açtıktan sonra yerel start/reset/test komutları çalıştırıldı; üçünün çıkışı 0, DB testi 19/19 PASS. Runtime engeli kapandı. Migration/seed/test kodu değiştirilmedi; kalan 22 tablo ve A-01–A-13 açık şema kararları kapanmadı. A-14'teki auth/üyelik operasyonları ve Faz 4 bu kabulün dışında kalır. Son devam adımında yalnız kayıtlar güncellendi; başarılı komutlar tekrarlanmadı.

## Açık kararlar

A-01–A-13 maddelerinin kayıt tarihi **2026-10-02**, A-14'ün kayıt tarihi **2026-10-03**; durumları **Açık — karar verilmedi; uygulama varsayımı yapılmadı**dır. İş kuralı kararları kullanıcı tarafından netleştirilir; şema ve teknik kararlar kaynak kapsamına uygun gerekçeyle kaydedilir. Her madde aşağıda özel kaynağını, neden gerekli olduğunu ve etkilediği fazları belirtir.

### A-01 — İskonto performansı ve eşik anlamı

- **Soru:** “Son üç ay” hangi takvim aralığıdır? Haftalar nasıl sınırlandırılır? Alışverişsiz haftalar hesaba nasıl girer? Teslim edilmiş veya ödenmiş siparişlerden hangileri dahil edilir? İadeler nasıl etkiler? 50K/70K/100K toplamı mı, ortalamayı mı ifade eder?
- **Korunan karar:** Değerler yaklaşık test eşikleridir; kalıcı ticari formül veya kesin eşik yorumu değildir. Hesap backend'dedir, eşikler kod içine gömülmez, müşteri ve Sales Operator aynı müşteri fiyatını görür.
- **Gerekçe:** Müşteri iskonto oranı ve fiyat snapshotları belirsiz bir hesap üzerinden üretilemez.
- **Kaynak:** §5, §37 (iskonto).
- **Etkilediği fazlar:** 3 (şema/seed), 5–7 (fiyat ve sipariş), 10 (referans performans ilişkisi), 16 (regresyon).
- **Durum:** Açık; formül seçilmedi.

### A-02 — Cari limit, borç ve tahsilat etkisi

- **Soru:** Son üç ayın haftalık alışverişlerinden referans cari limit hangi formülle hesaplanır? Borç hangi olayda oluşur? Doğrulanmamış tahsilat borcu/limiti etkiler mi? Kısmi ödeme ve fazla tahsilat nasıl işlenir?
- **Korunan karar:** Açık uyarı, otomatik bloklama olmaması, müşterinin devam edebilmesi ve aşım/onay audit'i değişmez.
- **Gerekçe:** Cari bakiye, sipariş uyarısı ve muhasebe doğrulamasının aynı kayıtlar üzerinde tutarlı olması gerekir.
- **Kaynak:** §6, §19, §37 (cari).
- **Etkilediği fazlar:** 3, 6–7, 10, 15–16.
- **Durum:** Açık; limit veya borç formülü seçilmedi.

### A-03 — Stok rezervasyonu ve hareket zamanları

- **Soru:** Rezervasyon hangi sipariş durumunda başlar? `picked` miktarı `reserved_qty` içinde sayılır mı? `physical_qty` hangi anda azalır? İptal ve iade hangi hareketlerle telafi edilir? `available_qty` hangi kalıcı/türetilmiş gösterimle tutarlı tutulur?
- **Korunan karar:** Kaynaktaki `available_qty = physical_qty - reserved_qty`, `available → reserved`, `reserved → picked`, `picked → dispatched`, `reserved → available`, `received → available` akışları korunur. Aynı rezervasyon iki kez tüketilemez; hareket geçmişi immutable'dır.
- **Gerekçe:** Durum sınırları seçilmeden çift rezervasyon, stok açığı veya çift düşüm riski değerlendirilemez. Bu kayıt, kaynak formülünü yeni bir formülle değiştirmez.
- **Kaynak:** §12–14, §37 (stok).
- **Etkilediği fazlar:** 3, 6–9, 11, 13, 16.
- **Durum:** Açık; rezervasyon başlangıcı/düşüm anı seçilmedi.

### A-04 — Ana sipariş, ödeme ve taleplerin durum eşlemesi

- **Soru:** §9'daki ana durumlar, ödeme durumu ve exception/talep kayıtları nasıl eşlenir? `payment_pending` ödeme boyutu olarak nerede tutulur? `cancel_requested` ve `item_substitution_pending` ana durum mu, devam eden talep mi olur? `failed` ve `returned` sonuçlarına hangi durumdan, hangi yetkiyle geçilir? Her geçişin koşulu ve rol yetkisi nedir?
- **Korunan karar:** Ana kaynak akışı `draft → pending_operator_review → confirmed → preparing → ready_for_dispatch → loaded → out_for_delivery → delivery_pending_confirmation → delivered` olarak korunur. Kaynağın yan durumları (`cancel_requested`, `cancelled`, `item_substitution_pending`, `delivery_disputed`, `payment_pending`, `rejected`) sessizce silinmez veya yeniden yorumlanmaz. Her geçiş history'ye yazılır; yetkisiz doğrudan status UPDATE yasaktır.
- **Gerekçe:** §9 ile §17/§37 farklı durum boyutlarını tarif eder. Tam geçiş matrisi olmadan stok, ödeme, teslimat ve taleplerin etkisi uygulanamaz.
- **Kaynak:** §9–11, §17, §25, §37 (sipariş durumları).
- **Etkilediği fazlar:** 3–4, 6–14, 16.
- **Durum:** Açık; enum veya geçiş matrisi seçilmedi.

### A-05 — “Order Operator” rol eşlemesi ve değişiklik sınırı

- **Soru:** §10'daki onaylayan/reddeden “Order Operator”, §2'deki yedi rolden hangisine veya hangi yetki birleşimine karşılık gelir? “Hazırlanmış” sipariş için doğrudan değişiklik yasağı hangi kesin durumdan başlar? Değişiklik/iptal talebini hangi rol, hangi aşamada sonuçlandırabilir?
- **Korunan karar:** Customer/Sales Operator talep açabilir; hazırlanmış/`loaded`/`out_for_delivery` sipariş doğrudan değiştirilemez; exception/change request gerekir. Sekizinci rol kendiliğinden eklenmez.
- **Gerekçe:** Kaynak rol listesi `order_operator` içermiyor. Bu ifade `sales_operator` veya `manager` kabul edilirse yetki sessizce değiştirilmiş olur.
- **Kaynak:** §2, §10, §24, §26.
- **Etkilediği fazlar:** 3–4, 8–9, 16.
- **Durum:** Açık; rol eşlemesi yapılmadı.

### A-06 — Eksik tablolar ve yabancı anahtar ilişkileri

- **Soru:** Kategoriler, araçlar, çalışan daveti, değişiklik talepleri, bildirim cihaz tokenları ve sayımdaki `warehouse_id` referansı için hangi tablolar/FK ilişkileri kullanılacak? Siparişi iki araca bölme konusunda §15'in “database modelinde desteklenebilir” ifadesi ile §32'nin “Veri modeli hazır” ifadesi arasındaki kesinlik farkı nasıl giderilecek; model hazırlığının kapsamı ve ayrıntıları ne olacak?
- **Korunan karar:** Tek depo, tek satıcı, yedi rol ve müşteri kuruluşunda tek kullanıcı kapsamı korunur. Siparişi iki araca bölme özelliğinin MVP'de kapalı olması her iki kaynak bölümünde kesindir; model hazırlığının kapsamı burada karara bağlanmaz.
- **Gerekçe:** §25'te referans alanlar/iş ihtiyaçları vardır ancak başvurulan bütün varlıklar tanımlı değildir; bu liste uygulanmaya hazır tam migration değildir. §15 ile §32'nin model hazırlığına ilişkin farklı kesinlikteki ifadeleri sessizce tek bir zorunluluğa dönüştürülemez.
- **Kaynak:** §3, §15, §25, §31–32, §37 (veri modeli).
- **Etkilediği fazlar:** 3–4, 5, 8–9, 11, 14, 16.
- **Durum:** Açık; bu maddede listelenen eksik varlıkların tablo/FK tasarımı uygulanmadı. T-09'daki bağımsız kullanıcı–müşteri temeli bu soruları kapatmaz.

### A-07 — Fiyat snapshot alan adları

- **Soru:** §5'teki `discount_rate_snapshot` ve `final_unit_price_snapshot` ile §25'teki `discount_snapshot` ve `final_price_snapshot` hangi kanonik alan adlarında ve anlamlarda birleşecek? İskonto alanının oran, final fiyat alanının birim fiyat anlamı nasıl açık tutulacak?
- **Korunan karar:** `list_price_snapshot` her iki yerde aynıdır; sipariş anındaki liste fiyatı, iskonto oranı ve nihai birim fiyat korunur. Sonraki fiyat değişikliği geçmiş siparişi etkilemez.
- **Gerekçe:** Aynı gereksinimin iki farklı adla yazılması şema, DTO ve hesaplamalarda farklı yorum üretebilir. SPEC her iki kaynak ifadesini görünür tutar.
- **Kaynak:** §5 ve §25 arasındaki alan adı farkı; §33 Faz 5.
- **Etkilediği fazlar:** 3, 5–8, 10, 16.
- **Durum:** Açık; alan adı seçilmedi.

### A-08 — İş kurallarının şemadaki eksik ayrıntıları

- **Soru:** Fiyat değişiklik geçmişi; ödeme tahsil zamanı/notu; mal kabul birim, tedarik/evrak notu ve zamanı; sayım fark nedeni/notu; alternatif item geçmişi; kampanya/hedef müşteri grubu; teslimat kanıtı dosyası ve Manager çözümü mevcut kayıtlarla mı, ek alanlarla mı, ayrı kayıtlarla mı temsil edilecek?
- **Korunan karar:** Bunların iş gereksinimleri zaten kaynakta vardır. Yeni satın alma, ERP veya zorunlu teslimat kanıtı kapsamı eklenmez; `audit_logs` bulunması bu iş verilerinin tamamının nerede yaşayacağını tek başına belirlemez.
- **Gerekçe:** §25 “ana alanlar” tablosudur; örneğin `payments` satırında §19'un istediği tahsil zamanı ve not açıkça bulunmaz. İş kuralları eksik şema nedeniyle düşürülemez.
- **Kaynak:** §4, §11, §13–14, §17–19, §21, §25, §27.
- **Etkilediği fazlar:** 3, 5, 8–10, 13–16.
- **Durum:** Açık; alan/tablo tasarımı yapılmadı.

### A-09 — GPS güncel konum, saklama, silme ve erişim sonu

- **Soru:** Güncel konum ve geçmiş nasıl ayrılacak? Saklama ve silme süreleri nedir? Konum ne zaman “eski” sayılıp uyarı üretir? Müşterinin erişimi sipariş teslimi, durak tamamlanması veya sefer bitişinin hangi anında kesilir? Aynı aktif seferde diğer teslimatlar sürerken tamamlanan müşterinin erişimi nasıl sonlandırılır?
- **Korunan karar:** Müşteri yalnız kendi aktif teslimatının son konumunu görür; sınırsız GPS geçmişi tutulmaz; takip yalnız `out_for_delivery` sırasında yapılır, tamamlanınca paylaşım durur. Geçmiş raporlama ihtiyaçları varsayılmaz.
- **Gerekçe:** §16/§30 davranışı tanımlar fakat çok duraklı seferin tam erişim sınırları ve süreler açık değildir.
- **Kaynak:** §15–16, §26, §30, §37 (GPS).
- **Etkilediği fazlar:** 3–4, 11–12, 16–17.
- **Durum:** Açık; süre veya retention politikası seçilmedi.

### A-10 — Harita sağlayıcısı ve gerçek cihaz izin davranışı

- **Soru:** Faz 12'nin MapLibre yönelimi korunarak harita veri/servis sağlayıcısı hangisi olacak? Android arka plan konum izni, izin reddi/kapatılması, yeniden izin verme, ekran kapalıyken çalışma, bağlantı ve pil değişiminde adaptif aralık hangi platform ayarlarıyla doğrulanacak?
- **Korunan karar:** Harita yalnız araç marker'ı ve son güncelleme zamanını gösterir; rota optimizasyonu/geocoding eklenmez. Başlangıç hedefi 10–15 saniyedir; izin kapanınca Manager uyarılır ve Driver'a tekrar izin akışı sunulur.
- **Gerekçe:** Kaynak MapLibre fazını adlandırır ancak sağlayıcı seçimini ve izin davranışının gerçek cihazda doğrulanmasını uygulama fazına bırakır.
- **Kaynak:** §16, §23, §31, §33 Faz 12, §34, §37 (GPS).
- **Etkilediği fazlar:** 2 (ortam hazırlığı), 12, 14, 16–17.
- **Durum:** Açık; sağlayıcı/platform ayarı seçilmedi veya cihaz testi yapılmadı.

### A-11 — Para, iskonto yuvarlama ve birim dönüşüm hassasiyeti

- **Soru:** TL tutarları hangi hassasiyetle temsil edilir? İskonto hangi noktada ve hangi kuralla yuvarlanır? Birim dönüşümlerinin hassasiyeti nedir; tam sayı sipariş miktarı ile taban birim miktarı arasındaki ilişki nasıl tanımlanır?
- **Korunan karar:** Sipariş miktarı integer'dır; backend fiyatı hesaplar ve snapshotları korur. §24'teki 100 TL / %8 / 92 TL örneği genel yuvarlama veya limit formülü belirlemez.
- **Gerekçe:** Kalem, sipariş toplamı, stok ve tahsilat tutarlarının tutarlılığı açık bir teknik karara bağlıdır.
- **Kaynak:** §4–5, §19, §24–25, §37 (para ve güvenilir işlem).
- **Etkilediği fazlar:** 3, 5–10, 15–16.
- **Durum:** Açık; precision/scale veya yuvarlama kuralı seçilmedi.

### A-12 — Tekrar deneme, idempotency ve transaction kilitleme

- **Soru:** Kritik sipariş, stok ve ödeme işlemlerinde tekrar deneme aynı işlemi nasıl tanıyacak? Idempotency anahtarının kapsamı, ömrü, çakışma ve yinelenen yanıt davranışı ne olacak? Transaction kilitleme/yarış kontrolü nasıl yapılacak? Yinelenen bildirim gönderimi nasıl kontrol edilecek?
- **Korunan karar:** Kritik işlemler backend transaction içindedir; eşzamanlı sipariş stok tutarsızlığı oluşturmaz, rezervasyon iki kez tüketilmez, yinelenen tahsilat çift kayıt üretmez. Bildirim kaybı siparişi geri almaz; yinelenen gönderim kontrol edilir.
- **Gerekçe:** Bu sonuçlar kaynak kabul ölçütleridir; kaynak uygulanacak kilit veya anahtar tasarımını seçmemiştir.
- **Kaynak:** §8, §12, §29, §33 Faz 9–10 ve 14, §36–37.
- **Etkilediği fazlar:** 3, 5–10, 13–14, 16.
- **Durum:** Açık; idempotency veya kilitleme mekanizması seçilmedi.

### A-13 — Rol yetkilerinin uygulama ayrıntıları

- **Soru:** Sales Operator için “operasyon için gerekli” müşteri/sipariş erişiminin kayıt sınırı nedir? İstisnai tahsilat yapabilen “başka yetkili çalışan” hangi roller/yetkilerle belirlenir? Primary ve assistant driver'ın aynı seferde GPS, durak sırası ve teslimat onayı yetkileri nasıl paylaşılır? İki driver bulunan siparişte hangi Driver puanlanır?
- **Korunan karar:** Yedi rol, müşteriler arası veri izolasyonu, driver'ın atanmış run/stop/order/GPS sınırı ve Owner-only maaş/prim kuralı korunur. Driver normalde ödeme almaz; müşteri yalnız Driver'ı puanlar ve sipariş başına tek puan verir.
- **Gerekçe:** Kaynak genel yetkileri ve primary/assistant desteğini belirler; bütün satır düzeyi izinlerin ve çift driver davranışlarının matrisi verilmemiştir.
- **Kaynak:** §2, §7, §15, §19–20, §25–26, §33 Faz 4, 11 ve 13.
- **Etkilediği fazlar:** 3–4, 7, 10–13, 16.
- **Durum:** Açık; yeni yetki verilmedi.

### A-14 — Auth başlangıcı sonrasında üyelik ve oturum ayrıntıları

- **Tarih / durum:** 2026-10-03; açık, Faz 4'e başlanmadı.
- **Sorular:** Kullanıcı–kuruluş üyeliğinin oluşturulması/değiştirilmesi hangi transaction ile yürütülecek? Bir kullanıcının birden fazla kuruluş ilişkisi, inactive üyelik geçişleri ve hesap silme/saklama kuralları nedir? Kalıcı mobil oturum saklaması, yenileme, çıkış/iptal ve gerçek e-posta doğrulama/davet ayarları nasıl uygulanacak?
- **Korunan karar:** Kuruluş başına MVP tek kullanıcı, müşteri kayıt sonrası doğrudan aktif, çalışanı Owner/Manager oluşturur, roller DB'dedir. E-posta doğrulamasıyla işletme aktifliği sessizce eşitlenmez. Client metadata'sından yetki türetilmez.
- **Etki:** Şimdiki temel kayıt yapısı bu operasyonları sağlamaz; yerel signup hazırlık boyunca kapalıdır. Gerçek giriş, güvenli oturum ve üyelik denetimi Faz 4 kabulü altında tamamlanır. A-05/A-13 rol soruları ayrıca açık kalır.

## Kararların kapatılması ve sonraki adım

Bir açık madde kapatılırken ID korunur; kararın tarihi, kesin cevabı, gerekçesi, kaynak etkisi, gerekiyorsa reddedilen seçenekleri ve etkilediği kabul ölçütleri kaydedilir. Sonra SPEC/PLAN/TESTING/PROGRESS birlikte tutarlı hale getirilir. DOCX ve Markdown farklılaşırsa fark kullanıcıya bildirilip burada kaydedilir; kaynak sessizce düzeltilmez (§35–36).

Faz 2'nin iskelet, tema, routing, ortak giriş/yükleniyor/boş/hata durumları ve yedi rol menüsü bu formülleri seçmeden hazırlanabilir. Şema, RLS, fiyat, sipariş, rezervasyon, ödeme ve GPS uygulaması ise ilgili açık maddeler çözülmeden tamamlandı kabul edilemez.

## 4 Ekim 2026 — kullanıcı tarafından onaylanan iş kararları

Kaynak: kullanıcının bu görevde eklediği “Faz 3 açık iş kararları aşağıdaki şekilde onaylandı” metni. B-01–B-09 **onaylı iş kararıdır**; T-12 bunları taşıyan teknik şema seçimidir. Bu onay gerçek iş servislerini Faz 3'e taşımaz: PLAN'daki Faz 3 migration/seed kabulü ile sonraki fazların işlem/izin kabulü ayrıdır.

### B-01 — Sipariş, rezervasyon ve onay

Normal sipariş `submitted` olur ve rezervasyon yapar. Cari limit aşımı, yetersiz stok veya özel/riskli sipariş Manager/Owner onayına gider; onaydan sonra `submitted`, ret halinde `rejected` olur. Draft ve rejected rezervasyon üretmez. Customer/Sales Operator submitted siparişi iptal edebilir; picking ve sonrası iptal Manager/Owner onayı ister. Delivered sonrası iptal yerine iade/uyuşmazlık vardır. Alternatif teklif asıl kalemi doğrudan değiştirmez; ürün/miktar değişimi müşteri onayı gerektirir. Operasyon durumu `orders.status`, ödeme görünümü `payment_status` olarak ayrılır; ödeme kayıtları esas, payment_status senkron önbellektir.

**Kaynak revizyonu:** K-05/A-02'nin uyarı sonrası müşteri tercihiyle koşulsuz devam davranışı yerine yönetici kararı gerekir. Eski `pending_operator_review/confirmed/preparing/ready_for_dispatch` adları teknik şemada `pending_approval/submitted/picking/picked` olarak karşılanır; `assigned` eklenir, `loaded` ve teslimat onayı/uyuşmazlığı korunur. Ödeme ve iptal/alternatif talepleri ana status dışında tutulur. Bu ad eşlemesi tam geçiş matrisi değildir.

### B-02 — Stok

`available_qty = physical_qty - reserved_qty`. Submitted rezervi artırır; picked fiziksel ve rezerve miktarı aynı taban miktar kadar azaltır, kalemin `picked_qty` değerini ve hareket geçmişini artırır. Kısmi picking vardır; picked satış miktarı sipariş miktarını aşamaz. İptal/iade/depoya dönüş telafi hareketi üretir. Depocunun sayım farkı Manager/Owner onayından sonra hareketle uygulanır. Kaynaktaki fiziksel düşüm zamanı bu açık onayla picked olarak kesinleşmiştir.

### B-03 — Cari, tahsilat ve vade

Gerçek borç müşteri onaylı teslimatta veya teslimatı kesinleştiren Manager/Owner çözümünde oluşur; tek driver girişi yeterli değildir. Tahsilat girildiğinde borç düşer. Tahsilat durumları `recorded`, `verified`, `disputed`, `cancelled`; yanlış kayıt silinmez, düzeltme/telafi eklenir. Kısmi ödeme kabul, ilgili siparişin kalan borcundan fazla ödeme ret edilir. Genel avans/alacak bakiyesi yoktur.

Cari limit kontrolündeki projected exposure, teslim edilmiş ödenmemiş borç ile `submitted/picking/picked/assigned/out_for_delivery` siparişlerin beklenen tutarlarını kapsar; kesin borç değildir. Aşım Manager/Owner onayı/ret ve audit/history üretir. `customers.payment_due_days` nullable müşteri özel vadesidir; yoksa sistem varsayılanı kullanılır. `due_date = delivered_at + seçilen payment_due_days`; vadesi geçmiş ve kapanmamış borç `overdue` olur. Varsayılan gün sayısı ve cari limit hesap formülü **onayda yoktur**, seed'e yazılmaz.

### B-04 — Takvim çeyreği iskontosu

Q1 Ocak–Mart, Q2 Nisan–Haziran, Q3 Temmuz–Eylül, Q4 Ekim–Aralık kullanılır. Müşteri onaylı teslim edilmiş siparişlerin iadeden arındırılmış net toplam tutarı eşik ölçüsüdür. İade miktarı/tutarı düşülür; teslim edilmemiş, cancelled, rejected veya tamamen iade edilmiş siparişler hariçtir. Ödenmiş olma şartı, kategori/miktar iskontosu yoktur. Çeyrek sonunda öneri oluşturulur; Manager/Owner onayından sonra customer_pricing'e yazılır ve sonraki çeyrekte uygulanır. Sessiz otomatik fiyat değişimi yoktur. Sipariş fiyat/iskonto snapshotları sonraki iskonto değişiminden etkilenmez. Eski haftalık/üç aylık belirsizlik bu takvim/toplam kararıyla değiştirilmiştir.

### B-05 — Para ve snapshot

Tüm para integer kuruştur; alanlarda `_kurus` son eki kullanılır. Float/double yoktur. Yuvarlama kalem toplamında yapılır, sipariş toplamı yuvarlanmış kalemlerin toplamıdır. Kanonik kalem alanları `unit_price_kurus`, `discount_rate_snapshot`, `final_unit_price_kurus`, `line_total_kurus` olur; hepsi sipariş anının snapshotıdır. İskonto oranı para değildir. Kuruşun altında kalan final birim fiyatının temsili ve eşit uzaklıktaki yuvarlama yönü onaylanmadı; hesaplayıcı yazılmaz.

### B-06 — Sefer ve teslimat

Bir sipariş aynı anda tek sefer/araca bağlıdır; kalem bölme yoktur. Eski atama kapanır, yeni atama geçmişe bağlanır; iki aktif stop yasaktır. Primary ve assistant driver teslimat, tahsilat girişi ve teslimat onayı başlatabilir; gerçek aktör kaydedilir, primary sadece varsayılan sorumludur. Bu karar K-09/A-13'teki önceki driver tahsilat sınırını genişletir. Normal tamamlanma driver girişi + müşteri onayıdır; eksik/ret/uyuşmazlık Manager **veya Owner** çözümündedir. GPS yalnız Faz 12 iskeletidir; konum takibi, saklama/izin/sağlayıcı ve konuma bağlı iş kuralı bu faza eklenmez.

### B-07 — Kategori, ürün fiyatı ve birim

Ürün tek kategori FK'sına bağlıdır. Güncel fiyat products üzerindedir; ayrı product_price_history eski/yeni kuruş, aktör, zaman ve gerekçe tutar. Audit bunun yerine geçmez. Her ürünün taban stok birimi ve product_units satış birimleri/dönüşümleri bulunur. Sipariş miktarı integer, taban stok etkisi dönüşüm katsayısıyladır. Float katsayı yoktur; güvenli decimal veya oran gösterimine izin verilmiştir.

### B-08 — Yardımcı kayıtlar ve kapsam

Notifications yalnız iskelettir; cihaz tokenı tutulmaz. Push, Firebase/APNs, tekrar gönderme Faz 10/sonrası içindir; PLAN'daki FCM Faz 14 işi başlatılmaz. Audit yalnız fiyat, stok/sayım onayı, sipariş durumu, alternatif kabul/ret, tahsilat ekleme/düzeltme/iptal, cari onay/ret, teslimat uyuşmazlığı/çözümü ve rol/yetki değişimidir. Kaynağın daha geniş audit örnekleri bu izin listesine sessizce eklenmez. app_settings JSON key/value, izinli anahtar ve belgeli tip/aralık kullanır. Ticari eşik gömülmez. Tek depo referansı kullanılır; inventory/count/movement warehouse FK taşır. Araç plaka/aktiflik/açıklama kaydıdır; her sefer tek araç FK'sı taşır.

### B-09 — İşlem tekrarı

Stok hareketi, tahsilat, teslimat onayı, durum geçişi, fiyat değişikliği ve cari limit kararı operation_key gerektirir. Aynı anahtarla aynı kritik işlem iki kez kaydedilemez. Veritabanı kısıtı zorunludur; buton kilidi yeterli değildir.

### T-12 — Onaylı kararların Faz 3 şema karşılığı

- **Sürümleme:** İlk identity migration, seed ve 19 test korunur. Yeni `20261004000100_business_foundation.sql` 22 kaynak tablo + 10 yardımcı tablo kurar; customers'a nullable credit_limit_kurus/payment_due_days ekler. Toplam 35 public tablo. Yeni seed, config'te identity seed'inden sonra çalışır. Flutter kodu/dependency değiştirilmez.
- **Para/birim:** Para bigint; oran exact numeric 0–1; taban stok/dönüşüm sınırsız ölçekli exact numeric ve sonlu/nonnegative kontrolü kullanır. Sipariş/picked miktarı integer satış birimidir; conversion snapshot geçmiş stok etkisini korur. Sonsuz/NaN ve sıfır dönüşüm reddedilir. Ticari hassasiyet/yuvarlama uygulanmaz.
- **Şema sınırı:** DDL, FK, check/unique, üretilen stok/sayım farkı ve geçmiş koruma trigger'ları vardır. Sipariş oluşturma/rezervasyon/picking, borç/exposure/vade hesaplama, fazla ödeme denetleyen kilitli transaction, payment_status senkronizasyonu, çeyrek önerisi veya audit otomasyonu **yoktur**. Bunlar Faz 5–13 işlemleridir; ileride bu garantileri sağlayan tek backend transaction ile yazılmalıdır. Mevcut tüm tablolar RLS açık ve anon/authenticated/PUBLIC grant kapalıdır; izin veren policy/RPC eklenmedi.
- **Tekrar koruması:** Her kritik kayıt türünde UUID `operation_key` NOT NULL UNIQUE; bekleyen kararların key'i yoktur, sonuçlanan kararda zorunlu ve sabittir. Anahtar kapsamı tablo/eylem türüdür. Aynı iş transaction'ı farklı türlerde aynı correlation key'i kullanabilir; tek türde çok satırlı iş için her alt işleme kararlı ayrı key gerekir. Tekrar INSERT 23505 ile reddedilir; otomatik başarılı replay yanıtı üretilmez. Retention/TTL silmesi yoktur. Değişmiş payload ve sonuç döndürme API sözleşmesi R-06'dır.
- **Geçmiş:** Stok/fiyat/status/audit/teslimat olayları ve tahsilat düzeltmeleri append-only'dir. Tahsilatın tutarı, siparişi, aktörü, yöntemi, zamanı ve key'i değiştirilemez/silinemez. Tamamlanmış kararlar immutable'dır. Kapalı atamalar değiştirilemez, hiçbir atama silinmez; yeni atama eski satıra bağlanır. Kalem fiyat/oran/birim snapshotı yerinde değişmez; aynı miktarın satır tutarı da yeniden fiyatlanamaz. Gelecek onaylı kalem revizyonunun temsil ayrıntısı R-03'te kalır.
- **Durum adları:** `order_state` domain'i yalnız bilinen operasyon adlarını sınırlar; geçiş yetkisi/matrisi uygulamaz. Payment cache adları `not_due/unpaid/partial/paid/overdue/disputed`; tahsilat verification_status değerlerinden ayrıdır. Sefer/durak status alanlarının tam sözlüğü R-03 nedeniyle text iskeletidir; yeni davranış varsayılmaz.
- **Yardımcı tablolar:** categories, warehouses, vehicles, product_price_history, pricing_proposals, order_approvals, order_change_requests, order_returns, order_return_items, payment_adjustments. Return kalemi composite FK ile aynı siparişe bağlıdır; kümülatif iade miktarı/tutarı işlemin kilitli kontrolünü gerektirir. Ayrı cari ledger veya genel müşteri avansı icat edilmedi.
- **Teslimat olayı:** delivery_confirmations append-only driver/customer/dispute/resolution olaylarıdır. Aktör/key her olayda vardır; driver olayı finalizes_delivery olamaz. Müşteri onayı ve Manager/Owner çözüm yetkisi, atanmış driver kontrolü ve çift onay koşulu gelecekteki yetkili transaction'da denetlenir; actor FK tek başına yetki kanıtı değildir.
- **Ayar sözleşmesi:** Şimdilik yalnız `default_payment_due_days`: JSON integer sayı, 0..2147483647 gün (integer saklama sınırı, ticari üst sınır değil), müşteri override'ı yokken vade gün sayısı. Eksik ayarda gelecek servis açık yapılandırma hatası vermeli; gizli fallback seçilmez. Anahtar/değer veya müşteri vadesi seed'de doldurulmaz. Yeni anahtar ancak migration+tip/aralık/açıklama+test ile eklenir.
- **Seed:** Orijinal sekiz/yedi rol ve iki müşteri korunur. Sentetik ürün/birim, sıfır stoklu ürün, kısmi picking, tutarlı hareket toplamları, taslak/onay isteği, müşteri onaylı teslimat ve kısmi ödeme örnekleri vardır. Rakamlar fixture'dır; iskonto kuralı pasiftir. GPS/ayar/düzeltme tablosu kasıtlı boştur; fixture'ların doğrudan SQL ile yüklenmesi iş servislerinin çalıştığını kanıtlamaz.

### Eski açık kararların güncel karşılığı

| Eski kayıt | Bu onayla kapanan bölüm | Kalan bağımlılık |
| --- | --- | --- |
| A-01 | Takvim çeyreği, net toplam, ödeme şartı olmaması, onay/sonraki çeyrek | R-01 |
| A-02 | Borç olayı, recorded tahsilat etkisi, kısmi/fazla ödeme, onay, vade ve exposure | R-02 |
| A-03 | submitted rezervasyonu, picked fiziksel düşüm, kısmi toplama, telafi/sayım | R-03/R-06 işlem ayrıntıları |
| A-04/A-05 | Lojistik/ödeme/talep ayrımı; risk ve picking sonrası iptalde Manager/Owner | R-03; tüm eski “Order Operator” kullanımlarına genel yetki verilmedi |
| A-06/A-08 | 22 tablo ve 10 yardımcı, FK, fiyat/ödeme/sayım/atama geçmişi | Davet Faz 4; kampanya/kanıt/push ayrıntıları ilgili sonraki fazlarda |
| A-07 | Kanonik snapshot alanları B-05 | Kapanan ad kararı; hesap yöntemi R-04 |
| A-09/A-10 | GPS'nin yalnız iskelet olması kesin | Konum izin/retention/sağlayıcı Faz 12'de açık |
| A-11 | Integer kuruş, kalem yuvarlama noktası, exact decimal dönüşüm | R-04 |
| A-12 | DB'de zorunlu unique operation_key | R-06 |
| A-13 | İki atanmış driver'ın işlem yapabilmesi, gerçek aktör | R-05 ve Faz 4 satır erişimi |
| A-14 | Bu görevde değiştirilmedi | Gerçek Auth/üyelik/oturum Faz 4 |

### Kalan açık kararlar — uygulanmış varsayım değildir

| ID | Eksik kesin karar | Uygulamaya etkisi |
| --- | --- | --- |
| R-01 | Çeyrek sınırının iş saat dilimi; sonraki çeyrekte gelen iadelerin hangi dönemi düzelttiği; Manager/Owner çözümüyle teslim edilmiş ancak customer onayı olmayan siparişin iskonto uygunluğu; gerçek eşikler ve onay zamanının gecikmesi | Çeyrek hesaplama/öneri servisi öncesi gerekir. Seed pasif örneği ticari kural değildir. |
| R-02 | Cari limit üretme formülü/değeri; sistem varsayılan vade gün sayısı; disputed/cancelled tahsilatın telafi zamanlaması ve muhasebe tutarı; exposure listesinde loaded/onay bekleyen teslimatın durumu | Cari ve ödeme transaction'ı uygulanmaz; onayda sayılan exposure durumlarına kendiliğinden yenisi eklenmez. |
| R-03 | Tam sipariş/sefer/durak geçiş matrisi; failed/returned eşlemesi; kalem değişiklik geçmişi; yetersiz stok onayı sonrası rezervasyon nasıl sağlanır; picking sonrası iptal/iade/eksik teslim telafisinin kabul zamanı | Faz 8–13 iş servisleri öncesi netleşmeli. Şema hiçbir stok yokken rezervasyon zorlamaz. |
| R-04 | **9 Ekim F5-01 ile kapandı:** kalem toplamında en yakın kuruş/tam yarımda yukarı; ayrı exact numeric birim snapshotı, eski bigint alanlar yalnız uyumluluk gösterimi. | Faz 5 hesap ve snapshot testleri uygulanmıştır; eski tutarlar yeniden hesaplanmaz. |
| R-05 | İki driver'dan hangisinin puanlandığı; satışçı erişim sınırı; diğer istisnai tahsil yetkileri; tüm işlem/rol matrisi | FK aktörü kaydeder, yetki sağlamaz. Faz 4/11/13 kararlarıdır. |
| R-06 | Transaction kilit sırası ve yarış kontrolü; aynı key/farklı payload cevabı, başarılı replay yanıtı, çok kalemli alt işlem key türetimi | Unique/immutable DB temeli var; eşzamanlı bakiye/rezervasyon güvenliği veya tam replay API'si iddia edilmez. |
| R-07 | Kampanya/iskonto/maaş değişimi gibi eski kaynak audit örnekleri, yeni sınırlı audit listesine ileride alınacak mı; kanıt dosyası saklama ilişkileri | Bu görevde izin listesi genişletilmez; Storage/kampanya/Owner modülleri öncesi karar gerekir. |

Bu soruların devam etmesi **migration + seed** kabulü ile gerçek iş akışı kabulünün ayrı olduğu gerçeğini değiştirmez. R-01–R-07 ilgili hesap/işlem fazının önkoşuludur; Phase 3 SQL testleri bu davranışları uygulanmış veya onaylanmış saymaz.

### T-13 — Faz 3 kapanış incelemesinin yedi bütünlük düzeltmesi

**Tarih/onay:** 2026-10-04; kullanıcı yedi P2 bulgunun migration/constraint/trigger düzeyinde giderilmesini ve negatif regresyonlarını açıkça istedi. Yeni `20261004000200_phase3_integrity_fixes.sql` kullanılır; ilk iki migration ve iki seed korunur. Tablo sayısı 35'tir. Yeni iş durumu, formül, RPC veya izin politikası eklenmez.

| Bulgu | Uygulanan teknik karar | Regresyon |
| --- | --- | --- |
| 1. Onaylı sayım kalemleri | stock_count_items INSERT/UPDATE/DELETE trigger'ı ilgili başlıkları UUID sırasıyla FOR UPDATE kilitler; eski veya yeni parent approved ise işlemi reddeder. Kalemi başka sayıma taşıma da kapsamda. Bekleyen sayım düzenlenebilir. | 7 test: bekleyen düzenleme/onay pozitif; onaylı kalem ekleme/değiştirme/silme ve iki yönde taşıma negatif. |
| 2. Sefer aracı/geçmiş | delivery_runs.vehicle_assignment_locked yalnız trigger'ların yönettiği kalıcı teknik kilittir. ended_at kaydı veya ilk stop ilişkisinden sonra araç değişemez. Mevcut geçmiş backfill edilir; yeni stop sonrası parent UPDATE, eşzamanlı araç değişimiyle aynı satır kilidini kullanır. ended_at/flag temizleme geçmiş kilidini kaldıramaz. | 9 test: kullanılmamış sefer/no-op pozitif; kapalı, geçmişli, ilk ataması yapılmış veya yeniden açılmış seferde araç değişimi negatif; ilk stop/kilit korunması doğrulanır. |
| 3. Teslimat olay bayrakları | driver_confirmed yalnız ve bütün driver olaylarında, customer_confirmed yalnız ve bütün customer olaylarında true olur. Böylece boş/false customer kaydı tek onay slotunu tüketemez. Mevcut finalizes_delivery kısıtı customer/resolution dışını reddetmeye devam eder. | 10 test: geçersiz tür/bayrak/finalization kombinasyonları; reddedilen false kaydın slot/key'ini gerçek onayın kullanabilmesi; geçerli driver/customer/resolution kayıtları. |
| 4. Kalemin sipariş bağı | order_items.order_id değişirse trigger 23514 verir; aynı değeri yazma kabul edilir. Mevcut fiyat/birim snapshot trigger'ı korunur. | 3 test: aynı ve farklı müşterinin başka siparişine taşıma reddi, no-op kabulü. |
| 5. Değişiklik talebi karar kanıtı | approved/rejected order_change_requests için decided_by ve decided_at birlikte zorunlu CHECK. Tamamlanmış kaydı mevcut immutable karar trigger'ı korur. | 7 test: eksik aktör/zamanla INSERT ve UPDATE reddi; geçerli karar; karar kanıtının sonradan silinememesi. |
| 6. Önceki durak bağı | previous_stop_id/order_id composite FK, aynı siparişe bağlar. CHECK kendisine bağlanmayı reddeder. Aktif stop unique index'i ve atama geçmişi trigger'ı korunur. | 3 test: başka sipariş ve self-link reddi, aynı siparişin önceki durağı kabulü. |
| 7. Stok hareketi dayanağı | stock_count_id/product_id, stock_count_items PK'sına; compensates_movement_id/product_id, aynı ürünün inventory_movements kaydına composite FK ile bağlanır. | 4 test: yanlış ürünün sayımına/telafi hareketine bağlanma reddi; doğru ürün bağları kabulü. |

**Sınırlar:** Seferin durum sözlüğü halen R-03'tür; yeni status adı veya kapanış geçişi seçilmedi. Araç kilidi için kayıtlı bitiş göstergesi `ended_at` ve atama geçmişi kullanılır. Flag bir yetki alanı değildir; client grant açılmaz ve false yazılması kilidi çözmez. Tür/bayrak bütünlüğü gerçek driver/customer/Manager/Owner yetkisi veya iki taraflı teslimat transaction'ı sağlamaz. Önceki durak zaman sırası, sayım onayından stok uygulaması ve telafi tutarı formülü bu migration'da seçilmez. R-01–R-07/A-14 açık kalır; Faz 4'e geçilmez.

**Koruma/doğrulama:** 97 eski assertion aynen korunur, yeni 43 assertion aynı test dosyasının sonuna eklenir ve transaction sonunda rollback olur. Seed değiştirilmez. Identity 19/19 ve business 140/140 PASS, reset/test komutları çıkış 0. Satır kilidi kullanımı yapısal korumadır; çok oturumlu yarış testi bu görevde çalıştırılmış sayılmaz. Flutter ve son komut sonuçları PROGRESS/TESTING'dedir.

## Faz 4 — 6 Ekim 2026 onayları ve uygulama sınırları

Bu bölüm önceki Faz 3'ün “policy yok / gerçek giriş kapalı” kayıtlarından önce gelir. Kullanıcı Faz 3'ü commit edip kabul etmiş, Faz 4 Auth + RBAC + RLS çalışmasını istemiştir. B-01–B-09 hesap/iş akışı kuralları değiştirilmez.

### F4-01 — Onaylı rol atama ve müşteri kapsamı

- **Owner:** Yedi rolün tamamını atama yetkisi vardır. **Manager:** yalnız customer, sales_operator, warehouse ve driver atayabilir; Accounting/Manager/Owner atayamaz, bu ayrıcalıklı hesapları alt role indirerek de yönetimi ele geçiremez. Assistant driver ayrı bir rol değildir; delivery_runs.assistant_driver_id ile atanmış driver'dır.
- **Sales Operator:** yalnız kendisine atanmış **veya kendisinin oluşturduğu** müşteriyi okuyup yönetebilir. Owner/Manager tüm müşterileri görebilir. Atama/oluşturucu bilgisi istemci metadata'sından alınmaz. created_by değişmez; assigned_sales_operator_id yalnız denetlenen Owner/Manager RPC'siyle değişir. İlk aşamada tek atanmış satışçı sütunu vardır; birden fazla eşzamanlı satışçı gereksinimi onaylanmış değildir.
- **Accounting:** müşteri operasyonlarını yönetemez. Ham customers tablosu kapalıdır; accounting_customers() yalnız id, company_name, credit_limit_kurus, payment_due_days döndürür. Adres/not/vergi/iletişim alanları açılmadı.
- **Atanmamış müşteri:** Sales tarafından oluşturulmuş kayıt, açık “oluşturduğu müşteriler” onayı nedeniyle o Sales'a görünür. Ne Sales oluşturucusu ne ataması bulunan kayıtlar personel tarafında yalnız Owner/Manager'a görünür. Müşterinin kendi kuruluşuna erişimi korunur. Accounting'in atanmamış müşterinin cari kaydını görüp göremeyeceği açık kalır; istisna uygulanmadı.
- **Kaynak:** Kullanıcının 6 Ekim devam mesajı; önceki A-13/R-05 satış kapsamı ve Manager rol atama belirsizliğinin bu kısmını kapatır. Diğer R-05 iş yetkileri kapanmaz.

### F4-02 — Teknik uygulama

- Mevcut 20261004000300_auth_read_access.sql tamamlanır; ilk üç migration ve iki seed değiştirilmez. 35 tablo korunur. customers'a nullable created_by ve assigned_sales_operator_id FK/index'leri eklenir; geçmiş kayıtların oluşturucusu/ataması tahmin edilmez.
- private şeması API'ye açılmaz. Sabit boş search_path kullanan, yalnız authenticated tarafından çalıştırılabilen SECURITY DEFINER yardımcıları DB'deki aktif profili, aktif müşteri/üyeliği, Sales ilişkisini ve sefer atamasını denetler. JWT'nin user_metadata.role değeri yetki sağlamaz. Grant tek başına satır erişimi değildir; RLS her sorguda canlı DB rolünü denetler.
- Anonim erişim ve tüm doğrudan tablo yazmaları kapalıdır. Owner bütün tablolarda okur; Manager operasyonel tablolarda okur ancak maaş, audit, ayarlar ve başkasının bildirim kutusu kapalıdır. Müşteri kendi kuruluşu/üyeliği/fiyatı/sipariş/kalem/history/ödemesi/puanı ve kendi bildirimini okur. Sales müşteri ilişkisi üzerinden müşteri/fiyat/sipariş/kalem/history/ödeme okur. Driver iki atama alanından biriyle kendi run/stop/vehicle/GPS kayıtlarını; yalnız açık durak ve bitmemiş sefer üzerinden sipariş/kalem/history okur. Müşteriye ham GPS geçmişi açılmaz.
- Sınırlı yazma girişleri: assign_account_role, create_customer_record, assign_customer_sales, update_customer_contact, link_customer_account. Bunlar Auth credential oluşturmaz; mevcut Auth UUID'sine profil/rol ve kuruluş üyeliği hazırlar. Manager/Owner yetkisi eski **ve yeni** rol üzerinde kontrol edilir. Profil/üyelik oluşturma hatasında transaction bütünüyle geri alınır. Rol ve atama/üyelik yetki değişimleri audit'e yazılır; contact düzenlemesi ticari audit allowlist'ini genişletmez.
- Sales contact yönetimi firma/yetkili kişi/telefon/e-posta/adres ile sınırlı; credit/active/vergi/not/atama değişikliği verilmedi. Owner/Manager create/link/role yetkileri RPC'dedir; ham INSERT/UPDATE/DELETE açılmaz. Sipariş/stok/fiyat/ödeme iş servisleri eklenmedi.
- Flutter AccountRepository gerçek signInWithPassword, local-scope signOut ve RLS'li profil okuması sağlar. /account oturumla korunur; rol query parametresi veya debug seçiminden gelmez. Hata/yükleme/pasif profil eski rolü ekranda tutmaz; uygulamaya dönüşte profil yenilenir. RLS yetkinin asıl uygulama noktasıdır.
- Oturum yalnız bellekte, token yenileme açık; kalıcı storage ve auth deep link kapalı. Uygulama kapanınca yeniden giriş gerekir. Giriş başarısızlığı sabit Türkçe hata verir, parola gönderim sonunda temizlenir. .env örneği boş kalır; login için yalnız public anahtar gerekir. Debug önizlemesi bağımsızdır.
- Windows 6 Ekim kontrolünde 54310–54409 aralığını ayırdığı için reset port 54322 üzerinde çıkış 1 verdi. Yalnız proje config'i API 55321 / DB 55322 / shadow 55320 olarak değişti; Windows ağ politikası değiştirilmedi. Android debug adresi http://10.0.2.2:55321, host http://127.0.0.1:55321.
- Phase 3 test sayıları 19 ve 140 korunur. Identity'nin üç, business'ın üç eski erişim beklentisi “policy/grant yok” yerine izinli SELECT / anonim kapalı / JWT subjectsiz boş sonuç / doğrudan yazma kapalı olarak güncellendi. Hiçbir şema/bütünlük regresyonu kaldırılmadı. Faz 4 ayrıca gerçek JWT subject + authenticated/anon rollerinde sınanır.
- Teknik kaynak: [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [Auth sign out](https://supabase.com/docs/guides/auth/signout). Local çıkış refresh token'ı iptal eder; alınmış access token'ın süresi dolmadan her koşulda anında geçersiz olduğu iddia edilmez. DB active/rol/üyelik denetimleri mevcut token'la da uygulanır.

### F4-03 — Açık kalan kabul ve kararlar

**Faz 4'ün tamamı kapanmadı.** Mevcut hesapla giriş ve sınırlı RBAC/RLS temeli, self-signup ve çalışan daveti yaşam döngüsünün yerine geçmez.

**7 Ekim güncellemesi:** Aşağıdaki önceki açık karar tablosunun müşteri–çalışan dönüşümü ve Accounting/Warehouse okuma kapsamı F4-04 ile karara bağlandı ve uygulandı. Genel üyelik transferi/yeniden etkinleştirme, kayıt/davet ve kalıcı oturum tamamlanmış değildir. Önceki dört alanlı Accounting ve Warehouse erişimi kapalı açıklamaları tarihçedir.

| Açık konu | Bu tur uygulanan güvenli sınır / sonraki iş |
| --- | --- |
| Müşteri kendi e-posta/şifre kaydı; çalışan Auth oluşturma/davet kanalı ve ilk Owner | Mobil Admin anahtarı yok. Yerel signup halen kapalı. Mevcut Auth identity'lerine rol/üyelik provisioning RPC'si var; server-only Admin API, davet/kayıt arayüzü ve doğrulama/kurtarma akışı tamamlanmalı. Kaynakta müşteri doğrudan aktif şartı korunur; email doğrulaması ile active birleştirilmez. |
| Üyelik transferi, çok kuruluş, pasif üyelik yeniden açma, customer ↔ çalışan dönüşümü | Mevcut üyeliği başka kuruluşa taşıma veya pasif üyeliği açma ve müşteri/çalışan rol dönüşümü reddedilir. Owner'ın rol atama yetkisi onaylıdır; bu dönüşümün bağlı müşteri/finans kayıtlarına etkisi onaylı değildir. A-14 kapsamında ayrı transaction tasarlanmalı. |
| Accounting alanları/atanmamış müşterinin cari görünürlüğü | Dört alanlık asgari projection; atanmamış istisna kapalı. Tam onaylı alan listesi ve cari/tahsilat okuma API'leri ayrıca belirlenmeli. |
| Sales'ın birden fazla ataması, oluşturucu erişiminin geri alınması, diğer müşteri düzenleme alanları | Tek atama ve kalıcı oluşturucu koşulu; bundan daha geniş yetki yok. Bütün müşteri operasyonlarının hazır olduğu iddia edilmez. |
| Warehouse/Accounting iş satırı/alan matrisi; eski Order Operator eşlemesi | Kendi profil/bildirimleri dışında Warehouse iş erişimi açılmadı; Accounting yalnız minimal projection okur. İlgili sipariş/finans/stok servisinden önce erişim matrisi tamamlanmalı. |
| Mobil kalıcı oturum, davet/kurtarma deep link, hesap kapatma/saklama | Bellek oturumu/refresh/local logout çalışır. Kalıcı saklama ve hesap yaşam döngüsü A-14'te açık; üretim kabulü yok. |
| GPS müşteri son-konum ve retention; iş transaction yarışları | Faz 12 ve ilgili işlem fazları. Bu auth çalışması hesap/formül veya transaction güvenliği kabulü değildir. |

Faz 5'e geçilmez. Sonraki somut iş, Faz 4 içinde kayıt/davet ve kalan alan/üyelik sözleşmesini kararlaştırıp uçtan uca onboarding akışını tamamlamaktır.

### F4-04 — Onaylı dönüşüm ve Accounting/Warehouse okuma sınırları

**Onay:** Kullanıcının üç açık yanıtı ve 6–7 Ekim 2026 devam talimatı. Bu bölüm F4-01–F4-03'ün çelişen eski okuma/dönüşüm sınırlarından önce gelir. Yeni migration `20261006000100_account_conversion_scoped_reads.sql`; önceki dört migration, 35 tablo ve iki seed korunur. Yalnız bu üç karar uygulanır; kayıt/davet veya Faz 5 iş ekranı eklenmez.

| Karar | Uygulanan sözleşme |
| --- | --- |
| Müşteri ↔ çalışan | `convert_account_role(target_user, target_role, target_customer)` yalnız aktif Owner'a açıktır. Mevcut Auth/profil üzerinde çalışır; credential üretmez. Sadece müşteri–çalışan yönleri kabul edilir; normal çalışan rol değişimi eski `assign_account_role` yolunda kalır. Manager dönüşüm yapamaz. |
| Müşteriden çalışana | Eski `customer_users` satırları silinmez/taşınmaz; aktif olanlar pasifleştirilir. Kuruluş, sipariş, tahsilat ve diğer geçmiş kayıtlar korunur. Hedef kuruluş parametresi kabul edilmez. |
| Çalışandan müşteriye | Owner açıkça aktif, hiçbir üyelik satırı bulunmayan bir kuruluş seçer. Eski pasif üyelik de kuruluşu dolu sayar; sessiz yeniden etkinleştirme yoktur. Yeni üyelik aktif kurulur; profilin mevcut `active` değeri korunur. |
| Açık iş engeli | Kullanıcının `assigned_sales_operator_id` ile atandığı herhangi bir müşteri; primary/assistant olduğu bitmemiş sefer (`ended_at IS NULL`); bitmiş seferde dahi kapanmamış durak dönüşümü reddettirir. Kapanmış sefer geçmişi engel değildir. `created_by` geçmişi görev ataması sayılmaz. |
| Accounting | Yalnız `assigned_sales_operator_id IS NOT NULL` müşteriler. Satışçı oluşturucusu tek başına yeterli değildir; atama kaldırılınca müşteri ve tahsilat okumaları kesilir. Yazma, müşteri yönetimi, ham müşteri/sipariş/ödeme satırları, maaş ve audit kapalıdır. |
| Warehouse | Ürün/birim, stok, hareket ve sayım okumaları. Sipariş hazırlığı yalnız `submitted/picking/picked`; müşteri kimliği/iletişim/vergi, fiyat/tutar/iskonto, ödeme ve maaş açılmaz. Hiçbir stok veya sipariş mutasyonu eklenmez. |

**Alan sözleşmeleri:**

- `accounting_customers`: id, company_name, contact_name, phone, email, address, tax_no, tax_office, credit_limit_kurus, payment_due_days. notes/oluşturucu/operasyon alanları yoktur.
- `accounting_payments`: id, customer_id, order_id, payment_amount_kurus, method, collector_user_id, collected_at, verified_by, verified_at, verification_status. `accounting_payment_adjustments`: id, payment_id, adjustment_amount_kurus, created_by, created_at. İkisi de aynı müşteri atama koşulunu denetler; tutar/borç hesaplamaz, serbest not ve işlem anahtarlarını vermez.
- `warehouse_products`: id, sku, name, package_label, base_unit, active; fiyat alanı yoktur. `warehouse_preparation_items`: order_id, item_id, status, product_id, product_unit_id, unit, conversion_to_base_snapshot, quantity, picked_qty.
- `warehouse_stock_counts` ve `warehouse_movements` açık tipli, yalnız stok alanlarını döndürür; serbest belge notları, genel reference alanları ve operation_key dışarıda kalır. `product_units`, `inventory`, `stock_count_items` mevcut tablolarında sadece aktif Warehouse SELECT politikası eklenir. Ham products/orders/order_items açılmaz; RLS'nin sütun gizlemediği göz önünde tutulur.

**Teknik güvence:** Sekiz RPC'nin tümü sabit boş search_path ile SECURITY DEFINER; anon/PUBLIC execute kapalı ve fonksiyon içinde canlı DB rol denetimi vardır. Ham INSERT/UPDATE/DELETE grant'i eklenmez. Dönüşüm, Auth/profil ve üyelik/kuruluş satır kilitleriyle tek transaction'dır; hata rol/üyelik/audit değişikliği bırakmaz. Eski rol ve üyelikler ile hedef rol/kuruluş audit'e kaydedilir. Pasif profil kendiliğinden açılmaz.

**Kalan sınırlar:** Şemada genel görev/atama tablosu yoktur; gelecekte eklenecek görevlerin dönüşüm engeline nasıl katılacağı ilgili serviste belirlenmelidir. Yeni sefer/iş atama servisleri aynı profil kilidi altında güncel rolü denetlemelidir; bu görev çok oturumlu yarış testinin veya iş transaction'larının kabulü değildir. Üyelik aktarımı, pasif üyelik geri açma, çoklu kuruluş, son Owner'ın hesap yaşam döngüsü, Sales oluşturucu erişiminin geri alınması ve Order Operator eşlemesi genişletilmedi. Self-signup, çalışan daveti/ilk Owner temini, kalıcı oturum, kurtarma/hesap kapatma halen Faz 4'te bekler. Dönüşüm yönetim ekranı ve bu okumaları tüketen iş ekranları bu backend kapsamına dahil değildir.

**Test kapsamı:** `account_scope_test.sql` 85 regresyon içerir; tüm 13 sipariş durumunda hazırlık erişimi, tam projection alan listeleri, aktif/pasif rol, atama kaldırılması, yetkisiz dönüşüm, açık iş engelleri, rollback ve geçmiş korunması sınanır. Eski `auth_access_test.sql` 117 testini korur; yalnız Accounting'in oluşturucuya dayalı 2 satır beklentisi onaylı daha dar 1 satıra güncellenir. Nihai komut kanıtları PROGRESS/TESTING başındadır.
