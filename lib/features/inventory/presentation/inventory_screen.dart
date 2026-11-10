import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../domain/inventory_balance.dart';
import 'inventory_providers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();

  String _query = '';
  bool _lowStockOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balancesAsync = ref.watch(
      _lowStockOnly
          ? inventoryLowStockBalancesProvider
          : inventoryBalancesProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزون'),
        actions: [
          IconButton(
            tooltip: 'تحديث المخزون',
            onPressed: () {
              ref.invalidate(inventoryBalancesProvider);
              ref.invalidate(inventoryLowStockBalancesProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _query = value.trim());
              },
              decoration: InputDecoration(
                hintText: 'ابحث باسم المنتج أو الباركود',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilterChip(
                selected: _lowStockOnly,
                avatar: const Icon(Icons.warning_amber_outlined),
                label: const Text('المخزون المنخفض فقط'),
                onSelected: (selected) {
                  setState(() => _lowStockOnly = selected);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: balancesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('تعذّر تحميل المخزون.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          ref.invalidate(inventoryBalancesProvider);
                          ref.invalidate(inventoryLowStockBalancesProvider);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (balances) {
                final normalizedQuery = _query.toLowerCase();

                final filteredBalances = balances.where((balance) {
                  if (normalizedQuery.isEmpty) return true;

                  return balance.product.name
                          .toLowerCase()
                          .contains(normalizedQuery) ||
                      (balance.product.barcode
                              ?.toLowerCase()
                              .contains(normalizedQuery) ??
                          false);
                }).toList(growable: false);

                if (filteredBalances.isEmpty) {
                  return Center(
                    child: Text(
                      balances.isEmpty
                          ? _lowStockOnly
                              ? 'لا توجد منتجات منخفضة المخزون.'
                              : 'لا توجد منتجات لعرضها.'
                          : 'لا توجد نتائج مطابقة للبحث.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filteredBalances.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    return _InventoryBalanceTile(
                      balance: filteredBalances[index],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryBalanceTile extends StatelessWidget {
  const _InventoryBalanceTile({
    required this.balance,
  });

  final InventoryBalance balance;

  @override
  Widget build(BuildContext context) {
    final product = balance.product;
    final isLowStock = balance.isBelowMinimum;
    final quantityText = Money(balance.quantityMilli).toDecimalString(
      decimals: 3,
    );
    final minimumText = Money(product.minStock).toDecimalString(
      decimals: 3,
    );

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            isLowStock
                ? Icons.warning_amber_outlined
                : Icons.inventory_2_outlined,
          ),
        ),
        title: Text(product.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'المتوفر: $quantityText ${product.unit}'
            '${product.minStock > 0 ? '\nحد التنبيه: $minimumText ${product.unit}' : ''}'
            '${product.barcode == null ? '' : '\nالباركود: ${product.barcode}'}',
          ),
        ),
        trailing: isLowStock
            ? const Chip(
                label: Text('منخفض'),
                avatar: Icon(Icons.warning_amber_outlined, size: 18),
              )
            : null,
      ),
    );
  }
}
