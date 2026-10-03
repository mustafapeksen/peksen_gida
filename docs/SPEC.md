# Pekşen Gıda teknik kapsamı

Kaynak: [Pekşen Gıda Teknik Tasarım ve Codex Geliştirme Planı v3](Peksen_Gida_Teknik_Tasarim_v3.docx), revizyon 1 Ekim 2026. Aktarım tarihi: 2 Ekim 2026. Bu dosya bir özet değildir; kaynak belgenin 39 bölümünün tüm metni ve 7 tablosu aşağıda korunmuştur. Başlık, liste, tablo ve akış biçimleri Markdown için düzenlenmiştir.

Bu tur yalnızca Faz 1 hazırlığıdır; aşağıdaki uygulama mimarisi, ekranlar ve diğer fazlar hedef kapsamdır, uygulanmış özellikler değildir. Güncel durum [PROGRESS.md](PROGRESS.md), faz takibi [PLAN.md](PLAN.md), kararlar [DECISIONS.md](DECISIONS.md), doğrulama planı [TESTING.md](TESTING.md) içindedir.

Kaynak belgedeki açık noktalar burada çözülmüş sayılmaz. Özellikle §10 içindeki Order Operator yedi rolden biriyle henüz eşlenmemiştir; §5 ve §25 snapshot alan adları farklıdır. §15 ile §32 iki araca bölünme modelinin hazırlığını farklı kesinlikte anlatır; her ikisinde MVP davranışı kapalıdır. §25 ana alan envanteridir, tamamlanmış SQL şeması değildir. Bu farklar ve §37 soruları karar kaydında açık tutulur. İskonto/cari formülü veya stok düşüm zamanı eklenmemiştir.

## Kaynak belgenin başlığı

Pekşen Gıda Teknik Tasarım ve Codex Geliştirme Planı v3

Android-first B2B gıda tedarik, saha satış, depo, dağıtım ve tahsilat sistemi

Bu belge, Pekşen Gıda Android uygulamasının ChatGPT ile planlanması ve Codex ile geliştirilmesi için proje sözleşmesidir. İş kapsamı ve Flutter/Supabase mimarisi korunmuştur. v3 revizyonu 1 Ekim 2026 tarihinde geliştirme sürecini, kabul ölçütlerini ve devam kayıtlarını günceller. Proje prototip olarak başlar; ticari kullanım öncesinde güvenlik, gerçek cihaz ve operasyon testleri tamamlanır.

## 1 Proje hedefi

Pekşen Gıda; market, restaurant, otel ve benzeri ticari müşterilere ürün satan tek satıcılı, tek depolu bir B2B tedarik sistemidir. Uygulama Android APK olarak başlayacak, ancak Flutter mimarisi gelecekte iOS'a açılabilecek şekilde kurulacaktır.

- Online ödeme yok; nakit ve POS tahsilatı var.

- Fatura PDF'i ilk sürümde yok.

- Harita yalnızca aktif teslimattaki araç konumunu gösterir.

- Otomatik rota optimizasyonu ve geocoding yok.

- Push bildirimleri kullanılacak.

- İlk sürüm internet bağlantısı olmadan kritik işlem yapmayacak.

## 2 Roller

| Rol | Temel görev |
| --- | --- |
| customer | Kendi ürünlerini/fiyatını görür, sipariş verir, siparişini ve aktif aracını takip eder, teslimatı onaylar, driver puanlar. |
| sales_operator | Sahada müşteri adına sipariş oluşturur, ürün/fiyat gösterir, alternatif ürün önerir, ödeme alır. |
| warehouse | Ürün/stok yönetir, mal kabulü yapar, sayım yapar, sipariş hazırlar; fiyat yönetimi yetkisi vardır. |
| accounting | Nakit/POS, cari, fiyat yönetimi ve finansal kayıtlar. |
| driver | Sefer, durak, GPS ve teslimat. |
| manager | Operasyon, fiyat, stok, dağıtım, çalışan ve raporlar. |
| owner | Tüm sistem, finans, ayarlar, audit, maaş/prim. |

## 3 Kullanıcı ve müşteri kayıtları

- Müşteri kendi hesabını e-posta/şifre ile oluşturabilir ve ilk sürümde doğrudan aktif olur.

- Müşteri kuruluşu tek kullanıcıdır.

- İleride çoklu kullanıcıya geçilebilmesi için customer_users tablosu yine de kullanılır.

- B2B müşteri alanları: firma adı, müşteri tipi, yetkili kişi, telefon, e-posta, teslimat adresi, vergi numarası, vergi dairesi, aktif/pasif, notlar.

- Çalışan hesapları owner/manager tarafından oluşturulabilir; çalışanların rolü database seviyesinde tutulur.

## 4 Ürün ve fiyatlandırma

- Ürünleri Warehouse rolü oluşturabilir.

- Fiyat değiştirme yetkisi başlangıçta Warehouse + Accounting + Manager + Owner'dır.

- Fiyat değişiklik geçmişi tutulur.

- Fiyat değişikliğinde eski fiyat, yeni fiyat, yapan kullanıcı, zaman ve gerekçe audit edilir.

- Stokta olmayan ürün katalogda kalır ve 'Stok Yok' görünür.

- Alternatif ürün varsa kullanıcıya gösterilebilir.

- Ürünler adet/kg/koli/paket vb. sipariş birimlerini destekler.

- Order quantity integer olmalıdır. 1.82 kg gibi siparişler yoktur.

- 1800 ml Yumoş gibi fiziksel ambalaj/gramaj bilgisi ürün metadata'sıdır; sipariş miktarı örneğin adet veya koli olur.

- Minimum sipariş tutarı global olarak zorunlu değildir.

- Minimum miktar ürün bazında tanımlanabilir.

## 5 Müşteri iskonto sistemi

Varsayılan test eşikleri: son 3 ay haftalık alışveriş performansına göre yaklaşık 50K=%4, 70K=%6, 100K=%8. Daha düşük müşteri normal liste fiyatını görür.

- Eşikler kod içine gömülmez; app_settings/pricing_rules içinde tutulur.

- Müşteri ekranı: liste fiyatı üstü çizili + 'Size Özel %X' + indirimli fiyat.

- Sales Operator müşteri adına sipariş oluştururken aynı müşteri fiyatını görür.

- Backend fiyatı yeniden hesaplar; client'ın gönderdiği fiyat kabul edilmez.

- Order item içinde list_price_snapshot, discount_rate_snapshot ve final_unit_price_snapshot tutulur.

- Geçmiş siparişler sonraki fiyat değişikliklerinden etkilenmez.

## 6 Cari limit

İlk modelde referans cari limit son 3 ayın haftalık alışverişlerinden hesaplanır. Limit aşımında kullanıcıya açık uyarı gösterilir.

- İlk sürümde otomatik bloklama yok.

- Müşteri 'Devam etmek istiyorum' seçerse sipariş devam eder.

- Limit aşımı ve kullanıcı onayı audit log'a yazılır.

- Limit hesaplama backend'de yapılır.

## 7 Gerçek saha satış senaryosu

```text
09:00
Sales Operator → ABC Market

Müşteri önceden sipariş hazırlamamış.

Sales Operator:
- müşteri profilini açar
- ürün kataloğunu gösterir
- müşterinin özel fiyatlarını gösterir
- müşteri ürünleri seçer
- miktarlar girilir
- sipariş müşteri adına oluşturulur

10:00
Order → Warehouse queue

Warehouse:
- ürünleri toplar
- eksik ürün varsa bildirir

Sales Operator:
- müşteriyle alternatif/eksik ürün kararını netleştirir

Dağıtım günü:
- siparişler araç/seferlere atanır
- araç yüklenir
- Driver 'yola çıktı' yapar
- müşteri canlı araç konumunu görür
- teslimat yapılır
- müşteri + driver teslimatı doğrular
- puanlama açılır

Ödeme:
- normalde Sales Operator tahsil eder
- istisnai olarak başka çalışan tahsil ederse collector_user_id kaydedilir
- Muhasebe kaydı doğrular
```

## 8 Sipariş kaynakları

| source | Anlam |
| --- | --- |
| customer_app | Müşteri kendi hesabından oluşturdu. |
| sales_operator | Saha satış personeli müşteri adına oluşturdu. |

Her iki kaynak aynı OrderService/backend transaction'ını kullanır. İki ayrı sipariş mantığı oluşturulmaz.

## 9 Sipariş state machine

```text
draft
  ↓
pending_operator_review
  ↓
confirmed
  ↓
preparing
  ↓
ready_for_dispatch
  ↓
loaded
  ↓
out_for_delivery
  ↓
delivery_pending_confirmation
  ↓
delivered

Yan/exception durumları:
cancel_requested
cancelled
item_substitution_pending
delivery_disputed
payment_pending
rejected
```

Her geçiş order_status_history'e yazılır. Yetkisiz doğrudan status UPDATE yasaktır.

## 10 Sipariş değişiklik/iptal

- Müşteri veya Sales Operator değişiklik talebi oluşturabilir.

- İlk MVP'de hazırlanmış/loaded/out_for_delivery sipariş doğrudan değiştirilemez.

- Değişiklik gerekiyorsa exception/change request açılır.

- Order Operator operasyonel olarak onaylar/reddeder.

- Bu kural stok ve fiyat tutarlılığını korur.

## 11 Alternatif ürün

- Warehouse eksik ürün bildirir.

- Sales Operator müşteriye alternatif sunar.

- Müşteri Kabul / Reddet / Miktarı Değiştir seçeneklerinden birini seçer.

- Reddedilirse yalnızca ilgili item çıkarılır.

- Kabul edilirse alternatif ürün yeni item olarak history ile kaydedilir.

## 12 Stok modeli

```text
inventory:
physical_qty
reserved_qty
available_qty = physical_qty - reserved_qty

Sipariş:
available → reserved

Hazırlama:
reserved → picked

Araca yükleme:
picked → dispatched

İptal:
reserved → available

Mal kabul:
received → available

Sayım:
system_quantity → counted_quantity → adjustment approval → final_quantity
```

Fiziksel stok ile kullanılabilir stok birbirinden ayrılır. Her hareket inventory_movements ile immutable geçmiş olarak tutulur.

## 13 Haftalık sayım

- Warehouse sayım oturumu açar.

- Ürünlerin gerçek miktarını girer.

- Farklar hesaplanır.

- Farkın nedeni/notu yazılabilir.

- Adjustment onayı Manager/Owner yetkisindedir.

- Onay sonrası inventory final miktarı güncellenir.

- Eski değer, yeni değer ve yapan/onaylayan kullanıcı audit edilir.

## 14 Mal kabul

- Malı Warehouse sisteme alır.

- Ürün, miktar, birim, tedarik/evrak notu ve zaman kaydı tutulur.

- Stok movement oluşturulur.

- Fiziksel ve kullanılabilir stok artırılır.

- İlk MVP'de satın alma siparişi modülü zorunlu değildir.

## 15 Dağıtım

- Bir araçta primary_driver + assistant_driver olabilir.

- Bir delivery_run tek araçla ilişkilidir.

- Driver durak sırasını kendisi değiştirebilir.

- Manager realtime olarak değişen sırayı görebilir.

- Bir siparişin iki araca bölünmesi database modelinde desteklenebilir; MVP'de kapalı tutulur.

- Ürünler araca yüklendikten sonra loaded durumu oluşur.

## 16 Canlı GPS

- GPS yalnızca out_for_delivery sırasında aktif.

- Android background location desteği gerekir.

- Başlangıç hedefi 10–15 saniye; bağlantı/pil durumunda adaptif aralık uygulanabilir.

- GPS izni kapatılırsa Manager uyarılır.

- Driver'a tekrar izin verme akışı gösterilir.

- Teslimat/sefer tamamlanınca GPS paylaşımı kapatılır.

- Customer sadece kendi siparişine atanmış aktif aracı görebilir.

- Map ekranı sadece araç marker'ı + son güncelleme zamanını gösterir.

## 17 Teslimat

```text
Driver:
Yola çıktı
   ↓
Müşteriye ulaştı
   ↓
Teslimatı tamamla

Customer:
Teslim aldım
veya
Teslim almadım → dispute

Normal:
driver_confirmed + customer_confirmed
             ↓
          delivered

Uyuşmazlık:
delivery_disputed
             ↓
          Manager
             ↓
delivered / failed / returned
```

Müşteri uygulamayı açmazsa Driver'ın tek başına teslimatı kesinleştirmesi önerilmez; exception olarak Manager onayı gerekir.

## 18 Teslimat kanıtı

- Normal teslimatta fotoğraf/imza/QR zorunlu değildir.

- Uyuşmazlık halinde Driver fotoğraf gibi opsiyonel kanıt yükleyebilir.

- Manager uyuşmazlığı inceler.

- Kanıt dosyaları Storage'da erişim kontrollü tutulur.

## 19 Ödeme

| Alan | Kural |
| --- | --- |
| Normal tahsilat | Sales Operator |
| İstisnai tahsilat | Başka yetkili çalışan; collector kaydı zorunlu |
| Yöntem | cash / POS |
| Doğrulama | Accounting |
| Driver | Normalde ödeme almaz |
| Fatura PDF | MVP dışında |

Payment kaydında sipariş, tutar, yöntem, fiilen tahsil eden kullanıcı, tahsil zamanı, doğrulayan muhasebe kullanıcısı, durum ve not bulunur.

## 20 Puanlama

- Customer yalnızca Driver'ı puanlar.

- 1–5 yıldız.

- Reason codes: geç geldi, davranış, ürün eksikliği, hasar, diğer gibi seçenekler.

- İsteğe bağlı yorum.

- Bir sipariş için bir puan.

- Manager/Owner aggregate sonuçları görebilir.

## 21 Büyük indirim bildirimi

Fiyat değişikliği ile kampanya indirimi ayrılır.

- Normal fiyat değişimi herkese bildirim göndermez.

- Manager/Owner bir kampanya/büyük indirim olayı oluşturabilir.

- Hedef müşteri grubu seçilebilir.

- Push bildirimi ürün/kampanya detayına deep-link verir.

- Bildirim geçmişi notifications tablosunda tutulur.

## 22 Bildirim olayları

| Olay | Alıcı | Deep link |
| --- | --- | --- |
| Yeni sipariş | Sales Operator / Warehouse | Sipariş detayı |
| Sipariş onaylandı | Customer | Sipariş detayı |
| Alternatif ürün | Customer | Alternatif teklif |
| Hazırlanıyor | Customer | Sipariş detayı |
| Teslimata hazır | Driver/Manager | Sefer |
| Yola çıktı | Customer | Canlı takip |
| GPS sorunu | Manager | Driver/sefer |
| Teslim uyuşmazlığı | Manager | Uyuşmazlık |
| Teslim edildi | Customer | Sipariş/puan |
| Büyük indirim | Hedef müşteriler | Ürün/kampanya |
| Cari limit aşımı | Customer / Accounting | Cari/sipariş |

## 23 Ekran envanteri

| Rol | Ekranlar |
| --- | --- |
| Customer | Login, Home, Categories, Products, Product Detail, Cart, Checkout, Orders, Order Detail, Live Delivery, Delivery Confirmation, Rating, Profile |
| Sales Operator | Dashboard, Customers, Customer Detail, Catalog, Create Order, Order Detail, Alternative Offer, Payments, Customer History |
| Warehouse | Dashboard, Order Queue, Picking, Missing Item, Products, Price Management, Receiving, Inventory, Stock Count, Movements |
| Accounting | Dashboard, Payments, Payment Verification, Customer Accounts, Credit Limit, Price Management, Reports |
| Driver | Today's Run, Stops, Stop Detail, Navigation Handoff, GPS Status, Delivery Confirmation, Exception |
| Manager | Dashboard, Orders, Inventory, Deliveries, Live Vehicles, Customers, Employees, Ratings, Discounts, Reports |
| Owner | All Manager screens + Finance, Salary/Bonus, Settings, Audit Log |

## 24 Kritik ekran davranışları

### Customer – ürün

```text
Liste fiyatı: 100 TL
Size Özel %8
Final: 92 TL

[+] Sepete ekle
```

### Sales Operator – saha siparişi

```text
Müşteri seç
 ↓
Müşteri fiyat seviyesini yükle
 ↓
Katalog
 ↓
Ürün seç
 ↓
Miktar
 ↓
Stok/minimum kontrol
 ↓
Sepete ekle
 ↓
Müşteri adına sipariş oluştur
```

### Warehouse – hazırlama

```text
Sipariş
 ↓
Pick list
 ↓
Her item: bekleniyor / toplandı / eksik
 ↓
Eksik varsa Sales Operator'a bildir
 ↓
Hazır
 ↓
ready_for_dispatch
```

### Driver – sefer

```text
Seferi aç
 ↓
Yükleme tamam
 ↓
loaded
 ↓
Yola çık
 ↓
GPS başlat
 ↓
Stop sırası
 ↓
Teslim
 ↓
Karşılıklı onay
```

## 25 Database modeli

| Tablo | Ana alanlar |
| --- | --- |
| profiles | id, role, name, email, phone, active |
| customers | id, company_name, customer_type, contact_name, phone, email, address, tax_no, tax_office, active, notes |
| customer_users | customer_id, user_id, active |
| products | id, sku, name, category_id, description, package_label, base_unit, min_quantity, list_price, active |
| product_units | id, product_id, unit_name, conversion_to_base, orderable |
| pricing_rules | id, name, threshold, discount_rate, active |
| customer_pricing | customer_id, discount_rate, source, effective_from |
| orders | id, customer_id, created_by, source, status, subtotal, discount_total, total, credit_warning, created_at |
| order_items | id, order_id, product_id, quantity, unit, list_price_snapshot, discount_snapshot, final_price_snapshot |
| order_status_history | id, order_id, from_status, to_status, changed_by, reason, created_at |
| alternative_offers | id, order_item_id, offered_product_id, offered_qty, status, responded_by |
| inventory | product_id, physical_qty, reserved_qty, available_qty |
| inventory_movements | id, product_id, type, quantity, reference_type, reference_id, created_by |
| stock_counts | id, warehouse_id, created_by, approved_by, status, created_at |
| stock_count_items | stock_count_id, product_id, system_qty, counted_qty, difference |
| delivery_runs | id, vehicle_id, primary_driver_id, assistant_driver_id, status, started_at, ended_at |
| delivery_stops | id, run_id, order_id, sequence, status, arrived_at, completed_at |
| driver_locations | id, run_id, driver_id, latitude, longitude, recorded_at |
| delivery_confirmations | id, order_id, customer_confirmed, driver_confirmed, dispute_reason |
| payments | id, order_id, amount, method, collector_user_id, verified_by, verification_status |
| ratings | id, order_id, customer_id, driver_id, score, reason_codes, comment |
| employee_salary_records | id, employee_id, period, salary, bonus, created_by |
| notifications | id, user_id, type, title, body, entity_type, entity_id, deep_link, read_at |
| app_settings | key, value, updated_by |
| audit_logs | id, actor_id, action, entity_type, entity_id, old_data, new_data, created_at |

## 26 RLS / güvenlik

- Customer sadece kendi customer_id'sine ait veriyi görebilir.

- Customer başka müşterinin fiyatını/siparişini/GPS'ini göremez.

- Sales Operator yalnızca operasyon için gerekli müşteri ve sipariş verisini görür.

- Driver yalnızca kendisine bağlı run/stop/order/GPS kayıtlarını görebilir.

- Manager operasyonel tüm veriyi görebilir.

- Owner tüm veriyi görebilir.

- Salary records Owner-only.

- service_role key APK'ya kesinlikle konulmaz.

- Fiyat client'tan kabul edilmez.

- RLS olmayan hassas tablo production-ready kabul edilmez.

## 27 Audit

Şu işlemler audit edilmelidir:

- Fiyat değişimi

- İskonto değişimi

- Sipariş state değişimi

- Sipariş değişikliği/iptali

- Stok düzeltmesi

- Sayım onayı

- Ödeme doğrulaması

- Cari limit aşımı/onayı

- Rol/permission değişimi

- Maaş/prim değişimi

- Büyük indirim kampanyası

- Teslimat uyuşmazlığı çözümü

## 28 Önerilen Flutter mimarisi

```text
lib/
  core/
    auth/
    config/
    errors/
    networking/
    routing/
    theme/
    permissions/
    notifications/
    realtime/
    location/
  features/
    auth/
    customer/
    products/
    pricing/
    orders/
    inventory/
    delivery/
    payments/
    ratings/
    employees/
    reports/
    owner/
  shared/
    widgets/
    models/

Her feature:
data/
domain/
presentation/
```

Riverpod state management, go_router navigation ve repository/service ayrımı kullanılacak.

## 29 Supabase mimarisi

- Supabase Auth: email/password.

- PostgreSQL: ana veri.

- RLS: yetkilendirme.

- RPC/Edge Functions: kritik transaction/business logic.

- Realtime: sipariş durumları, delivery state ve GPS.

- Storage: yalnızca gerekli teslimat kanıtları.

- FCM: Android push.

- Mobil uygulamada yalnızca anon/publishable key.

## 30 GPS retention

GPS verisi gereksiz şekilde sınırsız tutulmamalıdır. MVP'de aktif sefer sırasında canlı takip için tutulur; geçmiş raporlama ihtiyacı oluşursa sonradan retention süresi ayarlanır. Customer yalnızca aktif teslimata ait son konumu görür.

## 31 MVP'de özellikle yapılmayacaklar

- Online ödeme

- SMS OTP

- PDF fatura

- Otomatik rota optimizasyonu

- Geocoding

- iOS build

- Çoklu satıcı

- Çoklu depo

- Tam satın alma/tedarikçi yönetimi

- İleri seviye muhasebe ERP

- Zorunlu fotoğraf/imza/QR teslimat

- Bir siparişin iki araca bölünmesi

## 32 Varsayılan olarak kabul edilen açık kararlar

| Konu | Karar |
| --- | --- |
| Sayım farkı onayı | Manager/Owner |
| Tek siparişin iki araca bölünmesi | Veri modeli hazır, MVP kapalı |
| Müşteri uygulamayı açmazsa | Manager exception approval |
| Uyuşmazlık fotoğrafı | Opsiyonel |
| Minimum sipariş tutarı | Yok |
| Minimum ürün miktarı | Ürün bazlı |
| Büyük indirim bildirimi | Kampanya/indirim event'i |
| Müşteri kayıt sonrası | Direkt aktif |

## 33 ChatGPT ve Codex geliştirme fazları

- FAZ 1: Repository + AGENTS.md + docs/SPEC.md + karar ve ilerleme kayıtları. Kabul: kapsam, açık kararlar, klasör yapısı ve komutlar yazılı; henüz uygulama tamamlandı iddiası yok.

- FAZ 2: Flutter iskeleti + tema + routing. Kabul: uygulama açılır; giriş, yükleniyor, boş liste ve hata ekranları çalışır; rol bazlı menü iskeleti hazırdır.

- FAZ 3: Supabase migrations + seed. Kabul: boş veritabanı migration ile kurulabilir; yedi rol için sentetik test kullanıcıları ve örnek kayıtlar bulunur.

- FAZ 4: Auth + RBAC + RLS. Kabul: müşteri ve çalışan oturumları çalışır; yetkisiz rol değişimi, başka müşteri kaydı ve maaş verisi erişimi testlerde reddedilir.

- FAZ 5: Products + units + pricing. Kabul: birim dönüşümleri ve minimum miktar doğrulanır; fiyat backend tarafından hesaplanır; fiyat geçmişi ve sipariş snapshotları test edilir.

- FAZ 6: Customer experience. Kabul: katalog, müşteri fiyatı, sepet ve sipariş oluşturma akışı çalışır; fiyat/stok değişiminde açıklayıcı sonuç gösterilir.

- FAZ 7: Sales Operator saha siparişi. Kabul: müşteri seçilerek aynı backend sipariş servisi kullanılır; source ve created_by doğru kaydedilir.

- FAZ 8: Order workflow + alternatives. Kabul: izinli durum geçişleri, iptal/değişiklik talepleri ve alternatif kabul/ret akışı audit ile doğrulanır.

- FAZ 9: Warehouse + inventory. Kabul: rezervasyon, toplama, yükleme, mal kabulü ve onaylı sayım çalışır; eşzamanlı sipariş stok tutarsızlığı oluşturmaz.

- FAZ 10: Accounting + payments + credit. Kabul: nakit/POS tahsilat, gerçek tahsil eden kişi, muhasebe doğrulaması ve cari uyarı onayı kaydedilir; yinelenen işlem çift kayıt üretmez.

- FAZ 11: Delivery + vehicle + driver. Kabul: araç/sefer/durak ataması, primary ve assistant driver erişimi, yükleme ve sıra değişikliği çalışır.

- FAZ 12: Background GPS + Realtime + MapLibre. Kabul: Android gerçek cihazda ekran kapalıyken takip, izin reddi ve bağlantı kesintisi denenir; müşteri yalnızca kendi aktif teslimatını görür; sefer sonunda paylaşım durur.

- FAZ 13: Delivery confirmation + rating. Kabul: çift onay, uyuşmazlık ve Manager çözümü çalışır; teslim edilmeyen sipariş puanlanamaz; sipariş başına tek puan korunur.

- FAZ 14: FCM notifications. Kabul: hedef kullanıcı/rol, bildirim geçmişi ve deep link çalışır; bildirim kaybı sipariş işlemini geri almaz; yinelenen gönderim kontrol edilir.

- FAZ 15: Manager + Owner + reports. Kabul: operasyon raporları kayıtlarla tutarlıdır; maaş/prim yalnızca Owner tarafından erişilebilir.

- FAZ 16: Uçtan uca test + güvenlik incelemesi. Kabul: yedi rol senaryosu, fiyat/stok/tahsilat yarış durumları, RLS ve dosya erişimi kontrol edilir; açık engelleyici hata kalmaz.

- FAZ 17: Android release APK. Kabul: imzalı sürüm üretilebilir; gerçek cihazda kurulum, oturum, sipariş, bildirim ve GPS denenir; sürüm, kurulum ve yedekleme adımları belgelenir.

## 34 Her Codex fazında kalite kapısı

Her fazda değişikliğe uygun kontroller çalıştırılır. Flutter değişikliklerinde flutter analyze ve ilgili unit/widget testleri; SQL/RLS değişikliklerinde veritabanı, yetki ve transaction testleri; tamamlanan kullanıcı akışlarında integration testleri gerekir. Mobil bağımlılık, platform ayarı veya tamamlanan faz sonrası Android debug build alınır. GPS, bildirim ve release kabulü gerçek cihaz gerektirir.
Fiyat, stok, sipariş ve ödeme değişikliklerinde ilgili regresyon testleri zorunludur. Ölü/tekrarlanan kod, TODO/FIXME ve sırlar kontrol edilir; her TODO bir takip maddesine bağlanır. Hata düzeltilince ilgili test yeniden çalıştırılır.
Rapor: tamamlanan kabul ölçütleri, değişen dosyalar, çalıştırılan komutlar ve sonuçları, çalıştırılamayan kontroller ve nedenleri, kalan riskler ve sonraki adım. Çalıştırılmayan bir test başarılı sayılmaz; ortam engeli varsa faz doğrulama bekliyor olarak kaydedilir.

Bu doküman Codex için iş kurallarının kaynağıdır. ChatGPT kararları açıklamaya ve görevleri hazırlamaya yardımcı olur; Codex erişebildiği depoda kodu, migrationları ve testleri uygular. Çalışma ortamında Flutter/Android SDK veya bağlı cihaz yoksa ilgili kontrolün yerel bilgisayarda çalıştırılması gerekir. Belge yüklemek tek başına depo, Supabase hesabı veya telefon erişimi sağlamaz.

## 35 Depoda tutulacak proje dosyaları

Bu Word belgesi okunabilir ana tasarımdır. Geliştirme başlangıcında aynı kapsam docs/SPEC.md dosyasına aktarılır; iki metin çelişirse fark kullanıcıya bildirilir ve karar kaydedilir. Uygulama sırasında yalnızca sohbet geçmişine dayanılmaz.

AGENTS.md: proje amacı, klasörler, kurulum ve doğrulama komutları, kod kuralları, değiştirilemeyecek iş kuralları ve hassas işlem sınırları.

docs/PLAN.md: fazlar, bağımlılıklar ve kabul ölçütleri; durumlar bekliyor, devam ediyor, doğrulama bekliyor ve tamamlandı.

docs/DECISIONS.md: karar, tarih, gerekçe ve etkilediği kurallar; açık kararlar varsayım olarak açıkça işaretlenir.

docs/PROGRESS.md: son tamamlanan görev, mevcut engel, test sonuçları ve sıradaki somut görev.

docs/TESTING.md: yerel kurulum, test komutları, yedi rol senaryosu ve gerçek cihaz kontrol listesi.

README.md ve .env.example: kurulum ve değişken isimleri; gerçek parolalar, service_role ve imzalama anahtarları depoya veya sohbet metnine yazılmaz.

## 36 ChatGPT ve Codex ile çalışma düzeni

Kullanıcı ürün kararlarını verir ve ekranları değerlendirir. ChatGPT kapsamı ve açık soruları netleştirir; Codex depoyu inceler, sınırlı bir görevi uygular ve kanıtları raporlar. Araçlara erişim olmadığı durumda ChatGPT yalnızca verilen dosyalar ve çıktılar üzerinden değerlendirme yapabilir.

Her görevde amaç, kapsam, bağımlılıklar, kabul ölçütleri ve doğrulama komutları bulunur. Bir faz birden fazla küçük göreve ayrılabilir. Önce çalışan en küçük uçtan uca akış tamamlanır, ardından aynı rolün diğer ekranları eklenir. Mock/sentetik veri ile çalışan ekran gerçek backend entegrasyonu yapılmış sayılmaz.

Codex mevcut dosyaları ve AGENTS.md talimatlarını okuyarak başlar. İlgisiz değişiklikleri korur; migrationları sürümlü tutar; kritik fiyat/stok/ödeme işlemlerini backend transaction içinde yürütür. Kalıcı veriyi silme, canlı veritabanı migrationı ve yayınlama ayrıca kullanıcı tarafından yetkilendirilir. Yerel geliştirme ve test için her dosyada yeniden onay istenmez.

Her görev sonunda ilerleme ve karar dosyaları güncellenir. Yeni sohbette aynı depo, AGENTS.md, SPEC, PLAN ve PROGRESS okunur; son doğrulanmış noktadan devam edilir. Sohbetin önceki adımları hatırladığı varsayılmaz.

## 37 Kodlamadan önce netleştirilecek iş kuralları

Aşağıdaki konular kaynak belgedeki kapsamı değiştirmez; eksik formülleri ve durum sınırlarını görünür kılar. İlgili faz başlamadan karar kaydı gerekir. Bağımsız iskelet ve ekran çalışmaları sürdürülebilir.

İskonto: son üç ayın haftalık performansı için takvim aralığı, alışverişsiz haftalar, teslim edilmiş/ödenmiş sipariş seçimi, iade etkisi ve 50K/70K/100K eşiklerinin toplam mı ortalama mı olduğu tanımlanmalıdır. Bu değerler yalnızca test eşikleridir.

Cari: referans limit formülü, borcun hangi anda oluştuğu, doğrulanmamış tahsilatın etkisi ve kısmi ödeme/fazla tahsilat kuralları belirlenmelidir. Kaynaktaki uyarı ve devam edebilme davranışı korunur.

Stok: rezervasyonun hangi sipariş durumunda başladığı, picked miktarının reserved içinde sayılıp sayılmadığı, physical stoktan düşüm anı ve iptal/iade telafisi belirlenmelidir. available_qty tutarlı türetilmeli; aynı rezervasyon iki kez tüketilmemelidir.

Sipariş durumları: payment_pending ödeme boyutudur; cancel_requested ve item_substitution_pending devam eden talepler olabilir. Ana sipariş statusu, ödeme statusu ve exception/talep kayıtlarının eşlemesi kararlaştırılmalıdır. failed/returned teslimat sonuçlarının da geçişleri tanımlanmalıdır.

Veri modeli: kategoriler, araçlar, çalışan daveti, değişiklik talepleri, bildirim cihaz tokenları ve sayımdaki warehouse_id referansı için eksik tablolar/FK ilişkileri tamamlanmalıdır. Tek depo kapsamı korunur.

GPS: güncel konum ile geçmiş ayrılmalı; tutma ve silme süresi, eski konum uyarısı ve erişimin bitiş anı belirlenmelidir. Harita sağlayıcısı ve gerçek cihaz izin davranışı uygulama fazında doğrulanmalıdır.

Para ve güvenilir işlem: TL hassasiyeti, iskonto yuvarlama noktası, birim dönüşüm hassasiyeti, tekrar denemede idempotency ve transaction kilitleme kuralları teknik karar olarak yazılmalıdır.

## 38 Codex başlangıç görevi

Aşağıdaki metin, belge ve proje deposu erişilebilir olduğunda ilk görev olarak kullanılabilir.

Pekşen Gıda projesini bu teknik tasarıma göre geliştir. Önce mevcut depoyu ve varsa AGENTS.md dosyasını incele. İş kapsamını ve Flutter/Supabase mimarisini koru. Bu görevde yalnızca Faz 1’i tamamla: AGENTS.md, README.md, docs/SPEC.md, docs/PLAN.md, docs/DECISIONS.md, docs/PROGRESS.md ve docs/TESTING.md dosyalarını oluştur veya mevcut içerikle birleştir. Belgedeki açık kararları işaretle; iskonto, cari ve stok formüllerini kendiliğinden uydurma. Ortamda bulunan araçları kontrol et ve eksik Flutter/Android/Supabase gereksinimlerini raporla. Uygulama modüllerini henüz topluca yazma. Sonunda oluşturulan dosyaları, Faz 1 kabul ölçütlerini, engelleri ve Faz 2’nin ilk somut görevini raporla.

## 39 Sonraki görev ve devam metni

AGENTS.md, docs/SPEC.md, docs/PLAN.md, docs/DECISIONS.md ve docs/PROGRESS.md dosyalarını oku. Son doğrulanmış adımdan devam et. Sıradaki görevin amacını ve kabul ölçütlerini belirle, yalnızca o görevi uygula. Mevcut iş kurallarını değiştirme; ilgili kritik karar eksikse bağımsız çalışmayı sürdür ve gerekli soruyu belirt. Değişikliğe uygun testleri çalıştır, çalıştıramadıklarını açıkça yaz ve ilerleme kaydını güncelle.

