# Faz 3 yerel backend temeli

## Güncel kapsam — 4 Ekim 2026 onaylarından sonra

**Faz 3 migration/seed kabulü tamamlandı:** 25/25 kaynak tablo + 10 yardımcı tablo. İlk identity migration/seed/19 test değişmedi. Yeni business migration ve seed config'e eklendi; reset **0**, identity **19/19 PASS / 0**, business **97/97 PASS / 0**. Aşağıdaki eski üç tabloluk/ortam bekleyen açıklamalar tarihçedir. Gerçek Auth/iş servisleri yapılmadı; 35 tabloda RLS açık, istemci grant kapalı, izin veren policy yoktur.

### Güncel tekrar doğrulama

Çalışan Docker Desktop Linux motorunda, yalnız sentetik `peksen_gida_phase3_local` hedefinde depo kökünden:

```powershell
# Servisler kapalıysa önce: npx.cmd --yes supabase@2.119.0 start
npx.cmd --yes supabase@2.119.0 db reset --local
if ($LASTEXITCODE -ne 0) { throw 'Reset başarısız' }
npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/identity_foundation_test.sql
if ($LASTEXITCODE -ne 0) { throw 'Identity testleri başarısız' }
npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/business_foundation_test.sql
if ($LASTEXITCODE -ne 0) { throw 'Business testleri başarısız' }
```

Reset iki migration, ardından `seed.sql → seeds/business_foundation.sql` uygular. Testler rollback yapar. Başka/gerçek veri içeren hedefte reset kullanılmaz; cloud link/db push yoktur. CLI start/status çıktısı credential içerebilir; paylaşılmaz.

### Tablolar

| Dilim | Tablolar |
| --- | --- |
| Korunan kimlik | profiles, customers, customer_users |
| Ürün/fiyat | products, product_units, pricing_rules, customer_pricing |
| Sipariş | orders, order_items, order_status_history, alternative_offers |
| Stok | inventory, inventory_movements, stock_counts, stock_count_items |
| Dağıtım | delivery_runs, delivery_stops, driver_locations, delivery_confirmations |
| Diğer kaynak tablolar | payments, ratings, employee_salary_records, notifications, app_settings, audit_logs |
| 10 yardımcı | categories, warehouses, vehicles, product_price_history, pricing_proposals, order_approvals, order_change_requests, order_returns, order_return_items, payment_adjustments |

Customers'a nullable `credit_limit_kurus/payment_due_days` eklendi. Para bigint kuruş, stok/dönüşüm exact numeric, miktar/picked integer'dır. Kaynak para alanları açık `_kurus` isimleriyle eşlenir; snapshot adları `unit_price_kurus/discount_rate_snapshot/final_unit_price_kurus/line_total_kurus`. Available ve sayım difference üretilen alanlardır. Kritik olaylarda operation_key UNIQUE; tekrar kayıt ret edilir, replay API'si yoktur. Atama geçmişi/iki aktif stop engeli ve immutable geçmiş trigger'ları bulunur. [Tam teknik sözleşme ve açık kararlar](../docs/DECISIONS.md#t-12--onaylı-kararların-faz-3-şema-karşılığı).

| İzinli ayar | Tip/aralık | Anlam |
| --- | --- | --- |
| default_payment_due_days | JSON integer sayı, 0..2147483647; string/null/fraction kabul edilmez | Müşteri override'ı yoksa vade günü. Aralık integer saklama sınırıdır, ticari üst sınır onayı değildir. Onaylı değer yok, seed boştur; gelecek servis gizli fallback seçemez. |

Sentetik örnek tutarlar ticari değer değildir. Pasif zero iskonto fixture'ı canlı kural olmaz. İki ürün/üç birim, sıfır stok, kısmi picking, hareket toplamlarıyla tutarlı stok, taslak/onay isteği, driver+customer teslimat olayı ve kısmi ödeme bulunur. GPS/ayar/düzeltme seed'i kasıtlı boştur. Ayar/düzeltme kontrolleri rollback testlerinde yapılır. Sekiz Auth hesabı/yedi rol/iki müşteri korunur.

97 test şema bütünlüğünü sınar; gerçek transaction, fazla ödeme/yarış kontrolü, payment_status/borç senkronizasyonu, çeyrek hesaplama, rol yetkisi, GPS/push/Storage kabulü değildir. Sonuçlar [TESTING](../docs/TESTING.md) ve [PROGRESS](../docs/PROGRESS.md) başındadır.

## İlk identity diliminin tarihsel kurulum kaydı

Bu dizin **tam iş şeması değildir**. `20261003000100_identity_foundation.sql`, SPEC §2/3/25'te açık olan yedi rolü ve `profiles`, `customers`, `customer_users` tablolarını kurar. Diğer 22 kaynak tablosu ve eksik varlıklar, DECISIONS A-01–A-13'teki bağımlılıklar çözülmeden üretilmez. Fiyat, stok, sipariş veya cari formülü yoktur.

Supabase CLI **2.119.0**, yerel PostgreSQL **17** yapılandırması seçildi. CLI, `npx.cmd --yes supabase@2.119.0` üzerinden çalıştırılır; uygulamaya Node bağımlılığı eklenmez. `project_id = "peksen_gida_phase3_local"` sadece yeniden kurulabilir sentetik geliştirme ortamı içindir. Cloud proje linki yoktur.

## Kurulum ve DB doğrulaması

**Durum: mevcut üç tablonun yerel backend doğrulaması başarılı.** 4 Ekim 2026'da Docker Desktop Linux motoruyla `start` çıkış **0**, `db reset --local` çıkış **0**, mevcut DB testi **19/19 PASS / çıkış 0** verdi. Önceki **blocked by local Supabase runtime** engeli giderildi. Migration/seed/test dosyaları değiştirilmeden çalıştırıldı. Kanıtlar `build/phase3-db-validation-20261004/` altında, kalıcı sonuçlar [PROGRESS](../docs/PROGRESS.md) ve [TESTING](../docs/TESTING.md) içindedir. **Faz 3'ün tamamı bitmedi:** kalan 22 tablo ve açık şema kararları bekliyor.

Tekrar çalıştırma için Docker Desktop'ın Linux containers motoru veya çalışan Podman machine gerekir. Önceki Docker/Podman yokluğu nedeniyle alınan start çıkış 1, tarihsel kayıttır; güncel sonuç değildir.

Depo kökünden, yalnız bu projeye ayrılmış yerel hedefte:

```powershell
npx.cmd --yes supabase@2.119.0 start
if ($LASTEXITCODE -ne 0) { throw 'Supabase start başarısız; burada durun.' }
# Aşağıdaki reset yalnız yeniden oluşturulabilir sentetik yerel veriyi siler.
# Mevcut gerçek veri veya canlı hedefte kullanılmaz.
npx.cmd --yes supabase@2.119.0 db reset --local
if ($LASTEXITCODE -ne 0) { throw 'Migration/seed başarısız; burada durun.' }
npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/identity_foundation_test.sql
if ($LASTEXITCODE -ne 0) { throw 'DB testleri başarısız; burada durun.' }
```

`db reset --local` sırasıyla migration ve `seed.sql` uygular. Seed boş veritabanına yöneliktir; tekrar doğrudan SQL çalıştırmak yerine yerel reset kullanılır. `db push`, `link`, uzak DB URL'si veya cloud kullanıcı oluşturma çalıştırılmaz. CLI durum çıktısı ayrıcalıklı yerel anahtarlar içerebilir; çıktıyı depoya/sohbete kopyalamayın.

4 Ekim statik incelemesinde migration/seed değişikliği gerektiren somut hata bulunmadı; 19 assertion ile test planı eşleşti. CLI yardım kontrollerinin ardından gerçek yerel migration/seed ve 19 DB testi de başarıyla tamamlandı. Auth sistem tabloları, pgcrypto, pgTAP ve test rolünün yetkileri mevcut seed/testin kullandığı kapsamda çalıştı. `db lint --local` çalıştırılmadı; ayrıca çalışan veritabanı ister. Ayrıntılı önkoşullar ve Docker'sız yapılabilen kontroller [TESTING](../docs/TESTING.md) içindedir. Son belge tamamlama adımında başarılı DB komutları tekrarlanmadı.

## Şema ve sentetik veriler

- `profiles.id → auth.users.id`; rol yalnız `public.app_role` enum'udur. `auth.users.role` Supabase'in `authenticated` değeridir, iş rolü değildir.
- Müşteri üyeliği ayrı tabloda kalır. Kuruluş başına tek kullanıcı için `unique(customer_id)` vardır; kayıt silmede zincirleme veri kaybı yaratacak cascade yoktur. Alan zorunlulukları ve silme/üyelik işlemleri için sonraki politika ayrıntıları DECISIONS T-09/A-14'tedir.
- Sekiz sentetik Auth kullanıcısı ve e-posta identity'si yedi rolü kapsar; iki müşteri kuruluşu ve iki üyelik örneği vardır. E-postalar yalnız `@peksen.invalid` alanındadır; gerçek telefon/vergi bilgisi girilmez.
- Her hesabın parolası seed sırasında rastgele üretilip yalnız hash'i saklanır; kullanılabilir parola depoya veya çıktıya yazılmaz. Bu kullanıcılar DB/yetki test fixture'larıdır; bu fazda UI giriş hesabı değildir.
- Üç tabloda RLS açıktır; istemci grant'leri geri alınmıştır ve izin veren policy yoktur. Bu geçici kapalı temel Faz 4'ün RBAC/RLS uygulaması değildir. Signup, otomatik profil/rol atama, çalışan daveti ve iş RPC'leri yoktur.
- `tests/database/identity_foundation_test.sql`: 19 pgTAP kontrolü; roller, sentetik kayıtlar, Auth FK/identity, kuruluş başına kullanıcı, RLS ve kapalı istemci erişimi. **4 Ekim 2026: 19/19 PASS, çıkış 0.** Bu, Faz 4'ün gerçek oturum/rol izin matrisi kabulü değildir.

## Flutter bağlantısı

Kökteki `.env.example`, `--dart-define-from-file=.env` için boş şablondur. Android emülatörü host'a `http://10.0.2.2:54321`, host araçları `http://127.0.0.1:54321` üzerinden ulaşır. HTTP yalnız debug modunda yerel adreslere izinlidir; diğer hedeflerde HTTPS gerekir. Public publishable veya legacy anon anahtarı kullanılır; secret/service_role kullanılmaz.

İstemci başlangıcı sunucu erişimi veya migration başarısı kanıtlamaz. Gerçek giriş, token yenileme/kalıcı oturum saklama, signup ve yetkilendirme Faz 4'e aittir. Bu fazda gerçek bağlantı değeri girilmedi; preview değerler olmadan çalışır.

Kaynaklar: [yerel geliştirme](https://supabase.com/docs/guides/local-development), [migration ve seed](https://supabase.com/docs/guides/local-development/seeding-your-database), [Flutter istemci başlangıcı](https://supabase.com/docs/reference/dart/initializing).
