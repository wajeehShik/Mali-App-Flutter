import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const Uuid uuid = Uuid();

/// حالة المزامنة لكل سجل.
enum SyncStatus {
  /// لم يُرسل بعد إلى الخادم (أو عُدّل بعد آخر إرسال).
  pending,

  /// تمت مزامنته مع الخادم.
  synced,

  /// فشل الإرسال ويُعاد لاحقًا.
  failed,
}

/// الأعمدة المشتركة في كل جداول التطبيق (ما عدا `outbox` و`settings`).
mixin BaseColumns on Table {
  /// معرّف UUID يُولَّد محليًا.
  TextColumn get id => text().clientDefault(() => uuid.v4())();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  /// حذف ناعم: null يعني السجل فعّال.
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending'))();

  /// معرّف السجل على الخادم (يُملأ بعد أول مزامنة ناجحة).
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}