import 'package:drift/drift.dart';

/// جدول الإعدادات (مفتاح/قيمة). خاص بالجهاز ولا يُزامَن.
///
/// أمثلة على المفاتيح: currency، decimals، cycle_day.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text().withLength(min: 1, max: 64)();

  TextColumn get value => text()();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {key};
}