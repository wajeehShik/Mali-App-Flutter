import 'package:drift/drift.dart';

/// نوع العملية المسجَّلة في الطابور.
enum OutboxOperation { create, update, delete }

/// طابور المزامنة المحلي. خاص بالجهاز ولا يُزامَن نفسه.
///
/// الترتيب بحسب [id] التصاعدي هو ترتيب الإرسال.
@DataClassName('OutboxRow')
class Outbox extends Table {
  /// رقم متسلسل يحدد ترتيب الإرسال.
  IntColumn get id => integer().autoIncrement()();

  /// اسم الكيان (مثل: transactions، products).
  TextColumn get entity => text().withLength(min: 1, max: 64)();

  /// معرّف السجل المحلي (UUID).
  TextColumn get entityId => text()();

  TextColumn get operation => textEnum<OutboxOperation>()();

  /// نسخة JSON من السجل وقت التعديل.
  TextColumn get payload => text()();

  /// عدد محاولات الإرسال الفاشلة.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// آخر رسالة خطأ (للتشخيص).
  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
}