import 'package:drift/drift.dart';

import 'base_columns.dart';

/// نوع الحساب.
enum AccountType { cash, bank, wallet }

/// جدول الحسابات والمحافظ.
///
/// الرصيد الحالي لا يُخزَّن هنا، بل يُحسب من [openingBalance] وسجل العمليات.
@DataClassName('AccountRow')
class Accounts extends Table with BaseColumns {
  TextColumn get name => text().withLength(min: 1, max: 100)();

  TextColumn get type => textEnum<AccountType>()();

  /// الرصيد الافتتاحي بأصغر وحدة نقدية (يقبل السالب).
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();

  /// رمز العملة (جاهز للمستقبل، عملة واحدة حاليًا).
  TextColumn get currency => text().withDefault(const Constant('ILS'))();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}