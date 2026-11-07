import 'package:drift/drift.dart';

import 'base_columns.dart';

/// نوع التصنيف: لأي جزء من التطبيق يُستخدم.
enum CategoryKind { income, expense, product }

/// جدول التصنيفات (دخل، مصروف، منتج).
@DataClassName('CategoryRow')
class Categories extends Table with BaseColumns {
  TextColumn get name => text().withLength(min: 1, max: 100)();

  TextColumn get kind => textEnum<CategoryKind>()();
}