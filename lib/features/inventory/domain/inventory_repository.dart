import '../../../core/errors/failure.dart';
import 'inventory_balance.dart';

abstract interface class InventoryRepository {
  /// يراقب أرصدة المنتجات المحسوبة من بنود البيع والشراء.
  Stream<List<InventoryBalance>> watchBalances({
    String? categoryId,
    bool lowStockOnly = false,
  });

  /// يجلب الرصيد المشتق لمنتج، أو null إذا لم يوجد.
  Future<Result<InventoryBalance?>> getBalance(String productId);

  /// يبحث عن منتجات مع أرصدتها المشتقة بالاسم أو الباركود.
  Future<Result<List<InventoryBalance>>> search(String query);
}
