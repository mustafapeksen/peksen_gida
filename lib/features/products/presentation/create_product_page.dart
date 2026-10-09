import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_providers.dart';
import 'product_providers.dart';
import 'price_page.dart' show newOperationKey;

class _UnitInput {
  final name = TextEditingController(),
      conversion = TextEditingController(text: '1');
  void dispose() {
    name.dispose();
    conversion.dispose();
  }
}

class CreateProductPage extends ConsumerStatefulWidget {
  const CreateProductPage({super.key});
  @override
  ConsumerState<CreateProductPage> createState() => _CreateProductPageState();
}

class _CreateProductPageState extends ConsumerState<CreateProductPage> {
  final _form = GlobalKey<FormState>();
  final _sku = TextEditingController(),
      _name = TextEditingController(),
      _base = TextEditingController();
  final _minimum = TextEditingController(text: '1'),
      _package = TextEditingController();
  final _units = [_UnitInput()];
  final _id = newOperationKey();
  String? _category, _error;
  bool _busy = false;
  @override
  void dispose() {
    for (final c in [_sku, _name, _base, _minimum, _package]) {
      c.dispose();
    }
    for (final u in _units) {
      u.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await (await ref.read(productRepositoryProvider.future)).createDraft(
        id: _id,
        sku: _sku.text.trim(),
        name: _name.text.trim(),
        categoryId: _category!,
        baseUnit: _base.text.trim(),
        minimum: int.parse(_minimum.text),
        packageLabel: _package.text.trim(),
        units: _units
            .map(
              (u) => {
                'name': u.name.text.trim(),
                'conversion': u.conversion.text.trim().replaceAll(',', '.'),
              },
            )
            .toList(),
      );
      ref.invalidate(productsProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Ürün oluşturulamadı. SKU, birimler ve yetkinizi kontrol edin. Bağlantı kesildiyse tekrar göndermeden ürün listesini yenileyin.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ürün oluştur')),
      body: SafeArea(
        child: account.when(
          skipLoadingOnRefresh: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Hesap erişimi doğrulanamadı.')),
          data: (profile) {
            if (profile == null || !canReadProducts(profile.role)) {
              return const Center(child: Text('Ürün oluşturma yetkiniz yok.'));
            }
            return ref
                .watch(productCategoriesProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () =>
                          ref.invalidate(productCategoriesProvider),
                      child: const Text('Kategorileri yeniden yükle'),
                    ),
                  ),
                  data: (categories) => Form(
                    key: _form,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text(
                          'Ürün fiyatı belirlenmeden ve yönetici satışa açmadan sipariş edilemez.',
                        ),
                        if (categories.isEmpty)
                          const Text(
                            'Aktif kategori yok. Kategori yönetimi için karar bekleniyor.',
                          ),
                        for (final field in [
                          (controller: _sku, label: 'SKU'),
                          (controller: _name, label: 'Ürün adı'),
                          (controller: _base, label: 'Taban birim'),
                        ])
                          TextFormField(
                            controller: field.controller,
                            enabled: !_busy,
                            decoration: InputDecoration(labelText: field.label),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Bu alan zorunlu.'
                                : null,
                          ),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                          ),
                          items: categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c['id'] as String,
                                  child: Text(c['name'] as String),
                                ),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _category = v),
                          validator: (v) =>
                              v == null ? 'Kategori seçin.' : null,
                        ),
                        TextFormField(
                          controller: _minimum,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minimum taban miktar',
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return n == null || n <= 0 || n > 2147483647
                                ? 'Pozitif tam sayı girin.'
                                : null;
                          },
                        ),
                        TextFormField(
                          controller: _package,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Ambalaj / gramaj açıklaması',
                          ),
                        ),
                        for (final u in _units) ...[
                          TextFormField(
                            controller: u.name,
                            enabled: !_busy,
                            decoration: const InputDecoration(
                              labelText: 'Satış birimi',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Birim adı girin.'
                                : null,
                          ),
                          TextFormField(
                            controller: u.conversion,
                            enabled: !_busy,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '1 satış biriminin taban miktarı',
                            ),
                            validator: (v) {
                              final text = (v ?? '').trim().replaceAll(
                                ',',
                                '.',
                              );
                              return !RegExp(r'^\d+(\.\d+)?$').hasMatch(text) ||
                                      !RegExp('[1-9]').hasMatch(text)
                                  ? 'Pozitif ondalık değer girin.'
                                  : null;
                            },
                          ),
                        ],
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _units.add(_UnitInput())),
                          child: const Text('Satış birimi ekle'),
                        ),
                        if (_error != null) Text(_error!),
                        FilledButton(
                          onPressed: _busy || categories.isEmpty ? null : _save,
                          child: Text(
                            _busy ? 'Oluşturuluyor…' : 'Fiyatsız ürün oluştur',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
          },
        ),
      ),
    );
  }
}
