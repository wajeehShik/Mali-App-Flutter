import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/outbox_table.dart';
import '../../../core/database/tables/transactions_table.dart'
    as db_transactions;
import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import '../domain/sale.dart';
import '../domain/sale_repository.dart';

/// تنفيذ مستودع المبيعات عبر Drift.
/// فحص المخزون، حفظ العملية وبنودها، وكتابة outbox تتم ذريًا.
class SaleRepositoryImpl implements SaleRepository {
  SaleRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Sale>> watchSales({
    DateTime? from,
    DateTime? to,
    String? customerId,
  }) {
    final start = from ?? DateTime.utc(1900);
    final end = to ?? DateTime.utc(9999, 12, 31, 23, 59, 59);

    return _db.transactionsDao.watchByDateRange(start, end).asyncMap(
      (rows) async {
        final sales = rows.where((row) {
          return row.type == db_transactions.TransactionType.sale &&
              (customerId == null || row.contactId == customerId);
        });

        return Future.wait(sales.map(_fromRow));
      },
    );
  }

  @override
  Future<Result<List<Sale>>> getAll() {
    return guardAsync(() async {
      final rows = await _db.transactionsDao.getAll();
      final sales = rows.where(
        (row) => row.type == db_transactions.TransactionType.sale,
      );
      return Future.wait(sales.map(_fromRow));
    });
  }

  @override
  Future<Result<List<Sale>>> search(String query) {
    return guardAsync(() async {
      final term = query.trim().toLowerCase();
      final rows = await _db.transactionsDao.getAll();

      final matches = rows.where((row) {
        if (row.type != db_transactions.TransactionType.sale) return false;
        if (term.isEmpty) return true;

        return row.id.toLowerCase().contains(term) ||
            (row.note?.toLowerCase().contains(term) ?? false);
      });

      return Future.wait(matches.map(_fromRow));
    });
  }

  @override
  Future<Result<Sale?>> getById(String id) {
    return guardAsync(() async {
      final row = await _db.transactionsDao.getById(id);
      if (row == null || row.type != db_transactions.TransactionType.sale) {
        return null;
      }
      return _fromRow(row);
    });
  }

  @override
  Future<Result<void>> create(Sale sale) {
    final failure = _validate(sale);
    if (failure != null) return Future.value(Err<void>(failure));

    return guardAsync(() async {
      await _db.transaction(() async {
        await _ensureStockAvailable(sale);

        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: Value(sale.id),
                type: db_transactions.TransactionType.sale,
                date: sale.date.toUtc(),
                accountId: sale.accountId,
                contactId: Value(sale.customerId),
                total: sale.total.minor,
                paidAmount: sale.paidAmount.minor,
                note: Value(_cleanOptional(sale.note)),
              ),
            );

        await _insertItems(sale);

        final row = await _readRow(sale.id);
        final itemRows = await _readActiveItemRows(sale.id);

        await _enqueue(
          row: row,
          items: itemRows,
          operation: OutboxOperation.create,
        );
      });
    });
  }

  @override
  Future<Result<void>> update(Sale sale) {
    final failure = _validate(sale);
    if (failure != null) return Future.value(Err<void>(failure));

    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(sale.id);
        if (existing == null ||
            existing.type != db_transactions.TransactionType.sale) {
          throw const FailureException(
            NotFoundFailure('عملية البيع غير موجودة.'),
          );
        }

        // يستثني حركة البيع الحالية من حساب الرصيد، حتى لا تخصم مرتين.
        await _ensureStockAvailable(
          sale,
          excludingTransactionId: sale.id,
        );

        final now = DateTime.now().toUtc();

        await (_db.update(_db.transactions)
              ..where((row) => row.id.equals(sale.id)))
            .write(
          TransactionsCompanion(
            date: Value(sale.date.toUtc()),
            accountId: Value(sale.accountId),
            contactId: Value(sale.customerId),
            total: Value(sale.total.minor),
            paidAmount: Value(sale.paidAmount.minor),
            note: Value(_cleanOptional(sale.note)),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        await (_db.update(_db.transactionItems)
              ..where(
                (item) =>
                    item.transactionId.equals(sale.id) &
                    item.deletedAt.isNull(),
              ))
            .write(
          TransactionItemsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        await _insertItems(sale);

        final row = await _readRow(sale.id);
        final itemRows = await _readActiveItemRows(sale.id);

        await _enqueue(
          row: row,
          items: itemRows,
          operation: OutboxOperation.update,
        );
      });
    });
  }

  @override
  Future<Result<void>> softDelete(String id) {
    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(id);
        if (existing == null ||
            existing.type != db_transactions.TransactionType.sale) {
          throw const FailureException(
            NotFoundFailure('عملية البيع غير موجودة.'),
          );
        }

        final now = DateTime.now().toUtc();

        await (_db.update(_db.transactions)
              ..where((row) => row.id.equals(id)))
            .write(
          TransactionsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        await (_db.update(_db.transactionItems)
              ..where(
                (item) =>
                    item.transactionId.equals(id) & item.deletedAt.isNull(),
              ))
            .write(
          TransactionItemsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final row = await _readRow(id);
        final itemRows = await _readAllItemRows(id);

        await _enqueue(
          row: row,
          items: itemRows,
          operation: OutboxOperation.delete,
        );
      });
    });
  }

  Failure? _validate(Sale sale) {
    final errors = <String, String>{};

    if (sale.id.trim().isEmpty) {
      errors['id'] = 'معرّف عملية البيع مطلوب.';
    }
    if (sale.accountId.trim().isEmpty) {
      errors['accountId'] = 'الحساب مطلوب.';
    }
    if (sale.customerId != null && sale.customerId!.trim().isEmpty) {
      errors['customerId'] = 'العميل المحدد غير صالح.';
    }
    if (sale.items.isEmpty) {
      errors['items'] = 'أضف بندًا واحدًا على الأقل.';
    }

    for (final item in sale.items) {
      if (item.productId.trim().isEmpty) {
        errors['productId'] = 'المنتج مطلوب لكل بند.';
      }
      if (item.quantityMilli <= 0) {
        errors['quantity'] = 'كمية كل بند يجب أن تكون أكبر من صفر.';
      }
      if (item.unitPrice.minor < 0 || item.unitCost.minor < 0) {
        errors['price'] = 'السعر والتكلفة لا يمكن أن يكونا سالبين.';
      }
    }

    if (sale.total.minor <= 0) {
      errors['total'] = 'إجمالي البيع يجب أن يكون أكبر من صفر.';
    }

    if (sale.paidAmount.minor < 0) {
      errors['paidAmount'] = 'المبلغ المدفوع لا يمكن أن يكون سالبًا.';
    } else if (sale.paidAmount.minor > sale.total.minor) {
      errors['paidAmount'] = 'المبلغ المدفوع لا يمكن أن يتجاوز إجمالي البيع.';
    }

    final calculatedTotal = sale.items.fold<int>(
      0,
      (sum, item) => sum + item.lineTotal.minor,
    );

    if (sale.items.isNotEmpty && calculatedTotal != sale.total.minor) {
      errors['total'] = 'إجمالي العملية لا يساوي مجموع إجماليات البنود.';
    }

    if ((sale.note?.trim().length ?? 0) > 500) {
      errors['note'] = 'الملاحظة طويلة جدًا.';
    }

    if (errors.isEmpty) return null;

    return ValidationFailure(
      'تحقق من بيانات عملية البيع.',
      fieldErrors: errors,
    );
  }

  /// يتحقق من كميات المنتجات قبل البيع، مع تجميع البنود المكررة للمنتج نفسه.
  Future<void> _ensureStockAvailable(
    Sale sale, {
    String? excludingTransactionId,
  }) async {
    final requestedByProduct = <String, int>{};

    for (final item in sale.items) {
      requestedByProduct.update(
        item.productId,
        (quantity) => quantity + item.quantityMilli,
        ifAbsent: () => item.quantityMilli,
      );
    }

    for (final entry in requestedByProduct.entries) {
      final productQuery = _db.select(_db.products)
        ..where(
          (product) =>
              product.id.equals(entry.key) &
              product.deletedAt.isNull() &
              product.isActive.equals(true),
        );

      final product = await productQuery.getSingleOrNull();
      if (product == null) {
        throw const FailureException(
          ValidationFailure(
            'لا يمكن بيع منتج غير موجود أو غير نشط.',
          ),
        );
      }

      final available = await _getAvailableQuantity(
        entry.key,
        excludingTransactionId: excludingTransactionId,
      );

      if (available < entry.value) {
        final availableText =
            Money(available).toDecimalString(decimals: 3);
        final requestedText =
            Money(entry.value).toDecimalString(decimals: 3);

        throw FailureException(
          ConflictFailure(
            'المخزون غير كافٍ لمنتج «${product.name}». '
            'المتاح: $availableText، المطلوب: $requestedText.',
          ),
        );
      }
    }
  }

  Future<int> _getAvailableQuantity(
    String productId, {
    String? excludingTransactionId,
  }) async {
    final exclusionClause = excludingTransactionId == null
        ? ''
        : ' AND t.id <> ?';

    final variables = <Variable<Object>>[
      Variable<String>(productId),
      if (excludingTransactionId != null)
        Variable<String>(excludingTransactionId),
    ];

    final row = await _db.customSelect(
      '''
      SELECT COALESCE(
        SUM(
          CASE
            WHEN t.type = 'purchase' THEN i.quantity
            WHEN t.type = 'sale' THEN -i.quantity
            ELSE 0
          END
        ),
        0
      ) AS available_quantity
      FROM transaction_items i
      INNER JOIN transactions t ON t.id = i.transaction_id
      WHERE i.product_id = ?
        AND i.deleted_at IS NULL
        AND t.deleted_at IS NULL
        AND t.type IN ('purchase', 'sale')
        $exclusionClause
      ''',
      variables: variables,
      readsFrom: {
        _db.products,
        _db.transactionItems,
        _db.transactions,
      },
    ).getSingle();

    return row.read<int>('available_quantity');
  }

  Future<void> _insertItems(Sale sale) async {
    for (final item in sale.items) {
      await _db.into(_db.transactionItems).insert(
            TransactionItemsCompanion.insert(
              transactionId: sale.id,
              productId: item.productId,
              quantity: item.quantityMilli,
              unitPrice: item.unitPrice.minor,
              unitCost: Value(item.unitCost.minor),
            ),
          );
    }
  }

  Future<Sale> _fromRow(TransactionRow row) async {
    final itemRows = await _readActiveItemRows(row.id);

    return Sale(
      id: row.id,
      date: row.date,
      accountId: row.accountId,
      customerId: row.contactId,
      total: Money(row.total),
      paidAmount: Money(row.paidAmount),
      note: row.note,
      items: itemRows
          .map(
            (item) => SaleItem(
              productId: item.productId,
              quantityMilli: item.quantity,
              unitPrice: Money(item.unitPrice),
              unitCost: Money(item.unitCost),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<TransactionRow> _readRow(String id) async {
    final query = _db.select(_db.transactions)
      ..where((row) => row.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) {
      throw const FailureException(
        NotFoundFailure('عملية البيع غير موجودة.'),
      );
    }
    return row;
  }

  Future<TransactionRow?> _readActiveRowOrNull(String id) {
    final query = _db.select(_db.transactions)
      ..where((row) => row.id.equals(id) & row.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  Future<List<TransactionItemRow>> _readActiveItemRows(
    String transactionId,
  ) {
    final query = _db.select(_db.transactionItems)
      ..where(
        (item) =>
            item.transactionId.equals(transactionId) &
            item.deletedAt.isNull(),
      )
      ..orderBy([(item) => OrderingTerm.asc(item.createdAt)]);
    return query.get();
  }

  Future<List<TransactionItemRow>> _readAllItemRows(
    String transactionId,
  ) {
    final query = _db.select(_db.transactionItems)
      ..where((item) => item.transactionId.equals(transactionId))
      ..orderBy([(item) => OrderingTerm.asc(item.createdAt)]);
    return query.get();
  }

  String? _cleanOptional(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  Future<void> _enqueue({
    required TransactionRow row,
    required List<TransactionItemRow> items,
    required OutboxOperation operation,
  }) async {
    final payload = jsonEncode({
      'id': row.id,
      'type': row.type.name,
      'date': row.date.toUtc().toIso8601String(),
      'account_id': row.accountId,
      'to_account_id': row.toAccountId,
      'contact_id': row.contactId,
      'category_id': row.categoryId,
      'total': row.total,
      'paid_amount': row.paidAmount,
      'note': row.note,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
      'sync_status': row.syncStatus,
      'remote_id': row.remoteId,
      'items': items
          .map(
            (item) => {
              'id': item.id,
              'product_id': item.productId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'unit_cost': item.unitCost,
              'created_at': item.createdAt.toUtc().toIso8601String(),
              'updated_at': item.updatedAt.toUtc().toIso8601String(),
              'deleted_at': item.deletedAt?.toUtc().toIso8601String(),
              'sync_status': item.syncStatus,
              'remote_id': item.remoteId,
            },
          )
          .toList(growable: false),
    });

    await _db.into(_db.outbox).insert(
          OutboxCompanion.insert(
            entity: 'transactions',
            entityId: row.id,
            operation: operation,
            payload: payload,
          ),
        );
  }
}
