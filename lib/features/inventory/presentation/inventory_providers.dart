import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/errors/failure.dart';
import '../data/inventory_repository_impl.dart';
import '../domain/inventory_balance.dart';
import '../domain/inventory_repository.dart';

/// مستودع المخزون المحلي.
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// يراقب أرصدة جميع المنتجات.
final inventoryBalancesProvider =
    StreamProvider<List<InventoryBalance>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchBalances();
});

/// يراقب المنتجات التي وصلت إلى حد المخزون الأدنى أو نزلت عنه.
final inventoryLowStockBalancesProvider =
    StreamProvider<List<InventoryBalance>>((ref) {
  return ref
      .watch(inventoryRepositoryProvider)
      .watchBalances(lowStockOnly: true);
});

/// يراقب أرصدة منتجات تصنيف محدد.
final inventoryBalancesByCategoryProvider =
    StreamProvider.family<List<InventoryBalance>, String>((ref, categoryId) {
  return ref
      .watch(inventoryRepositoryProvider)
      .watchBalances(categoryId: categoryId);
});

/// يجلب الرصيد الحالي لمنتج واحد.
final inventoryBalanceProvider =
    FutureProvider.family<Result<InventoryBalance?>, String>(
  (ref, productId) {
    return ref.watch(inventoryRepositoryProvider).getBalance(productId);
  },
);

/// يبحث باسم المنتج أو الباركود.
final inventorySearchProvider =
    FutureProvider.family<Result<List<InventoryBalance>>, String>(
  (ref, query) {
    return ref.watch(inventoryRepositoryProvider).search(query);
  },
);
