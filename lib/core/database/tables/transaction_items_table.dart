import 'package:drift/drift.dart';

import 'base_columns.dart';
import 'products_table.dart';
import 'transactions_table.dart';

/// جدول بنود العمليات (للبيع والشراء فقط).
///
/// المخزون الحالي يُحسب من هذا الجدول، لا يُخزَّن في المنتج.
@DataClassName('TransactionItemRow')
class TransactionItems extends Table with BaseColumns {
  TextColumn get transactionId =>
      text().references(Transactions, #id)();

  TextColumn get productId => text().references(Products, #id)();

  /// الكمية بالألف (1.5 = 1500).
  IntColumn get quantity => integer()();

  /// سعر الوحدة وقت العملية بأصغر وحدة نقدية (سعر البيع أو الشراء).
  IntColumn get unitPrice => integer()();

  /// تكلفة الوحدة وقت العملية بأصغر وحدة نقدية (لحساب الربح).
  IntColumn get unitCost => integer().withDefault(const Constant(0))();
}