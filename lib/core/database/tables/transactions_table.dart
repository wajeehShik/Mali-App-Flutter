import 'package:drift/drift.dart';

import 'accounts_table.dart';
import 'base_columns.dart';
import 'categories_table.dart';
import 'contacts_table.dart';

/// نوع العملية المالية.
enum TransactionType {
  /// دخل (إيراد غير مرتبط بمنتجات).
  income,

  /// مصروف.
  expense,

  /// بيع منتجات.
  sale,

  /// شراء منتجات.
  purchase,

  /// تحويل بين حسابين.
  transfer,

  /// سداد دين وارد: عميل يسدد لنا.
  debtIn,

  /// سداد دين صادر: نسدد لمورد.
  debtOut,
}

/// جدول العمليات المالية (المصدر الوحيد للأرصدة والديون والمخزون).
@DataClassName('TransactionRow')
class Transactions extends Table with BaseColumns {
  TextColumn get type => textEnum<TransactionType>()();

  /// تاريخ العملية (قد يختلف عن وقت إنشاء السجل).
  DateTimeColumn get date => dateTime()();

  /// الحساب الذي تمت عليه العملية (المصدر في التحويل).
  @ReferenceName('sourceTransactions')
  TextColumn get accountId => text().references(Accounts, #id)();

  /// الحساب الوجهة (للتحويل فقط).
  @ReferenceName('incomingTransfers')
  TextColumn get toAccountId =>
      text().nullable().references(Accounts, #id)();

  TextColumn get contactId =>
      text().nullable().references(Contacts, #id)();

  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();

  /// إجمالي العملية بأصغر وحدة نقدية.
  IntColumn get total => integer()();

  /// المبلغ المدفوع فعليًا بأصغر وحدة نقدية.
  IntColumn get paidAmount => integer()();

  TextColumn get note => text().nullable().withLength(max: 500)();
}