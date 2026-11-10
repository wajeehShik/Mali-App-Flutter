import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/categories_table.dart' as db_categories;
import '../../../core/database/tables/outbox_table.dart';
import '../../../core/errors/failure.dart';
import '../domain/category.dart';
import '../domain/category_repository.dart';

/// تنفيذ مستودع التصنيفات محليًا عبر Drift.
class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Category>> watchByKind(CategoryKind kind) {
    final dbKind = db_categories.CategoryKind.values.byName(kind.name);
    return _db.categoriesDao
        .watchByKind(dbKind)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Future<Result<List<Category>>> getAll() {
    return guardAsync(() async {
      final rows = await _db.categoriesDao.getAll();
      return rows.map(_fromRow).toList(growable: false);
    });
  }

  @override
  Future<Result<Category?>> getById(String id) {
    return guardAsync(() async {
      final row = await _db.categoriesDao.getById(id);
      return row == null ? null : _fromRow(row);
    });
  }

  @override
  Future<Result<void>> create(Category category) {
    final failure = _validate(category);
    if (failure != null) return Future.value(Err<void>(failure));

    return guardAsync(() async {
      await _db.transaction(() async {
        await _db.into(_db.categories).insert(
              CategoriesCompanion.insert(
                id: Value(category.id),
                name: category.name.trim(),
                kind: db_categories.CategoryKind.values.byName(
                  category.kind.name,
                ),
              ),
            );

        final row = await _readRow(category.id);
        await _enqueue(row: row, operation: OutboxOperation.create);
      });
    });
  }

  @override
  Future<Result<void>> update(Category category) {
    final failure = _validate(category);
    if (failure != null) return Future.value(Err<void>(failure));

    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(category.id);
        if (existing == null) {
          throw const FailureException(
            NotFoundFailure('التصنيف غير موجود.'),
          );
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.categories)
              ..where((row) => row.id.equals(category.id)))
            .write(
          CategoriesCompanion(
            name: Value(category.name.trim()),
            kind: Value(
              db_categories.CategoryKind.values.byName(category.kind.name),
            ),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final row = await _readRow(category.id);
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
            NotFoundFailure('التصنيف غير موجود.'),
          );
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.categories)..where((row) => row.id.equals(id)))
            .write(
          CategoriesCompanion(
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

  Category _fromRow(CategoryRow row) {
    return Category(
      id: row.id,
      name: row.name,
      kind: CategoryKind.values.byName(row.kind.name),
    );
  }

  Failure? _validate(Category category) {
    final errors = <String, String>{};
    final name = category.name.trim();

    if (category.id.trim().isEmpty) {
      errors['id'] = 'معرّف التصنيف مطلوب.';
    }
    if (name.isEmpty) {
      errors['name'] = 'اسم التصنيف مطلوب.';
    } else if (name.length > 100) {
      errors['name'] = 'اسم التصنيف طويل جدًا.';
    }

    if (errors.isEmpty) return null;
    return ValidationFailure('تحقق من بيانات التصنيف.', fieldErrors: errors);
  }

  Future<CategoryRow> _readRow(String id) async {
    final query = _db.select(_db.categories)
      ..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();

    if (row == null) {
      throw const FailureException(
        NotFoundFailure('التصنيف غير موجود.'),
      );
    }
    return row;
  }

  Future<CategoryRow?> _readActiveRowOrNull(String id) {
    final query = _db.select(_db.categories)
      ..where((row) => row.id.equals(id) & row.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  Future<void> _enqueue({
    required CategoryRow row,
    required OutboxOperation operation,
  }) async {
    final payload = jsonEncode({
      'id': row.id,
      'name': row.name,
      'kind': row.kind.name,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
      'sync_status': row.syncStatus,
      'remote_id': row.remoteId,
    });

    await _db.into(_db.outbox).insert(
          OutboxCompanion.insert(
            entity: 'categories',
            entityId: row.id,
            operation: operation,
            payload: payload,
          ),
        );
  }
}
