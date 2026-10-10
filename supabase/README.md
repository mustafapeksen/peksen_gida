# Pekşen Gıda yerel backend

**Faz 8 / F8-02:** Onuncu migration gerçek submitted iptalini korur. On birinci `20261010000100_order_review.sql` alternatif **niyeti** ve Manager/Owner **talep kararı** ekler. `propose_order_alternative` aktif atanmış Sales; `respond_order_alternative` kendi aktif Customer; `decide_order_request` Manager/Owner ve submitted+pending talep içindir. Karar notu/aktör/zaman zorunlu; `request_decided` history olayı sipariş geçişi değildir. Karar/alternatif kabulü kalem/fiyat/rezervasyonu değiştirmez. Gerçek revizyon/picking sonrası telafi bekler. Ham yazmalar/anon kapalı; private receipt istemciye açılmaz. Eski immutable kararlara not uydurulmaz; NOT VALID CHECK yeni yazmalarda zorunlu kanıtı denetler. F8-02 ve doğrulama ayrıntıları docs/DECISIONS/PROGRESS/TESTING başındadır.

Yerel reset sonrası yeni paket: `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/order_review_test.sql`. Önceki workflow, checkout, pricing, business, auth_access ve account_scope paketleri ilgili regresyonlardır. Yeni 62 + ilgili 618 assertion başarılıdır; gerçek kalem/stok revizyonu test edilmiş sayılmaz.

**Faz 7:** `20261009000300_sales_checkout.sql`, `private.sales_customer` yardımcısını aktif + atanmış müşteriyle sınırlar; eski creator-only erişimi kaldırır. Var olan RLS/quote/checkout kontrolleri bu sınırı kullanır. Yeni `sales_checkout_customers()` yalnız Sales'e ID/firma adı döndürür. Mevcut ilk sekiz migration/iki seed korunur. Yeni `sales_checkout_test.sql` 50 test; ilgili auth paketi 119 testtir. Yerel doğrulama komutları ve F7-01 sınırı TESTING/DECISIONS başındadır.

**Faz 6 — Customer checkout:** Sekizinci migration `20261009000200_customer_checkout.sql`; `customer_catalog`, `quote_cart`, `save_cart_draft`, `load_cart_draft`, `checkout_cart` yalnız mevcut Customer/Sales kapsamı içinde çalışır. `private.cart_drafts` ve `private.checkout_receipts` istemciye açık değildir. `orders.credit_check_state=not_evaluated` kesin borç/cari sonucu değildir. Yeni `customer_checkout_test.sql` 94 assertion içerir. Yerel reset sonrası `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/customer_checkout_test.sql` çalıştırılır. Fiyat/minimum/exact snapshot sözleşmesi F5-01, transaction/rezervasyon/yeniden onay F6-01'de; mevcut public ham yazma/RLS sınırları korunur.

**9 Ekim 2026 — Faz 5:** Yedinci migration `20261009000100_product_pricing.sql` eklendi. İlk altı migration ve iki seed korunur. Ürünler fiyatsız/pasif başlayabilir; Manager/Owner `change_product_price` ile history/audit üretip `activate_product` ile satışa açar. `create_product_draft`, `product_categories`, `product_reference_list`, `product_price_events` dar yetkili RPC'lerdir; ham yazmalar açılmaz. `quote_product(customer, unit, integer quantity)` fiyat/iskonto parametresi kabul etmez; exact dönüşüm ve snapshot, taban minimumu ve Istanbul yürürlük günü kullanır. Quote rezervasyon veya kalıcı sipariş değildir. `product_pricing_test.sql` yeni 73 regresyon içerir. Yerel reset/test sonuçları ve ilk ortam hatası docs/TESTING başındadır. Çeyrek önerisi veya ticari eşik eklenmedi.

## Kayıt/davet devamı — 7 Ekim 2026

Güncel sözleşme F4-05/F4-06'dır. Altıncı migration `20261007000100_account_onboarding.sql` kayıt trigger'ı, private davet tablosu ve denetlenen davet/aktivasyon RPC'lerini ekler. 35 public tablo, önceki beş migration ve iki seed korunur. Ham yazmalar/anon erişimi açılmaz. E-posta sahipliği doğrulanır; müşteri profilinin aktif oluşması doğrulanmadan oturum açılabildiği anlamına gelmez. Owner-only pasifleştirme/yeniden açma, son Owner ve açık iş korumaları uygulanır.

Yerelde signup/e-posta onayı açık, minimum parola 8 karakter; SDK/backend üst sınırı 72 UTF-8 bayttır. Mailpit **55324**, Edge runtime açıktır. Config değişmiş eski servis için önce `stop`, sonra `start` gerekir. E-posta şablonları `templates/code.html`; 6 haneli kod uygulamaya girilir. PKCE doğrulayıcısı şifreli platform deposundadır. `functions/invite-account` Auth token'ını sunucuda doğrular ve DB rol kontrolünden sonra runtime Admin API ile davet gönderir. Server credential istemciye veya dosyaya kopyalanmaz. Üretim SMTP/ilk Owner temini bu yerel kontrolün sonucu değildir.

Önce aşağıdaki reset ve dört eski DB testini çalıştırın; ardından:

```powershell
npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/account_onboarding_test.sql
if ($LASTEXITCODE -ne 0) { throw 'Hesap yaşam döngüsü başarısız' }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File supabase/tests/run-local-auth-check.ps1
if ($LASTEXITCODE -ne 0) { throw 'Auth oturum testi başarısız' }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File supabase/tests/run-local-auth-check.ps1 -TestFile account_onboarding_client_test.dart
if ($LASTEXITCODE -ne 0) { throw 'PKCE/kayıt/davet testi başarısız' }
```

DB testleri **19 + 140 + 117 + 85 + 54 = 415 PASS**; SDK oturum **9/9**, onboarding **4/4 PASS**, tüm çıkışlar 0. DB kontrolleri SDK testlerinden önce çalıştırılır: pgTAP fixture'ları rollback olur, SDK akışı yerel sentetik yeni müşteri/davet kayıtlarını bırakır. SDK scriptleri aynı anda çalıştırılmaz; sekiz seed hesabının geçici credential hash'leri sonunda geri yüklenir. Sonradan yeniden DB temelini sınamak için yalnız bu sentetik hedefte reset gerekir. Host testinde yalnız native secure-storage plugin'i mock'tur; HTTP, Auth, e-posta kodu, Edge ve DB gerçektir. Bu sonuç Android'de gerçek hesapla yeniden açılış/görsel kabul değildir.

Aşağıdaki eski “kayıt kapalı / beş migration / yaşam döngüsü yok” ifadeleri önceki doğrulama tarihçesidir.

## Güncel Faz 4 — 7 Ekim 2026

`20261006000100_account_conversion_scoped_reads.sql` beşinci migration'dır; önceki dört migration ve iki seed değişmez. F4-04: `convert_account_role` yalnız Owner için iki yönlü müşteri–çalışan dönüşümü yapar; eski üyelikleri silmez, açık atamalar varken çalışanı müşteriye dönüştürmez. Accounting yalnız atanmış müşterinin onaylı alanlarını/tahsilatlarını; Warehouse ürün/stok/sayım ve submitted/picking/picked hazırlık alanlarını okur. Sütun ayrımı typed RPC, güvenli stok tabloları SELECT RLS ile uygulanır. Ham yazmalar/anon kapalı kalır. Tam RPC/alan sözleşmesi [DECISIONS F4-04](../docs/DECISIONS.md) içindedir. Yeni `account_scope_test.sql` 85 regresyon içerir. Aşağıdaki önceki Warehouse/Accounting eksik kapsam cümleleri tarihçedir; kayıt/davet ve kalıcı oturum halen bekler.

Önceki üç migration ve iki seed korunur; `20261004000300_auth_read_access.sql` tamamlandı. 35 tablo var; customers'a oluşturucu ve Sales ataması FK/index'leri eklendi. RLS read politikaları, private rol/üyelik/atama yardımcıları ve sınırlı rol/müşteri yönetimi RPC'leri bulunur. Anonim erişim ve doğrudan tablo yazmaları kapalıdır. Yetki matrisi, açık noktalar ve RPC sözleşmesi [DECISIONS F4-01–F4-03](../docs/DECISIONS.md) içindedir. **Faz 4 tam bitmedi:** müşteri self-signup, çalışan Auth credential/davet ve yaşam döngüsü tamamlanmadı. Profil/üyelik RPC'leri mevcut Auth identity UUID'siyle çalışır; kullanıcı adı/parola üretmez. Warehouse iş erişimi ve Accounting'in tam finans alan matrisi henüz açılmadı.

**Port değişikliği:** Windows 54310–54409 aralığını ayırdığı için API **55321**, DB **55322**, shadow **55320** kullanılır. Android emulator adresi `http://10.0.2.2:55321`; host adresi `http://127.0.0.1:55321`. Aynı sentetik `peksen_gida_phase3_local` projesi, cloud link yok. Eski çalışan servis varsa yeni portları almak için `stop` ve `start` gerekir. Config signup'ı kapalı tutar; secret istemciye/depo/sohbete yazılmaz.

Depo kökünde PowerShell ile, yalnız yeniden oluşturulabilir yerel seed için:

```powershell
# Servisler kapalıysa: npx.cmd --yes supabase@2.119.0 start
npx.cmd --yes supabase@2.119.0 db reset --local
if ($LASTEXITCODE -ne 0) { throw 'Reset başarısız' }
npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/identity_foundation_test.sql
if ($LASTEXITCODE -ne 0) { throw 'Identity başarısız' }
npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/business_foundation_test.sql
if ($LASTEXITCODE -ne 0) { throw 'Business başarısız' }
npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/auth_access_test.sql
if ($LASTEXITCODE -ne 0) { throw 'Auth/RLS başarısız' }
npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/account_scope_test.sql
if ($LASTEXITCODE -ne 0) { throw 'Dönüşüm/alan yetkileri başarısız' }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File supabase/tests/run-local-auth-check.ps1
if ($LASTEXITCODE -ne 0) { throw 'Gerçek yerel Auth kontrolü başarısız' }
```

Reset beş migration ve değişmemiş iki seed'i uygular. pgTAP fixture'ları rollback olur. Gerçek Auth scripti yalnız sabit yerel hedefte sekiz `.invalid` hesabı denetler; rastgele test girdisini process belleğinde tutar, SDK ile giriş/DB profil/refresh/çıkış sınar, parola hash'lerini finally bloğunda geri yükler. Script zorla kesilirse yerel `db reset --local` yapın. Hiçbir gerçek hesap veya üretim hedefinde kullanılmaz. Bu HTTP/SDK kanıtı Android'de gerçek girişin görsel kabulü değildir.

**Önceki Faz 3 kurulum/kabul tarihçesi aşağıdadır.** Eski 543xx portları, policy yokluğu ve giriş kapalı ifadeleri güncel Faz 4 sınırlarının yerine geçmez.

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
