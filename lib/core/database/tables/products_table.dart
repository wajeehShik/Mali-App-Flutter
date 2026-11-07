import 'package:drift/drift.dart';

import 'base_columns.dart';
import 'categories_table.dart';

/// جدول المنتجات.
///
/// المخزون الحالي لا يُخزَّن هنا، بل يُحسب من حركات الشراء والبيع.
@DataClassName('ProductRow')
class Products extends Table with BaseColumns {
  TextColumn get name => text().withLength(min: 1, max: 150)();

  /// تصنيف المنتج (اختياري). يشير إلى [Categories.id].
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();

  TextColumn get barcode => text().nullable().withLength(max: 64)();

  /// وحدة القياس للعرض (قطعة، كغ، متر...).
  TextColumn get unit => text().withDefault(const Constant('قطعة'))();

  /// سعر البيع بأصغر وحدة نقدية.
  IntColumn get salePrice => integer().withDefault(const Constant(0))();

  /// سعر التكلفة بأصغر وحدة نقدية.
  IntColumn get costPrice => integer().withDefault(const Constant(0))();

  /// حد التنبيه للمخزون المنخفض، بالألف (1.5 = 1500).
  IntColumn get minStock => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}