import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/categories_table.dart' as db_categories;
import '../../../core/database/tables/outbox_table.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

/// تنفيذ مستودع المنتجات محليًا عبر Drift.
class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Product>> watchActive({String? categoryId}) {
    return _db.productsDao
        .watchActive(categoryId: categoryId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Future<Result<List<Product>>> getAll() {
    return guardAsync(() async {
      final rows = await _db.productsDao.getAll();
      return rows.map(_fromRow).toList(growable: false);
    });
  }

  @override
  Future<Result<List<Product>>> search(String query) {
    return guardAsync(() async {
      final rows = await _db.productsDao.search(query);
      return rows.map(_fromRow).toList(growable: false);
    });
  }

  @override
  Future<Result<Product?>> getByBarcode(String barcode) {
    return guardAsync(() async {
      final row = await _db.productsDao.getByBarcode(barcode.trim());
      return row == null ? null : _fromRow(row);
    });
  }

  @override
  Future<Result<Product?>> getById(String id) {
    return guardAsync(() async {
      final row = await _db.productsDao.getById(id);
      return row == null ? null : _fromRow(row);
    });
  }

  @override
  Future<Result<void>> create(Product product) {
    final failure = _validate(product);
    if (failure != null) return Future.value(Err<void>(failure));

    return guardAsync(() async {
      await _db.transaction(() async {
        await _validateCategory(product.categoryId);

        await _db.into(_db.products).insert(
              ProductsCompanion.insert(
                id: Value(product.id),
                name: product.name.trim(),
                categoryId: Value(product.categoryId),
                barcode: Value(_clean(product.barcode)),
                unit: Value(product.unit.trim()),
                salePrice: Value(product.salePrice.minor),
                costPrice: Value(product.costPrice.minor),
                minStock: Value(product.minStock),
                isActive: Value(product.isActive),
              ),
            );

        final row = await _readRow(product.id);
        await _enqueue(row: row, operation: OutboxOperation.create);
      });
    });
  }

  @override
  Future<Result<void>> update(Product product) {
    final failure = _validate(product);
    if (failure != null) return Future.value(Err<void>(failure));

    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(product.id);
        if (existing == null) {
          throw const FailureException(
            NotFoundFailure('المنتج غير موجود.'),
          );
        }

        await _validateCategory(product.categoryId);

        final now = DateTime.now().toUtc();
        await (_db.update(_db.products)
              ..where((row) => row.id.equals(product.id)))
            .write(
          ProductsCompanion(
            name: Value(product.name.trim()),
            categoryId: Value(product.categoryId),
            barcode: Value(_clean(product.barcode)),
            unit: Value(product.unit.trim()),
            salePrice: Value(product.salePrice.minor),
            costPrice: Value(product.costPrice.minor),
            minStock: Value(product.minStock),
            isActive: Value(product.isActive),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final row = await _readRow(product.id);
        await _enqueue(row: row, operation: OutboxOperation.update);
      });
    });
  }

  @override
  Future<Result<void>> setActive(String id, bool isActive) {
    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(id);
        if (existing == null) {
          throw const FailureException(
            NotFoundFailure('المنتج غير موجود.'),
          );
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.products)..where((row) => row.id.equals(id)))
            .write(
          ProductsCompanion(
            isActive: Value(isActive),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final row = await _readRow(id);
        await _enqueue(row: row, operation: OutboxOperation.update);
      });
    });
  }

  @override
  Future<Result<void>> softDelete(String id) {
    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(id);
        if (existing == null) {
          throw const FailureException(
            NotFoundFailure('المنتج غير موجود.'),
          );
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.products)..where((row) => row.id.equals(id)))
            .write(
          ProductsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final row = await _readRow(id);
        await _enqueue(row: row, operation: OutboxOperation.delete);
      });
    });
  }

  Product _fromRow(ProductRow row) {
    return Product(
      id: row.id,
      name: row.name,
      categoryId: row.categoryId,
      barcode: row.barcode,
      unit: row.unit,
      salePrice: Money(row.salePrice),
      costPrice: Money(row.costPrice),
      minStock: row.minStock,
      isActive: row.isActive,
    );
  }

  Failure? _validate(Product product) {
    final errors = <String, String>{};
    final name = product.name.trim();
    final unit = product.unit.trim();
    final barcode = product.barcode?.trim();

    if (product.id.trim().isEmpty) {
      errors['id'] = 'معرّف المنتج مطلوب.';
    }
    if (name.isEmpty) {
      errors['name'] = 'اسم المنتج مطلوب.';
    } else if (name.length > 150) {
      errors['name'] = 'اسم المنتج طويل جدًا.';
    }
    if (unit.isEmpty) {
      errors['unit'] = 'وحدة المنتج مطلوبة.';
    }
    if (barcode != null && barcode.length > 64) {
      errors['barcode'] = 'الباركود طويل جدًا.';
    }
    if (product.salePrice.isNegative) {
      errors['salePrice'] = 'سعر البيع لا يمكن أن يكون سالبًا.';
    }
    if (product.costPrice.isNegative) {
      errors['costPrice'] = 'سعر التكلفة لا يمكن أن يكون سالبًا.';
    }
    if (product.minStock < 0) {
      errors['minStock'] = 'حد المخزون لا يمكن أن يكون سالبًا.';
    }

    if (errors.isEmpty) return null;
    return ValidationFailure(
      'تحقق من بيانات المنتج.',
      fieldErrors: errors,
    );
  }

  Future<void> _validateCategory(String? categoryId) async {
    if (categoryId == null || categoryId.trim().isEmpty) return;

    final category = await _db.categoriesDao.getById(categoryId);
    if (category == null) {
      throw const FailureException(
        NotFoundFailure('تصنيف المنتج غير موجود.'),
      );
    }
    if (category.kind != db_categories.CategoryKind.product) {
      throw const FailureException(
        ConflictFailure('يجب اختيار تصنيف من نوع المنتجات.'),
      );
    }
  }

  Future<ProductRow> _readRow(String id) async {
    final query = _db.select(_db.products)
      ..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();

    if (row == null) {
      throw const FailureException(
        NotFoundFailure('المنتج غير موجود.'),
      );
    }
    return row;
  }

  Future<ProductRow?> _readActiveRowOrNull(String id) {
    final query = _db.select(_db.products)
      ..where((row) => row.id.equals(id) & row.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  Future<void> _enqueue({
    required ProductRow row,
    required OutboxOperation operation,
  }) async {
    final payload = jsonEncode({
      'id': row.id,
      'name': row.name,
      'category_id': row.categoryId,
      'barcode': row.barcode,
      'unit': row.unit,
      'sale_price': row.salePrice,
      'cost_price': row.costPrice,
      'min_stock': row.minStock,
      'is_active': row.isActive,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
      'sync_status': row.syncStatus,
      'remote_id': row.remoteId,
    });

    await _db.into(_db.outbox).insert(
          OutboxCompanion.insert(
            entity: 'products',
            entityId: row.id,
            operation: operation,
            payload: payload,
          ),
        );
  }
}
