# Pekşen Gıda yerel backend

**Faz 15 / F15-01:** On sekizinci migration `20261013000200_management_reports.sql`: Manager/Owner `management_report(start_day,end_day)`; yalnız Owner `owner_salary_workspace(target_month)`, `save_salary(...)` ve `owner_audit_page(before_time,before_id)`. Yeni iki private yardımcı tablo maaş revizyon geçmişi ve idempotency yanıtıdır; public tablo sayısı 35'tir. Ham yazma grant'i eklenmedi; eski RLS politikaları ve seed değişmedi. Çalışan+ay tekilliği/ay başı ve revision korunur, eski hatalı veriler sessizce dönüştürülmez. Rapor RPC'si mevcut kayıtları tek statement snapshot'ından okur. Maaş işlemi operasyon, ödeme veya bildirim üretmez.

Yerel kontroller: `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/management_reports_test.sql` (95 assertion); `python supabase/tests/client/salary_concurrency_test.py` (iki gerçek bağlantı); `powershell -NoProfile -ExecutionPolicy Bypass -File supabase/tests/run-local-auth-check.ps1 -TestFile reports_client_test.dart` (gerçek Auth/SDK). Concurrency/SDK yalnız sentetik local reset sonrası çalıştırılır; committed fixture'lar sonrasında reset ile temizlenir. Tüm sonuçlar [TESTING](../docs/TESTING.md) başındadır. Faz 16 ve geçmiş fazların açık gerçek cihaz/üretim kabulleri bu kapsamda değildir; aşağıdaki Faz 15 yasakları tarihçedir.

**Faz 14 / F14-01:** On yedinci migration `20261013000100_notifications.sql`, private cihaz/session, olay/duyuru/gönderim kuyruğu ve kendi inbox/read/destination RPC'lerini ekler. Bildirim history/alternatif/atama/kampanya kaynaklarından iş transaction'ı sonrasında üretilir. GPS hata olgusu koordinatsızdır; bildirim kayıt arızası tracking'i geri almaz. FCM gönderiminde canlı rol/atama/session tekrar denetlenir; satır kilidi, lease, tekillik ve sınırlı tekrar vardır. FCM exactly-once garantisi verilmez. Owner dahil inbox yalnız sahibine açıktır; diğer iş RLS sınırları değişmez.

Yerel çalışma: `npx.cmd --yes supabase@2.119.0 functions serve push-dispatch --no-verify-jwt`, ardından ayrı terminalde `powershell -NoProfile -ExecutionPolicy Bypass -File supabase/tests/run-notification-worker.ps1 -Watch`. Tek tur için `-Watch` kaldırılır. Script yalnız yerel 55321 hedefini kabul eder ve sunucu kimliğini CLI'den yalnız belleğe alır. Edge handler yalnız sunucu bearer kabul eder. Firebase yoksa collection çalışır, `push=not_configured` döner; FCM gönderilmez. Public Firebase kimlikleri Flutter'a define olarak verilir, `FIREBASE_SERVICE_ACCOUNT_JSON` yalnız sunucu çalışma ortamında yapılandırılır. Gerçek değerleri kaynak koduna, Flutter `.env` dosyasına veya dokümana koymayın. Üretim scheduler/kimlik/gerçek cihaz push kabulü açık kalır.

Yeni DB testi `supabase/tests/database/notifications_test.sql` 88 assertion; worker mock testi `npx.cmd --yes deno@2.9.6 test supabase/functions/push-dispatch/worker_test.ts`; gerçek local SDK `powershell -NoProfile -ExecutionPolicy Bypass -File supabase/tests/run-local-auth-check.ps1 -TestFile notification_client_test.dart`. Son kaynak ve önceki geniş koşuların ayrımı, tüm sonuçlar ve kabul sınırları [TESTING](../docs/TESTING.md) başındadır. Fiyat, iskonto, stok, teslimat veya tahsilat sözleşmesi değişmez; Faz 15 yoktur.

**Faz 13 / F13-01:** On altıncı migration `20261012000200_delivery_confirmation.sql`, `delivery_workspace()` ve idempotent `delivery_action(action,data,request_key)` RPC'lerini ekler. Açık sefere/durağa atanmış Driver bildirimi → Customer onayı/uyuşmazlığı → gerektiğinde Manager/Owner gerekçeli delivered çözümü. Kesinleşme durak/history/audit ile atomiktir; stok ve fiyatlara dokunmaz. F10 açık-durak tahsilat sınırı aynıdır: durak kapandıktan sonra Driver tahsil edemez. Puan, fiili Driver için kendi Customer kullanıcısı tarafından sipariş başına bir kez verilir.

`private.delivery_receipts` tekrar sonuçlarını, `private.delivery_evidence` kanıt dosyalarının sipariş/aktör ilişkisini tutar; RLS ve ham erişim kapalıdır. `delivery-evidence` private bucket JPEG/PNG, 5 MB; yalnız uyuşmazlığa atanmış Driver yükler, yalnız yükleyen Driver ve Manager/Owner okur. Update/delete politikası yoktur. Kanıt rezervasyonu tek başına yüklenmiş dosya sayılmaz. Süreli saklama/silme kararı verilmedi. Failed/returned ve stok telafisi RPC'de açılmadı.

Yerelde `storage.enabled=true`; mevcut runtime yeni servisi almıyorsa CLI `stop → start` gerekir. Anahtar içeren CLI çıktısını paylaşmayın. `npx.cmd --yes supabase@2.119.0 db reset --local` yalnız sentetik local DB'yi yeniden kurar; önceki yerel kabul seferi ve oturumlarını da sıfırlar. DB testi: `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/delivery_confirmation_test.sql`. Gerçek API/Storage testi: `powershell -NoProfile -ExecutionPolicy Bypass -File supabase/tests/run-local-auth-check.ps1 -TestFile delivery_storage_client_test.dart`. İki bağlantılı yarış testi: `python supabase/tests/client/delivery_concurrency_test.py`. Son iki test yerel fixture bırakır; ardından local reset gerekir. Runner yalnız bellekte sentetik kimlik bilgisi oluşturur ve eski hash'leri geri yükler. Son komut/kanıt ve manuel kabul sınırları TESTING başındadır.

**Faz 12 / F12-01:** On beşinci migration `20261012000100_live_tracking.sql`: private `run_tracking` yalnız son noktayı, `tracking_viewers` koordinatsız kanal alıcılarını tutar. `tracking_workspace`, `tracking_control`, `publish_run_location` RPC'leri canlı rol/primary/aktif teslimat sınırlarını uygular. Ham konum yazma, anonim erişim ve legacy `driver_locations` geçmişine yeni yazma kapalıdır. Önceki migration ve seed'ler değişmedi.

Realtime yalnız özel `tracking:<auth uid>` kanalında yenileme sinyali gönderir; SDK'nın eklediği mesaj UUID'si dışında veri `{changed:true}`dır. Koordinatlar yetkili RPC ile alınır. Kanal bağlantısı erişim yerine geçmez; hata/bağlantı kaybında istemci tekrar yetki denetler. Realtime sinyal hatası sipariş/stok transaction'ını engellemez; son nokta silme hataları bastırılmaz. Realtime devre dışı kalırsa periyodik okuma yedeği vardır.

Yerel `config.toml` Realtime'ı açar. Önceden açık runtime yeni servisi almıyorsa `npx.cmd --yes supabase@2.119.0 stop` ardından `start` gerekir; CLI anahtar çıktısını paylaşmayın. Sonrasında `db reset --local` ve `test db --local supabase/tests/database/live_tracking_test.sql`. Gerçek yerel SDK kanal testi: `powershell -NoProfile -ExecutionPolicy Bypass -File supabase/tests/run-local-auth-check.ps1 -TestFile tracking_realtime_test.dart`; sentetik kimlik bilgileri bellekte üretilir, eski hash'ler geri yüklenir. Güncel sonuçlar TESTING başındadır.

Kaynaklar: [Supabase özel Realtime kanal yetkisi](https://supabase.com/docs/guides/realtime/authorization), [veritabanından Broadcast](https://supabase.com/docs/guides/realtime/broadcast#broadcast-from-the-database). Supabase'in sahip olduğu `realtime.messages` RLS ayarı değiştirilmez; yalnız uygulamanın SELECT politikası eklenir.

**Faz 11 / F11-01:** On dördüncü migration `20261011000300_delivery_dispatch.sql`: `dispatch_workspace()` açık alan listeli okuma; `dispatch_action(action,data,request_key)` denetlenen araç, ekipli sefer, picked atama/yeniden atama, Driver sırası/depart, Manager/Owner plan iptali/sefer kapatması. Ham yazmalar ve anonim erişim kapalı; yeni private receipt RLS açık. Mevcut 13 migration/iki seed değişmez. Yeni seferler `dispatch_managed=true`; eski serbest durumlar dönüştürülmez. Atama picked bırakır; Warehouse eski yükleme servisini kullanır. Yola çıkış bütün açık siparişler loaded ise atomiktir; GPS/teslimat onayı/stok/tahsilat üretmez.

Yeni paket: `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/delivery_dispatch_test.sql`. Gerçek iki bağlantılı yarış: temiz yerel reset sonrası `python supabase/tests/client/dispatch_concurrency_test.py`; yalnız sabit yerel Docker container'ında sentetik kayıtlar kullanır. **Sonrasında `npx.cmd --yes supabase@2.119.0 db reset --local` gerekir.** Git commit/push yapmaz. Güncel sayılar ve manuel kabul sınırları docs/TESTING başında, kurallar DECISIONS F11-01'dedir.


**Faz 10 / F10-01:** `20261011000200_accounting_payments_credit.sql` 13. migration'dır. Tahsilat (`record_payment`), atanmış müşteri için Accounting doğrulaması (`verify_payment`), Manager/Owner gerekçeli limit (`set_customer_credit_limit`), yalnız credit başvurusu kararı (`decide_credit_approval`) ve açık alan listeli `finance_workspace` eklendi. Checkout fiyat/snapshot/yeniden onayı koruyarak müşteri kilidi altında exposure denetler. Limit NULL ise önceki not_evaluated uyarısı korunur; stok kuyruğu cari kuyruğuna dönüştürülmez. Ham tablo yazmaları ve anonim erişim kapalıdır; önceki migration/seed dosyaları korunur. Yeni finance receipt aynı isteği tekrar güvenli kılar. Açık düzeltme/telafi/teslimat işlemleri uygulanmaz.

Yeni test: `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/finance_test.sql`. İki gerçek DB bağlantısıyla yarış: **temiz reset sonrası** `python supabase/tests/client/finance_concurrency_test.py`; sabit yerel Docker container'ı ve standart Python kullanır, anahtar/credential almaz. Test sentetik DB fixture'larını commit eder; **sonrasında `npx.cmd --yes supabase@2.119.0 db reset --local` gerekir**. Git commit yapmaz. Yetkiler, vade önceliği, NULL limit ve belirsiz bakiyede kapalı davranış DECISIONS F10-01'de; son sonuçlar TESTING başındadır.

**Faz 9 / F9-01:** `20261011000100_warehouse_inventory.sql` 12. migration'dır. `warehouse_workspace` fiyat/müşteri alanları içermeyen depo projection'ı; `warehouse_order_action` start/pick/load; `receive_inventory`, `submit_stock_count`, `approve_stock_count` denetlenen yazma RPC'leridir. Ham yazma kapalıdır; aynı key/payload private receipt üzerinden tekrar güvenlidir. Inventory revision değişmiş sayımın onayını engeller; eski revision'sız sayımlar yeniden girilmelidir. Yükleme mevcut açık sefer/durak gerektirir, atama oluşturmaz. Telafi/kalem revizyonu/cari hesabı uygulanmaz.

Yeni DB paketi: `npx.cmd --yes supabase@2.119.0 test db --local supabase/tests/database/warehouse_inventory_test.sql`. Gerçek ayrı bağlantı yarışı: temiz local reset sonrası `python supabase/tests/client/inventory_concurrency_test.py`; Python standart kütüphanesi ve Docker gerekir. Yalnız sabit yerel container/Unix socket kullanır, credential veya cloud hedefi almaz. Bu test görünür olması gereken sentetik kayıtları commit eder; **sonrasında `npx.cmd --yes supabase@2.119.0 db reset --local` çalıştırın**. Git commit işlemi yapmaz. Son komutlar/sınırlar TESTING başındadır.

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
