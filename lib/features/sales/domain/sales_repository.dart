class SalesCustomer {
  const SalesCustomer(this.id, this.companyName);
  final String id, companyName;
}

abstract interface class SalesRepository {
  Future<List<SalesCustomer>> assignedCustomers();
}
