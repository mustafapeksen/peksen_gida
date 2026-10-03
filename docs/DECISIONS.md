# Pekşen Gıda — Karar kaydı

Kayıt tarihi: **2026-10-02** (Europe/Istanbul). Kaynak: [Pekşen Gıda Teknik Tasarım ve Codex Geliştirme Planı v3](Peksen_Gida_Teknik_Tasarim_v3.docx), revizyon tarihi 1 Ekim 2026. Bölüm numaraları kaynak DOCX'e aittir.

Bu kayıt Faz 1'de hazırlanmış, Faz 2'de iskeletin teknik kararlarıyla genişletilmiştir. Kaynakta karara bağlanmış kurallar ile henüz cevaplanmamış sorular ayrılmıştır. Açık maddeler onaylanmış varsayım değildir; formül, eşik yorumu, yeni rol veya durum geçişi seçilmemiştir. İş kurallarının tamamı [SPEC.md](SPEC.md), fazlar ve kabul ölçütleri [PLAN.md](PLAN.md) içindedir.

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

## Açık kararlar

Bu bölümdeki tüm maddeler için tarih **2026-10-02**, durum **Açık — karar verilmedi; uygulama varsayımı yapılmadı**dır. İş kuralı kararları kullanıcı tarafından netleştirilir; şema ve teknik kararlar kaynak kapsamına uygun gerekçeyle kaydedilir. Her madde aşağıda özel kaynağını, neden gerekli olduğunu ve etkilediği fazları belirtir.

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
- **Durum:** Açık; yeni tablo veya FK tasarımı bu fazda uygulanmadı.

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

## Kararların kapatılması ve sonraki adım

Bir açık madde kapatılırken ID korunur; kararın tarihi, kesin cevabı, gerekçesi, kaynak etkisi, gerekiyorsa reddedilen seçenekleri ve etkilediği kabul ölçütleri kaydedilir. Sonra SPEC/PLAN/TESTING/PROGRESS birlikte tutarlı hale getirilir. DOCX ve Markdown farklılaşırsa fark kullanıcıya bildirilip burada kaydedilir; kaynak sessizce düzeltilmez (§35–36).

Faz 2'nin iskelet, tema, routing, ortak giriş/yükleniyor/boş/hata durumları ve yedi rol menüsü bu formülleri seçmeden hazırlanabilir. Şema, RLS, fiyat, sipariş, rezervasyon, ödeme ve GPS uygulaması ise ilgili açık maddeler çözülmeden tamamlandı kabul edilemez.
