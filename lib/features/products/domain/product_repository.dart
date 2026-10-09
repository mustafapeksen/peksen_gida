/// Decimal database quantities travel as text; no floating point pricing here.
class ProductUnit {
  const ProductUnit(this.id, this.name, this.conversion, this.orderable);
  final String id, name, conversion;
  final bool orderable;
  factory ProductUnit.fromJson(Map<String, dynamic> row) => ProductUnit(
    row['id'] as String,
    row['name'] as String,
    row['conversion'] as String,
    row['orderable'] as bool,
  );
}

class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.baseUnit,
    required this.active,
    required this.units,
    this.packageLabel,
    this.priceKurus,
    this.minimum,
    this.category,
  });
  final String id, sku, name, baseUnit;
  final String? packageLabel, priceKurus, minimum, category;
  final bool active;
  final List<ProductUnit> units;
  factory Product.fromJson(Map<String, dynamic> row) => Product(
    id: row['id'] as String,
    sku: row['sku'] as String,
    name: row['name'] as String,
    baseUnit: row['base_unit'] as String,
    active: row['active'] as bool,
    packageLabel: row['package_label'] as String?,
    priceKurus: row['price_kurus'] as String?,
    minimum: row['minimum'] as String?,
    category: row['category'] as String?,
    units: (row['units'] as List)
        .map((u) => ProductUnit.fromJson(Map<String, dynamic>.from(u as Map)))
        .toList(),
  );
}

String formatKurus(String value) {
  final amount = BigInt.parse(value);
  return '${amount ~/ BigInt.from(100)},${(amount % BigInt.from(100)).toString().padLeft(2, '0')} TL';
}

/// Parse the Turkish money form without a binary floating-point intermediate.
String? parseMoney(String value) {
  final match = RegExp(r'^(\d+)(?:[,.](\d{1,2}))?$').firstMatch(value.trim());
  if (match == null) return null;
  final amount =
      BigInt.parse(match[1]!) * BigInt.from(100) +
      BigInt.parse((match[2] ?? '').padRight(2, '0'));
  if (amount > BigInt.parse('9223372036854775807')) return null;
  return amount.toString();
}

String formatDiscountPercent(String fraction) {
  final parts = fraction.split('.');
  final decimals = (parts.length == 1 ? '' : parts[1]).padRight(2, '0');
  final whole = BigInt.parse('${parts[0]}${decimals.substring(0, 2)}');
  final tail = decimals.substring(2).replaceFirst(RegExp(r'0+$'), '');
  return '$whole${tail.isEmpty ? '' : ',$tail'}';
}

abstract interface class ProductRepository {
  Future<List<Map<String, dynamic>>> pricingCustomers();
  Future<Map<String, dynamic>> quote(
    String customerId,
    String unitId,
    int quantity,
  );
  Future<List<Map<String, dynamic>>> categories();
  Future<void> createDraft({
    required String id,
    required String sku,
    required String name,
    required String categoryId,
    required String baseUnit,
    required int minimum,
    required String packageLabel,
    required List<Map<String, String>> units,
  });
  Future<void> activate(String productId, String expectedPrice);
  Future<List<Product>> list();
  Future<List<Map<String, dynamic>>> priceHistory(String productId);
  Future<void> changePrice({
    required String productId,
    required String? expectedPrice,
    required String newPrice,
    required String reason,
    required String operationKey,
  });
}
