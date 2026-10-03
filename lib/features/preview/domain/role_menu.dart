/// Source roles from SPEC §2, used only to browse development previews.
///
/// Selecting an entry here does not grant permissions or establish a session.
enum AppRole {
  customer(
    id: 'customer',
    label: 'Müşteri',
    description: 'Ürünler, siparişler ve teslimat takibi.',
  ),
  salesOperator(
    id: 'sales_operator',
    label: 'Saha satış',
    description: 'Müşteri ziyaretleri, siparişler ve tahsilatlar.',
  ),
  warehouse(
    id: 'warehouse',
    label: 'Depo',
    description: 'Sipariş hazırlığı, ürünler ve stok işlemleri.',
  ),
  accounting(
    id: 'accounting',
    label: 'Muhasebe',
    description: 'Tahsilatlar, müşteri hesapları ve fiyatlar.',
  ),
  driver(
    id: 'driver',
    label: 'Sürücü',
    description: 'Günlük sefer, duraklar ve teslimatlar.',
  ),
  manager(
    id: 'manager',
    label: 'Yönetici',
    description: 'Operasyon, ekip ve dağıtım yönetimi.',
  ),
  owner(
    id: 'owner',
    label: 'İşletme sahibi',
    description: 'Operasyon, finans ve işletme ayarları.',
  );

  const AppRole({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  static AppRole? fromId(String id) {
    for (final role in values) {
      if (role.id == id) return role;
    }
    return null;
  }
}

/// One screen from the SPEC §23 inventory, not an implemented business module.
final class RoleMenuEntry {
  const RoleMenuEntry({
    required this.id,
    required this.label,
    required this.sourceLabel,
  });

  final String id;
  final String label;

  /// Exact source label for traceability; not displayed in the interface.
  final String sourceLabel;
}

const _managerMenu = <RoleMenuEntry>[
  RoleMenuEntry(
    id: 'dashboard',
    label: 'Genel bakış',
    sourceLabel: 'Dashboard',
  ),
  RoleMenuEntry(id: 'orders', label: 'Siparişler', sourceLabel: 'Orders'),
  RoleMenuEntry(id: 'inventory', label: 'Stok', sourceLabel: 'Inventory'),
  RoleMenuEntry(
    id: 'deliveries',
    label: 'Teslimatlar',
    sourceLabel: 'Deliveries',
  ),
  RoleMenuEntry(
    id: 'live_vehicles',
    label: 'Canlı araç takibi',
    sourceLabel: 'Live Vehicles',
  ),
  RoleMenuEntry(id: 'customers', label: 'Müşteriler', sourceLabel: 'Customers'),
  RoleMenuEntry(id: 'employees', label: 'Çalışanlar', sourceLabel: 'Employees'),
  RoleMenuEntry(
    id: 'ratings',
    label: 'Değerlendirmeler',
    sourceLabel: 'Ratings',
  ),
  RoleMenuEntry(id: 'discounts', label: 'İndirimler', sourceLabel: 'Discounts'),
  RoleMenuEntry(id: 'reports', label: 'Raporlar', sourceLabel: 'Reports'),
];

/// Complete SPEC §23 inventory: 13 + 9 + 10 + 7 + 7 + 10 + 14 = 70 entries.
const roleMenus = <AppRole, List<RoleMenuEntry>>{
  AppRole.customer: [
    RoleMenuEntry(id: 'login', label: 'Giriş', sourceLabel: 'Login'),
    RoleMenuEntry(id: 'home', label: 'Ana sayfa', sourceLabel: 'Home'),
    RoleMenuEntry(
      id: 'categories',
      label: 'Kategoriler',
      sourceLabel: 'Categories',
    ),
    RoleMenuEntry(id: 'products', label: 'Ürünler', sourceLabel: 'Products'),
    RoleMenuEntry(
      id: 'product_detail',
      label: 'Ürün detayı',
      sourceLabel: 'Product Detail',
    ),
    RoleMenuEntry(id: 'cart', label: 'Sepet', sourceLabel: 'Cart'),
    RoleMenuEntry(
      id: 'checkout',
      label: 'Siparişi tamamla',
      sourceLabel: 'Checkout',
    ),
    RoleMenuEntry(id: 'orders', label: 'Siparişlerim', sourceLabel: 'Orders'),
    RoleMenuEntry(
      id: 'order_detail',
      label: 'Sipariş detayı',
      sourceLabel: 'Order Detail',
    ),
    RoleMenuEntry(
      id: 'live_delivery',
      label: 'Canlı teslimat takibi',
      sourceLabel: 'Live Delivery',
    ),
    RoleMenuEntry(
      id: 'delivery_confirmation',
      label: 'Teslimat onayı',
      sourceLabel: 'Delivery Confirmation',
    ),
    RoleMenuEntry(
      id: 'rating',
      label: 'Sürücüyü puanla',
      sourceLabel: 'Rating',
    ),
    RoleMenuEntry(id: 'profile', label: 'Profilim', sourceLabel: 'Profile'),
  ],
  AppRole.salesOperator: [
    RoleMenuEntry(
      id: 'dashboard',
      label: 'Genel bakış',
      sourceLabel: 'Dashboard',
    ),
    RoleMenuEntry(
      id: 'customers',
      label: 'Müşteriler',
      sourceLabel: 'Customers',
    ),
    RoleMenuEntry(
      id: 'customer_detail',
      label: 'Müşteri detayı',
      sourceLabel: 'Customer Detail',
    ),
    RoleMenuEntry(id: 'catalog', label: 'Katalog', sourceLabel: 'Catalog'),
    RoleMenuEntry(
      id: 'create_order',
      label: 'Sipariş oluştur',
      sourceLabel: 'Create Order',
    ),
    RoleMenuEntry(
      id: 'order_detail',
      label: 'Sipariş detayı',
      sourceLabel: 'Order Detail',
    ),
    RoleMenuEntry(
      id: 'alternative_offer',
      label: 'Alternatif ürün teklifi',
      sourceLabel: 'Alternative Offer',
    ),
    RoleMenuEntry(
      id: 'payments',
      label: 'Tahsilatlar',
      sourceLabel: 'Payments',
    ),
    RoleMenuEntry(
      id: 'customer_history',
      label: 'Müşteri geçmişi',
      sourceLabel: 'Customer History',
    ),
  ],
  AppRole.warehouse: [
    RoleMenuEntry(
      id: 'dashboard',
      label: 'Genel bakış',
      sourceLabel: 'Dashboard',
    ),
    RoleMenuEntry(
      id: 'order_queue',
      label: 'Sipariş kuyruğu',
      sourceLabel: 'Order Queue',
    ),
    RoleMenuEntry(
      id: 'picking',
      label: 'Sipariş hazırlama',
      sourceLabel: 'Picking',
    ),
    RoleMenuEntry(
      id: 'missing_item',
      label: 'Eksik ürün bildirimi',
      sourceLabel: 'Missing Item',
    ),
    RoleMenuEntry(id: 'products', label: 'Ürünler', sourceLabel: 'Products'),
    RoleMenuEntry(
      id: 'price_management',
      label: 'Fiyat yönetimi',
      sourceLabel: 'Price Management',
    ),
    RoleMenuEntry(
      id: 'receiving',
      label: 'Mal kabul',
      sourceLabel: 'Receiving',
    ),
    RoleMenuEntry(id: 'inventory', label: 'Stok', sourceLabel: 'Inventory'),
    RoleMenuEntry(
      id: 'stock_count',
      label: 'Stok sayımı',
      sourceLabel: 'Stock Count',
    ),
    RoleMenuEntry(
      id: 'movements',
      label: 'Stok hareketleri',
      sourceLabel: 'Movements',
    ),
  ],
  AppRole.accounting: [
    RoleMenuEntry(
      id: 'dashboard',
      label: 'Genel bakış',
      sourceLabel: 'Dashboard',
    ),
    RoleMenuEntry(
      id: 'payments',
      label: 'Tahsilatlar',
      sourceLabel: 'Payments',
    ),
    RoleMenuEntry(
      id: 'payment_verification',
      label: 'Tahsilat doğrulama',
      sourceLabel: 'Payment Verification',
    ),
    RoleMenuEntry(
      id: 'customer_accounts',
      label: 'Müşteri hesapları',
      sourceLabel: 'Customer Accounts',
    ),
    RoleMenuEntry(
      id: 'credit_limit',
      label: 'Cari limit',
      sourceLabel: 'Credit Limit',
    ),
    RoleMenuEntry(
      id: 'price_management',
      label: 'Fiyat yönetimi',
      sourceLabel: 'Price Management',
    ),
    RoleMenuEntry(id: 'reports', label: 'Raporlar', sourceLabel: 'Reports'),
  ],
  AppRole.driver: [
    RoleMenuEntry(
      id: 'todays_run',
      label: 'Bugünkü sefer',
      sourceLabel: "Today's Run",
    ),
    RoleMenuEntry(id: 'stops', label: 'Duraklar', sourceLabel: 'Stops'),
    RoleMenuEntry(
      id: 'stop_detail',
      label: 'Durak detayı',
      sourceLabel: 'Stop Detail',
    ),
    RoleMenuEntry(
      id: 'navigation_handoff',
      label: 'Yol tarifine geç',
      sourceLabel: 'Navigation Handoff',
    ),
    RoleMenuEntry(
      id: 'gps_status',
      label: 'Konum durumu',
      sourceLabel: 'GPS Status',
    ),
    RoleMenuEntry(
      id: 'delivery_confirmation',
      label: 'Teslimat onayı',
      sourceLabel: 'Delivery Confirmation',
    ),
    RoleMenuEntry(
      id: 'exception',
      label: 'Sorun bildirimi',
      sourceLabel: 'Exception',
    ),
  ],
  AppRole.manager: _managerMenu,
  AppRole.owner: [
    ..._managerMenu,
    RoleMenuEntry(id: 'finance', label: 'Finans', sourceLabel: 'Finance'),
    RoleMenuEntry(
      id: 'salary_bonus',
      label: 'Maaş ve prim',
      sourceLabel: 'Salary/Bonus',
    ),
    RoleMenuEntry(id: 'settings', label: 'Ayarlar', sourceLabel: 'Settings'),
    RoleMenuEntry(
      id: 'audit',
      label: 'İşlem kayıtları',
      sourceLabel: 'Audit Log',
    ),
  ],
};
