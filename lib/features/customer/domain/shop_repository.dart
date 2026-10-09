class CatalogUnit {
  const CatalogUnit(this.id, this.name, this.conversion);
  final String id, name, conversion;
}

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.category,
    required this.baseUnit,
    required this.minimum,
    required this.listPrice,
    required this.finalPrice,
    required this.discount,
    required this.stockState,
    required this.units,
    this.description,
    this.packageLabel,
  });
  final String id,
      name,
      categoryId,
      category,
      baseUnit,
      minimum,
      listPrice,
      finalPrice,
      discount,
      stockState;
  final String? description, packageLabel;
  final List<CatalogUnit> units;
  factory CatalogProduct.fromJson(Map<String, dynamic> p) => CatalogProduct(
    id: p['id'] as String,
    name: p['name'] as String,
    categoryId: p['category_id'] as String,
    category: p['category'] as String,
    baseUnit: p['base_unit'] as String,
    minimum: p['minimum'] as String,
    listPrice: p['list_price_kurus'] as String,
    finalPrice: p['exact_final_base_price'] as String,
    discount: p['discount_rate'] as String,
    stockState: p['stock_state'] as String,
    description: p['description'] as String?,
    packageLabel: p['package_label'] as String?,
    units: (p['units'] as List)
        .map(
          (v) => CatalogUnit(
            v['id'] as String,
            v['name'] as String,
            v['conversion'] as String,
          ),
        )
        .toList(),
  );
}

class CartLine {
  const CartLine({
    required this.productName,
    required this.unitId,
    required this.unitName,
    required this.quantity,
  });
  final String productName, unitId, unitName;
  final int quantity;
  Map<String, dynamic> toJson() => {'unit_id': unitId, 'quantity': quantity};
  CartLine withQuantity(int value) => CartLine(
    productName: productName,
    unitId: unitId,
    unitName: unitName,
    quantity: value,
  );
}

String formatExactKurus(String value) {
  final parts = value.split('.');
  final n = BigInt.parse(parts[0]);
  var fraction =
      (n % BigInt.from(100)).toString().padLeft(2, '0') +
      (parts.length > 1 ? parts[1] : '');
  while (fraction.length > 2 && fraction.endsWith('0')) {
    fraction = fraction.substring(0, fraction.length - 1);
  }
  return '${n ~/ BigInt.from(100)},$fraction TL';
}

class CheckoutRejected implements Exception {
  const CheckoutRejected();
}

abstract interface class ShopRepository {
  Future<Map<String, dynamic>?> pendingCheckout(String customerId);
  Future<List<Map<String, dynamic>>> orders(String customerId);
  Future<void> saveDraft(String customerId, List<CartLine> lines);
  Future<List<Map<String, dynamic>>?> loadDraft(String customerId);
  Future<Map<String, dynamic>> checkout(
    String customerId,
    List<CartLine> lines,
    Map<String, dynamic> quote,
    String key,
  );
  Future<String> customerId(String userId);
  Future<List<CatalogProduct>> catalog(String customerId);
  Future<Map<String, dynamic>> quote(String customerId, List<CartLine> lines);
}
