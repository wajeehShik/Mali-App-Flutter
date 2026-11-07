import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/settings_table.dart';

part 'settings_dao.g.dart';

/// وصول مباشر لجدول الإعدادات (مفتاح/قيمة). خاص بالجهاز ولا يُزامَن.
@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// قيمة الإعداد، أو null إن لم يُحفظ.
  Future<String?> getValue(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// يراقب قيمة الإعداد ويصدر قيمة جديدة عند كل تغيير (null إن لم يوجد).
  Stream<String?> watchValue(String key) {
    return (select(settings)..where((s) => s.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  /// يحفظ الإعداد: ينشئه إن لم يوجد أو يستبدل قيمته.
  Future<void> setValue(String key, String value) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion(
        key: Value(key),
        value: Value(value),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// يحذف الإعداد نهائيًا (يعود للقيمة الافتراضية في الكود).
  Future<void> remove(String key) {
    return (delete(settings)..where((s) => s.key.equals(key))).go();
  }

  /// كل الإعدادات كخريطة مفتاح ← قيمة (للنسخ الاحتياطي).
  Future<Map<String, String>> getAll() async {
    final rows = await select(settings).get();
    return {for (final r in rows) r.key: r.value};
  }
}