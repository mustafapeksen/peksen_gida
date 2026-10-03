# Pekşen Gıda geliştirme planı

Kaynak: [Peksen_Gida_Teknik_Tasarim_v3.docx](Peksen_Gida_Teknik_Tasarim_v3.docx), özellikle §33–39. Kayıt tarihi: 2 Ekim 2026; son durum kontrolü: 3 Ekim 2026. İş kapsamı ve Flutter/Supabase mimarisi [SPEC.md](SPEC.md) içindedir.

Faz 1 dokümantasyonu tamamlanmıştır; mevcut görev yalnızca Faz 2 Flutter iskeleti, tema ve routing kapsamındadır. Faz 3–17 uygulanmamıştır. Aşağıdaki faz adları ve kabul ölçütleri kaynak §33'ten aktarılmıştır. Bağımlılıklar, bu kapsamın uygulanması için hazırlanan planlama sırasıdır; yeni iş kuralı değildir. Kritik iş kuralı açık olduğunda [DECISIONS.md](DECISIONS.md) kararı olmadan ona bağlı uygulama veya beklenen test sonucu uydurulmaz.

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
| 3 | Supabase migrations + seed | Faz 1–2; §37 veri modeli eksikleri ve şemayı etkileyen para, durum, stok kararları ilgili migration öncesi kaydedilir. Yerel/yalıtılmış test ortamı hazırlanır. | Boş veritabanı migration ile kurulabilir; yedi rol için sentetik test kullanıcıları ve örnek kayıtlar bulunur. | bekliyor |
| 4 | Auth + RBAC + RLS | Faz 2–3; çalışan hesabı/davet akışı, rol sınırları ve müşteri ilişkileri netleşir. | Müşteri ve çalışan oturumları çalışır; yetkisiz rol değişimi, başka müşteri kaydı ve maaş verisi erişimi testlerde reddedilir. | bekliyor |
| 5 | Products + units + pricing | Faz 3–4; iskonto takvimi/ölçümü, TL ve dönüşüm hassasiyeti, yuvarlama ve snapshot adları karara bağlanır. | Birim dönüşümleri ve minimum miktar doğrulanır; fiyat backend tarafından hesaplanır; fiyat geçmişi ve sipariş snapshotları test edilir. | bekliyor |
| 6 | Customer experience | Faz 2–5; sipariş oluşturmayı etkileyen cari, stok, durum ve güvenilir işlem kararları gerekir. Faz 8–9'un ayrıntılı ekranları beklenmeden ortak backend işleminin gereken en küçük dilimi kurulur. | Katalog, müşteri fiyatı, sepet ve sipariş oluşturma akışı çalışır; fiyat/stok değişiminde açıklayıcı sonuç gösterilir. | bekliyor |
| 7 | Sales Operator saha siparişi | Faz 4–6; ortak OrderService/backend transaction ve müşteri erişim sınırları. | Müşteri seçilerek aynı backend sipariş servisi kullanılır; source ve created_by doğru kaydedilir. | bekliyor |
| 8 | Order workflow + alternatives | Faz 3–7; ana durum/ödeme/talep eşlemesi, failed/returned geçişleri, Order Operator yetkisi ve değişiklik sınırları netleşir. | İzinli durum geçişleri, iptal/değişiklik talepleri ve alternatif kabul/ret akışı audit ile doğrulanır. | bekliyor |
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

## Faz 2 görevi — mevcut kapsam

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

## Faz 3 hazırlığı — sonraki kullanıcı görevi

Faz 3'e bu görevde başlanmaz. İlk iş mevcut kayıtları okuyup yerel Supabase CLI/konteyner ortamını ve boş, yalıtılmış sentetik test veritabanı hedefini doğrulamaktır. Migration öncesinde A-01–A-08 ve A-11–A-13'ün şemayı etkileyen soruları; konum tabloları için A-09 ayrıca ele alınır. Kanonik snapshot alanları, eksik tablolar/FK'ler, yedi rol ve müşteri ilişkileri, para hassasiyeti, sipariş durum boyutları ve stok gösterimi kaydedilmeden bağımlı migration/seed yazılmaz. Amaç sürümlü migration ve yedi rol için sentetik seed'dir; canlı veritabanı bağlantısı veya ürün formülü varsayımı değildir.

## Her fazda kalite kapısı

Kaynak §34'teki kontroller [TESTING.md](TESTING.md) içinde ayrıntılıdır. Flutter değişikliklerinde analyze ve ilgili unit/widget testleri; SQL/RLS değişikliklerinde veritabanı, yetki ve transaction testleri; tamamlanan kullanıcı akışlarında integration testleri gerekir. Mobil bağımlılık, platform ayarı veya tamamlanan faz sonrası Android debug build alınır. GPS, bildirim ve release kabulü gerçek cihaz gerektirir. Fiyat/stok/sipariş/ödeme değişiklikleri ilgili regresyon testlerini gerektirir.

Her kapanış raporu tamamlanan kabul ölçütlerini, değişen dosyaları, çalıştırılan komutları/sonuçları, çalıştırılamayan kontrolleri/nedenlerini, kalan riskleri ve sonraki somut görevi içerir. Mevcut kaynakla çelişki kullanıcıya bildirilir ve karar kaydına yazılır.
