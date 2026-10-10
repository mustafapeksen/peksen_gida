# Pekşen Gıda geliştirme planı

**10 Ekim 2026 — F8-02 kapanışı:** Faz 8'in F8-01/F8-02 ile kullanıcı tarafından sınırlandırılan yerel kapsamı tamamlandı: gerçek submitted iptali, stok etkilemeyen talep/alternatif niyeti, Manager/Owner submitted talep kararı ve history/audit. 166 Flutter, 680 DB, build ve Android 5/5 geçti. Kullanıcının açık cevabıyla gerçek kalem revizyonu ve picking sonrası stok etkili onaylar bekler; uygulanmış sayılmaz. Faz 9 başlamadı; yeni görev olmadan geçilmez. Aşağıdaki F8-01 kaydı tarihçedir.

**10 Ekim 2026 — Faz 8:** Kullanıcı F8-01 ile bu turu submitted iptali ve değişiklik/iptal talebi altyapısına daralttı. Karar yetkisi yalnız Manager/Owner; alternatif uygulaması ve picking sonrası stok etkili onaylar bekler. Onaylı dilimin sonuçları PROGRESS/TESTING'dedir; Faz 8 bütünü henüz tamamlanmadı. Faz 9'a geçilmez. Aşağıdaki Faz 7 “Faz 8 başlatılmaz” ifadesi önceki görevin tarihçesidir.

**9 Ekim 2026 Faz 7 devamı:** Sales yalnız atanmış aktif müşteri seçer; F7-01 creator-only istisnasını kaldırır. Ortak Faz 6 checkout kullanılır; 143 farklı Flutter testi (142 tam + 1 son hedefli), 421 ilgili DB, debug build ve Android 2/2 geçti. Faz 7 tamamlandı. Faz 8 başlatılmaz.

**9 Ekim 2026 Faz 6 devamı:** Customer katalog/sepet/taslak/gönderim F6-01 sınırında tamamlandı; 130 Flutter, 392 ilgili DB, debug build ve Android 3/3 smoke geçti. Cari hesap yalnız not_evaluated uyarısıdır; borç/exposure formülü eklenmedi. Sales ekranları Faz 7 için bekler. Aşağıdaki Faz 5 kapanışı tarihsel kayıttır.

**9 Ekim 2026 güncel durum:** Faz 1–5 tamamlandı; Faz 4 kabulü korunur. Faz 5 F5-01 onaylarıyla ürün/birim/fiyat kapsamındadır: analyze, 113 Flutter testi, debug build, ilgili 298 DB testi ve iki Android smoke geçti. Kanıtlar/sınırlar PROGRESS/TESTING başındadır. Çeyrek önerisi/eşik hesabı/geç iade bu görevden açıkça çıkarılmıştır. Faz 6 başlamadı.

Kaynak: [Peksen_Gida_Teknik_Tasarim_v3.docx](Peksen_Gida_Teknik_Tasarim_v3.docx), özellikle §33–39. Kayıt tarihi: 2 Ekim 2026; son durum kontrolü: 4 Ekim 2026. İş kapsamı ve Flutter/Supabase mimarisi [SPEC.md](SPEC.md) içindedir.

**Faz 3 tarihsel kabul notu:** Faz 1–3 tamamlanmıştır; Faz 3 kabulü **migration + seed ve mevcut client hazırlığı** ile sınırlıdır. Kullanıcının 4 Ekim B-01–B-09 onaylarıyla 25 kaynak tablo ve 10 yardımcı tablo kuruldu. Boş DB kurulumu/seed başarılı, identity 19/19 ve business 97/97 PASS; Flutter pub get/analyze/65 test/debug build çıkış 0. Faz 4–17 uygulanmamıştır. Aşağıdaki kabul ölçütleri kaynak §33'ten aktarılmıştır; migration/seed kabulü gerçek sipariş/cari/stok servislerini kapsamaz. [DECISIONS R-01–R-07](DECISIONS.md) ilgili sonraki işlem fazlarından önce çözülür; açık formül uygulamaya gömülmez.

## Durumlar ve ilerleme kuralı

| Durum | Anlam |
| --- | --- |
| bekliyor | Uygulamaya başlanmadı veya önkoşul bekleniyor. |
| devam ediyor | Fazın sınırlandırılmış görevi yürütülüyor. |
| doğrulama bekliyor | İş üretildi; gerekli kabul kanıtı eksik veya ortam nedeniyle kontrol çalıştırılamadı. |
| tamamlandı | Fazın ilgili kabul ölçütleri doğrulandı; sonuç ve sınırlamalar PROGRESS'e yazıldı. |

Bir faz birden fazla küçük göreve ayrılır. Her görev amaç, kapsam, bağımlılık, kabul ölçütü ve doğrulama komutlarıyla başlar. Önce çalışan en küçük uçtan uca akış, ardından aynı rolün diğer ekranları uygulanır. Mock/sentetik ekran gerçek backend entegrasyonu sayılmaz. Çalıştırılmayan test başarılı sayılmaz. Her görev sonunda karar ve ilerleme kayıtları güncellenir.

## 17 faz

| Faz | Kapsam | Bağımlılıklar ve önkoşullar | Kaynaktaki kabul ölçütleri | Durum |
| --- | --- | --- | --- | --- |
| 1 | Repository + AGENTS.md + docs/SPEC.md + karar ve ilerleme kayıtları | Mevcut depo ve kaynak DOCX okunur; mevcut dosyalar korunur. | Kapsam, açık kararlar, klasör yapısı ve komutlar yazılı; henüz uygulama tamamlandı iddiası yok. | tamamlandı |
| 2 | Flutter iskeleti + tema + routing | Faz 1; Flutter/Android araçları ve seçilecek sürümler doğrulanır. İş formüllerinden bağımsız iskelet yapılabilir. | Uygulama açılır; giriş, yükleniyor, boş liste ve hata ekranları çalışır; rol bazlı menü iskeleti hazırdır. | tamamlandı |
| 3 | Supabase migrations + seed | Faz 1–2; B-01–B-09 ve T-12, yerel sentetik Docker hedefi. | Boş veritabanı migration ile kurulabilir; yedi rol için sentetik test kullanıcıları ve örnek kayıtlar bulunur. | tamamlandı; 25 kaynak + 10 yardımcı tablo, 19+97 DB test |
| 4 | Auth + RBAC + RLS | Faz 2–3; F4-01–F4-06, onaylı kayıt/davet/hesap sınırları. | Müşteri ve çalışan oturumları çalışır; yetkisiz rol değişimi, başka müşteri kaydı ve maaş verisi erişimi testlerde reddedilir. | tamamlandı; DB/SDK ve Android görsel/kalıcı oturum kabulü |
| 5 | Products + units + pricing | Faz 3–4; F5-01 onaylı erişim, exact dönüşüm, taban minimumu, yarımda yukarı yuvarlama ve snapshot sözleşmesi. | Birim dönüşümleri/minimum doğrulanır; fiyat backend hesaplanır; fiyat geçmişi ve sipariş snapshotları test edilir. | tamamlandı; 73 yeni DB + 140 business + 85 scope, 113 Flutter, build ve Android 2/2 |
| 6 | Customer experience | Faz 2–5; sipariş oluşturmayı etkileyen cari, stok, durum ve güvenilir işlem kararları gerekir. Faz 8–9'un ayrıntılı ekranları beklenmeden ortak backend işleminin gereken en küçük dilimi kurulur. | Katalog, müşteri fiyatı, sepet ve sipariş oluşturma akışı çalışır; fiyat/stok değişiminde açıklayıcı sonuç gösterilir. | tamamlandı; F6-01, 130 Flutter + 392 DB + build + Android 3/3 |
| 7 | Sales Operator saha siparişi | Faz 4–6; ortak OrderService/backend transaction ve müşteri erişim sınırları. | Müşteri seçilerek aynı backend sipariş servisi kullanılır; source ve created_by doğru kaydedilir. | tamamlandı; F7-01, 143 Flutter / 421 DB / build / Android 2/2 |
| 8 | Order workflow + alternatives | Faz 3–7; F8-01/F8-02: submitted iptali, talep ve alternatif niyeti, yalnız Manager/Owner submitted talep kararı. Gerçek revizyon/picking sonrası stok etkisi kullanıcı kararıyla bekler. | İzinli durum geçişi, iptal/değişiklik talepleri ve alternatif kabul/ret niyeti history/audit ile doğrulanır; karar siparişi uygulamaz. | tamamlandı (onaylı F8-01/F8-02 yerel kapsamı); 166 Flutter / 680 DB / build / Android 5/5 |
| 9 | Warehouse + inventory | Faz 3–8; rezervasyon başlangıcı, picked/reserved ilişkisi, fiziksel düşüm, iptal/iade telafisi ve kilitleme kuralları karara bağlanır. | Rezervasyon, toplama, yükleme, mal kabulü ve onaylı sayım çalışır; eşzamanlı sipariş stok tutarsızlığı oluşturmaz. | bekliyor |
| 10 | Accounting + payments + credit | Faz 3–9; cari limit, borç oluşumu, doğrulanmamış/kısmi/fazla tahsilat, idempotency ve para hassasiyeti kararları gerekir. Cari uyarısının sipariş oluşturmadaki temel davranışı Faz 6'da korunur. | Nakit/POS tahsilat, gerçek tahsil eden kişi, muhasebe doğrulaması ve cari uyarı onayı kaydedilir; yinelenen işlem çift kayıt üretmez. | bekliyor |
| 11 | Delivery + vehicle + driver | Faz 4, 8–9; araç/sefer/durak modeli ve primary/assistant driver yetkileri netleşir. | Araç/sefer/durak ataması, primary ve assistant driver erişimi, yükleme ve sıra değişikliği çalışır. | bekliyor |
| 12 | Background GPS + Realtime + MapLibre | Faz 11; konum saklama/silme, eski konum uyarısı, erişim bitişi, harita sağlayıcısı ve Android izin davranışı kararları; gerçek Android cihaz. | Android gerçek cihazda ekran kapalıyken takip, izin reddi ve bağlantı kesintisi denenir; müşteri yalnızca kendi aktif teslimatını görür; sefer sonunda paylaşım durur. | bekliyor |
| 13 | Delivery confirmation + rating | Faz 8, 11–12; çift onay, Manager exception yetkisi, failed/returned geçişleri ve kontrollü Storage erişimi. | Çift onay, uyuşmazlık ve Manager çözümü çalışır; teslim edilmeyen sipariş puanlanamaz; sipariş başına tek puan korunur. | bekliyor |
| 14 | FCM notifications | Faz 4–13'te olay üreten akışlar; cihaz token modeli, FCM yapılandırması ve tekrar gönderim kararı; gerçek Android cihaz. | Hedef kullanıcı/rol, bildirim geçmişi ve deep link çalışır; bildirim kaybı sipariş işlemini geri almaz; yinelenen gönderim kontrol edilir. | bekliyor |
| 15 | Manager + Owner + reports | Faz 4–14; operasyon kayıtları, rapor veri kaynakları ve Owner-only maaş/prim politikaları. | Operasyon raporları kayıtlarla tutarlıdır; maaş/prim yalnızca Owner tarafından erişilebilir. | bekliyor |
| 16 | Uçtan uca test + güvenlik incelemesi | Faz 2–15; ilgili açık kararlar kapanmış, sentetik yedi rol verisi ve gerçek cihaz test ortamı hazır. | Yedi rol senaryosu, fiyat/stok/tahsilat yarış durumları, RLS ve dosya erişimi kontrol edilir; açık engelleyici hata kalmaz. | bekliyor |
| 17 | Android release APK | Faz 16; imzalama ve sürüm yapılandırması, gerçek cihaz, kurulum ve yedekleme yönergeleri. Yayınlama ayrıca yetkilendirilir. | İmzalı sürüm üretilebilir; gerçek cihazda kurulum, oturum, sipariş, bildirim ve GPS denenir; sürüm, kurulum ve yedekleme adımları belgelenir. | bekliyor |

§37 kararları ilgili faz başlamadan kayda alınır. Daha erken bir fazda aynı kritik backend davranışının küçük bir dilimi gerekiyorsa karar ve test yükümlülüğü de o göreve taşınır; bu, kararı sonraki faza erteleme gerekçesi değildir. Bağımsız tema, ekran ve iskelet çalışmaları sürdürülebilir.

## Faz 1 kabul kontrolü — tarihi kayıt

Son kanıt ve kontrol sonuçları [PROGRESS.md](PROGRESS.md) içinde tutulur. Aşağıdaki ölçütler uygulama tamamlandığı anlamına gelmez:

1. Açık klasör, Git durumu ve mevcut dosyalar incelenmiş; kaynak DOCX okunmuş olmalı.
2. İş kuralları, yedi rol, tüm ekranlar, veri modeli, mimari ve kapsam dışı maddeler SPEC'e aktarılmış olmalı.
3. İskonto, cari, stok ve sipariş durumları başta olmak üzere açık kararlar kaynakla ilişkilendirilmiş olmalı; eksik formül uydurulmamalı.
4. AGENTS, README, `.gitignore`, `.env.example`, SPEC, PLAN, DECISIONS, PROGRESS ve TESTING bulunmalı; mevcut kaynak dosyaları korunmalı.
5. Mevcut ve hedef klasör yapısı, kurulum/doğrulama komutları ve gerekli ortam açıkça yazılmalı; uygulanmamış komutlar başarılı diye gösterilmemeli.
6. Faz 1 görevi içinde Flutter projesi veya uygulama modülleri oluşturulmamalı; commit, push ve yayınlama yapılmamalı. Kullanıcının sonraki Faz 2 görevi yalnızca aşağıdaki iskelet için yetki vermiştir; bu tarihsel ölçüt Faz 2'yi engellemez.

## Faz 2 görevi — tamamlanan kapsamın kaydı

**Amaç:** Android'de açılan Flutter iskeletini tema, go_router ve Riverpod ile kurmak; giriş, yükleniyor, boş liste, hata ekranları ve yedi role ait menü iskeletini göstermek.

**Önkoşullar:** AGENTS, SPEC, PLAN, DECISIONS ve PROGRESS yeniden okunur. Flutter/Dart sürümü, Android araç zinciri ve çalıştırma hedefi doğrulanıp kaydedilir. Uygulama kimliği ve paket sürümleri seçilir. Flutter oluşturucusunun mevcut belgeleri veya `.gitignore` dosyasını değiştirmemesi için dosya farkları gözetilir. Formül gerektirmeyen iskelet, §37 iş kararlarını beklemeden hazırlanabilir.

**Sınırlı kapsam:** SPEC §28'deki `lib/core`, `lib/features` ve `lib/shared` ayrımını gözeten en küçük iskelet, ortak tema, routing, durum ekranları ve rol bazlı menü kabukları. Giriş ekranı bu fazda arayüzdür; gerçek Supabase Auth/RBAC/RLS kabulü Faz 4'tedir. Rol seçimi “Geliştirme önizlemesi” olarak yalnız debug modunda gösterilir ve rota erişimi de debug koşuluyla korunur; yetkilendirme kanıtı sayılmaz. Sipariş, iskonto, cari, stok, ödeme, GPS ve bildirim entegrasyonları bu göreve eklenmez.

**Uygulama kararları:** Proje mevcut depo kökündedir; Flutter oluşturucusu geçici klasörde çalıştırılıp dosyalar seçilerek birleştirilir. README, `.gitignore` ve kaynak belgeler ezilmez. Görünen ad `Pekşen Gıda`; geçici kimlik `com.example.peksen_gida`dır. SDK/paket seçimi, tema, yönlendirme, önizleme sınırı ve release imzalama durumu DECISIONS T-01–T-06'da kayıtlıdır.

**Kabul ölçütleri:**

1. Uygulama Android hedefte açılır; Türkçe giriş, yükleniyor, boş liste ve hata görünümleri erişilebilirdir.
2. Yedi Türkçe rol menüsü ve SPEC §23'teki ekran bağlantıları arasında gezinilir; bu kabuklar gerçek iş modülü olarak sunulmaz.
3. Geri gezinme, doğrudan alt yol açma ve bilinmeyen rota/rol/ekran/durum davranışları tanımlıdır.
4. Küçük ekranda taşma oluşmaz; giriş alanlarına klavye açıkken erişilir. Widget koşulları ve görsel cihaz kanıtı ayrı kaydedilir.
5. Rol envanteri, ekran ve yönlendirme davranışları anlamlı unit/widget testleriyle doğrulanır; `flutter analyze` ve `flutter test` başarılıdır.
6. `flutter build apk --debug` başarılıdır.
7. Bağlı emülatörde uygulama çalıştırılır ve açılış kontrol edilir. Emülatör yoksa çalıştırma “yapılmadı”, ortam engeli varsa ilgili kabul “doğrulama bekliyor” kaydedilir. Görsel olarak incelenmeyen davranışlar görsel kabul sayılmaz.
8. Debug dışındaki önizleme erişimi kapalıdır; girişte gerçek oturum açmanın henüz bağlı olmadığı açıklanır. Mevcut belgeler korunur; commit, push, yayınlama veya Faz 3 işi yapılmaz.

**Doğrulama komutları:** `flutter --version`, `flutter doctor -v`, `flutter devices`, `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug` ve bağlı Android hedefte `flutter test integration_test/app_smoke_test.dart -d CIHAZ_ID`. Manuel ekran incelemesi için `flutter run -d CIHAZ_ID` veya önceden doğrulanmış APK'nın ADB ile kurulup açılması kullanılabilir. Son görevde `flutter devices` ve ADB, `emulator-5554` hedefini doğruladı. Bitiş çıktıları ve çıkış kodları kaydedilir; APK'nın varlığı tek başına build kabulü değildir. Komutlar ve test kapsamı [TESTING.md](TESTING.md), sonuçlar ve kabul durumları [PROGRESS.md](PROGRESS.md) içindedir. Otomatik emülatör testi ve görsel gözlem ayrı kanıtlardır.

**3 Ekim 2026 son kabul:** Mevcut iskelet, paketler ve geçen 42 test değiştirilmeden korundu. Kayıtlı pub get, analyze, 42/42 test ve debug build çıkış 0'dır; yeniden çalıştırılmadı. Bağlı emulator-5554 üzerinde mevcut integration testi 1/1 başarı ve çıkış 0 ile bitti. Normal debug APK ayrıca ADB ile kuruldu (çıkış 0) ve soğuk başlatıldı (`Status: ok`, çıkış 0). Giriş, Android klavyesinde iki alana erişim, rol seçim listesi, Depo/Ürünler örneği, ortak durumlar ve örnek geri akışı görüntüler üzerinden incelendi. Yedi rol/70 menünün tamamı, bilinmeyen rota ve 320×568/2× yazı koşulları widget kanıtına dayanır; bütün ekranların cihazda görsel kabulü iddia edilmez. **Faz 2 tamamlandı; Faz 3 başlamadı.** Görsel olarak incelenmeyen ekran/cihaz koşulları TESTING'de açıkça listelenmiştir.

## Faz 3 — son kabul, 4 Ekim 2026 iş onaylarından sonra

| Ölçüt | Kanıt / sonuç |
| --- | --- |
| Boş DB migration ile kurulabilir | İki migration ve iki seed; son `db reset --local` çıkış 0. |
| Kaynak veri modeli | 25 kaynak tablo + 10 yardımcı; ilk identity migration/seed korunur. |
| Yedi rol ve örnek kayıtlar | Sekiz sentetik Auth/profile, iki kuruluş; ürün/birim/stok/sipariş/teslimat/ödeme örnekleri. |
| DB bütünlük ve kapalı erişim | Identity 19/19 ve business 97/97 PASS, çıkış 0; Faz 4 policy yok. |
| Flutter hazırlığı korunur | pub get/analyze çıkış 0, 65/65 test ve debug build çıkış 0. Kod/test değişmedi. |
| Kalan kararlar/kapsam sınırı | B-01–B-09 onaylı, T-12 teknik şema; R-01–R-07/A-14 sonraki servis/izin işleri. |

**Faz 3 tamamlandı (migration/seed kapsamı).** Faz 4'e geçilmez. İlgili yeni görev gelmeden gerçek Auth, fiyat/stok/payment transaction, izin politikası, GPS/push yapılmaz. Bu tur integration/görsel kontrol tekrarlanmadı; önceki Android başarısı tarihsel olarak korunur. Son komutlar ve sınırlar PROGRESS/TESTING başındadır.

## Faz 3 ilk dilim ve ortam bekleme sürecinin tarihsel kaydı

**Amaç:** Kaynağın migration/seed kabulüne ilerlemek; kullanıcının ayrıca istediği güvenli env/config, Supabase client başlangıcı ve auth durum gözlemini Faz 2'yi koruyarak hazırlamak. Gerçek oturum açma/RBAC/RLS izin politikaları Faz 4'te kalır.

**Bağımsız dilim:** SPEC §2/3/25 için yedi rol ve profiles/customers/customer_users; sekiz sentetik kullanıcı/identity (iki customer), iki kuruluş ve üyelik seed'i; kapalı istemci erişimi ve 19 DB testi. Teknik seçimler T-07–T-10'da kayıtlıdır. Diğer 22 kaynak tablosu ve eksik varlıklar A-01–A-13 bağımlılıkları çözülmeden oluşturulmaz; bu erteleme tam şema kabulünü azaltmaz.

**Kabul ölçütleri ve son durum:**

1. Boş yerel Supabase DB migration ile kurulur: dosyalar hazır, **doğrulanmadı**. Docker/Podman yok; start çıkış 1.
2. Yedi role ait sentetik kullanıcılar ve örnek kayıtlar DB'de bulunur: seed hazır, **çalıştırılmadı**. Ürün/stok/sipariş örnekleri açık kararları bekler.
3. Güvenli public config ve istemci/auth-state altyapısı hazırlanır: uygulandı; yapılandırmasız/bozuk/yükleniyor/hata/SDK başlangıcı testleri mevcut. Oturum gözlemi yetkilendirme değildir.
4. Mevcut önizleme ve giriş sınırı korunur: eski 42 test değiştirilmedi; tam Flutter test paketi 65/65 geçti.
5. Flutter pub get, analyze, 65 test ve Android debug build: hepsi çıkış 0; yeniden bağlanan emulator-5554 üzerinde mevcut integration testi de 1/1 ve çıkış 0. Yeni görsel inceleme yapılmadı; DB kabulü bu Flutter kontrolleriyle karşılanmış sayılmaz.

**Doğrulama:** `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`; cihaz varsa `flutter test integration_test/app_smoke_test.dart -d CIHAZ_ID`. DB için `npx.cmd --yes supabase@2.119.0 start`, yalnız boş/sentetik yerel hedefte `db reset --local`, ardından `test db --local supabase/tests/database/identity_foundation_test.sql`.

**4 Ekim 2026 devam kontrolü:** Mevcut dosyalar, Git durumu ve 3 Ekim komutlarının bitiş kayıtları yeniden okundu. Başarılı Flutter kontrollerinden sonra uygulama/test kodu değişmedi; kontroller tekrarlanmadı. Docker/Podman erişimi hâlâ yok. Migration/seed kabulü ve açık kararların durumu değişmedi.

**Sonraki somut iş:** Docker uyumlu yerel ortamı kullanılabilir hale getirip ilk migration/seed/DB testini doğrulamak; şemayı etkileyen A-01–A-13 kararlarını netleştirerek kalan migrationları Faz 3 içinde tamamlamak. Faz 3 bitmedi; Faz 4'e geçilmez. Auth operasyon/saklama ayrıntıları A-14'te görünür tutulur.

**4 Ekim kullanıcı yönlendirmesi:** Bu görevde Docker Desktop/Podman kurulmaz. Bağımsız statik SQL incelemesi ve CLI yardım doğrulaması tamamlandı; boş DB kurulumu, seed ve DB test kabulü **blocked by local Supabase runtime**. Kullanıcı ileride iki runtime'dan birini kurup başlattığında TESTING'deki açık yerel hedef komutları çalıştırılır. İstenen Flutter tekrar kontrolleri tamamlandı: pub get/analyze/build çıkış 0; 65/65 unit/widget ve emulator-5554 üzerinde 1/1 integration çıkış 0. Bunlar DB kabulünün yerine geçmez. Kaynak SQL ve iş kuralları değiştirilmedi.

## Her fazda kalite kapısı

Kaynak §34'teki kontroller [TESTING.md](TESTING.md) içinde ayrıntılıdır. Flutter değişikliklerinde analyze ve ilgili unit/widget testleri; SQL/RLS değişikliklerinde veritabanı, yetki ve transaction testleri; tamamlanan kullanıcı akışlarında integration testleri gerekir. Mobil bağımlılık, platform ayarı veya tamamlanan faz sonrası Android debug build alınır. GPS, bildirim ve release kabulü gerçek cihaz gerektirir. Fiyat/stok/sipariş/ödeme değişiklikleri ilgili regresyon testlerini gerektirir.

Her kapanış raporu tamamlanan kabul ölçütlerini, değişen dosyaları, çalıştırılan komutları/sonuçları, çalıştırılamayan kontrolleri/nedenlerini, kalan riskleri ve sonraki somut görevi içerir. Mevcut kaynakla çelişki kullanıcıya bildirilir ve karar kaydına yazılır.
