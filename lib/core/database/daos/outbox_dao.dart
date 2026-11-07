import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/outbox_table.dart';

part 'outbox_dao.g.dart';

/// وصول مباشر لطابور المزامنة. لا شبكة ولا منطق مزامنة هنا.
@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  /// يضيف عنصرًا إلى الطابور ويعيد رقمه.
  Future<int> enqueue({
    required String entity,
    required String entityId,
    required OutboxOperation operation,
    required String payload,
  }) {
    return into(outbox).insert(
      OutboxCompanion.insert(
        entity: entity,
        entityId: entityId,
        operation: operation,
        payload: payload,
      ),
    );
  }

  /// العناصر المعلّقة بترتيب الإرسال (الأقدم أولًا).
  Future<List<OutboxRow>> getPending({int limit = 50}) {
    final query = select(outbox)
      ..orderBy([(o) => OrderingTerm.asc(o.id)])
      ..limit(limit);
    return query.get();
  }

  /// عدد العناصر المعلّقة، وتتحدث تلقائيًا (لمؤشر المزامنة في الواجهة).
  Stream<int> watchPendingCount() {
    final count = outbox.id.count();
    final query = selectOnly(outbox)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// يحذف عنصرًا بعد نجاح إرساله.
  Future<void> remove(int id) {
    return (delete(outbox)..where((o) => o.id.equals(id))).go();
  }

  /// يسجّل فشل محاولة: يزيد العدّاد ويحفظ رسالة الخطأ.
  Future<void> markFailed(int id, String error) {
    return customUpdate(
      'UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      variables: [Variable.withString(error), Variable.withInt(id)],
      updates: {outbox},
    );
  }
}