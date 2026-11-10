import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import '../../products/domain/product.dart';
import '../domain/inventory_balance.dart';
import '../domain/inventory_repository.dart';

/// يحسب الأرصدة عند القراءة من حركات الشراء والبيع، ولا يكتبها في قاعدة البيانات.
class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._db);

  final AppDatabase _db;

  static const _selectBalances = '''
    SELECT
      p.id AS product_id,
      p.name AS product_name,
      p.category_id AS category_id,
      p.barcode AS barcode,
      p.unit AS unit,
      p.sale_price AS sale_price,
      p.cost_price AS cost_price,
      p.min_stock AS min_stock,
      p.is_active AS is_active,
      COALESCE(
        SUM(
          CASE
            WHEN t.type = 'purchase' THEN i.quantity
            WHEN t.type = 'sale' THEN -i.quantity
            ELSE 0
          END
        ),
        0
      ) AS quantity_milli
    FROM products p
    LEFT JOIN transaction_items i
      ON i.product_id = p.id AND i.deleted_at IS NULL
    LEFT JOIN transactions t
      ON t.id = i.transaction_id
      AND t.deleted_at IS NULL
      AND t.type IN ('purchase', 'sale')
    WHERE p.deleted_at IS NULL
  ''';

  @override
  Stream<List<InventoryBalance>> watchBalances({
    String? categoryId,
    bool lowStockOnly = false,
  }) {
    final query = _buildQuery(categoryId: categoryId);

    return query.watch().map((rows) {
      final balances = rows.map(_fromRow);

      if (!lowStockOnly) {
        return balances.toList(growable: false);
      }

      return balances
          .where((balance) => balance.isBelowMinimum)
          .toList(growable: false);
    });
  }

  @override
  Future<Result<InventoryBalance?>> getBalance(String productId) {
    return guardAsync(() async {
      final query = _buildQuery(productId: productId);
      final row = await query.getSingleOrNull();
      return row == null ? null : _fromRow(row);
    });
  }

  @override
  Future<Result<List<InventoryBalance>>> search(String query) {
    return guardAsync(() async {
      final term = query.trim().toLowerCase();
      final rows = await _buildQuery().get();

      return rows.map(_fromRow).where((balance) {
        if (term.isEmpty) return true;

        return balance.product.name.toLowerCase().contains(term) ||
            (balance.product.barcode?.toLowerCase().contains(term) ?? false);
      }).toList(growable: false);
    });
  }

  Selectable<QueryRow> _buildQuery({
    String? categoryId,
    String? productId,
  }) {
    final clauses = <String>[];
    final variables = <Variable<Object>>[];

    if (categoryId != null) {
      clauses.add(' AND p.category_id = ?');
      variables.add(Variable<String>(categoryId));
    }

    if (productId != null) {
      clauses.add(' AND p.id = ?');
      variables.add(Variable<String>(productId));
    }

    return _db.customSelect(
      '$_selectBalances${clauses.join()} GROUP BY p.id ORDER BY p.name',
      variables: variables,
      readsFrom: {
        _db.products,
        _db.transactionItems,
        _db.transactions,
      },
    );
  }

  InventoryBalance _fromRow(QueryRow row) {
    final product = Product(
      id: row.read<String>('product_id'),
      name: row.read<String>('product_name'),
      categoryId: row.read<String?>('category_id'),
      barcode: row.read<String?>('barcode'),
      unit: row.read<String>('unit'),
      salePrice: Money(row.read<int>('sale_price')),
      costPrice: Money(row.read<int>('cost_price')),
      minStock: row.read<int>('min_stock'),
      isActive: row.read<bool>('is_active'),
    );

    return InventoryBalance(
      product: product,
      quantityMilli: row.read<int>('quantity_milli'),
    );
  }
}
