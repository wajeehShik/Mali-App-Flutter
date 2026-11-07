import 'package:drift/drift.dart';

import 'base_columns.dart';

/// نوع جهة الاتصال.
enum ContactKind { customer, supplier, both }

/// جدول العملاء والموردين.
///
/// الدين لا يُخزَّن هنا، بل يُحسب من العمليات (بيع/شراء/سداد).
@DataClassName('ContactRow')
class Contacts extends Table with BaseColumns {
  TextColumn get name => text().withLength(min: 1, max: 100)();

  TextColumn get phone => text().nullable().withLength(max: 30)();

  TextColumn get kind => textEnum<ContactKind>()();

  TextColumn get note => text().nullable().withLength(max: 500)();
}