import '../../../core/errors/failure.dart';
import 'sale.dart';

/// عقد الوصول إلى عمليات البيع.
abstract interface class SaleRepository {
  /// يراقب عمليات البيع ضمن المدى [from, to)، مع استثناء الحد الأعلى.
  ///
  /// يمكن تمرير [customerId] لتصفية النتائج حسب العميل.
  Stream<List<Sale>> watchSales({
    DateTime? from,
    DateTime? to,
    String? customerId,
  });

  /// يجلب جميع عمليات البيع غير المحذوفة.
  Future<Result<List<Sale>>> getAll();

  /// يبحث في المبيعات بالملاحظة أو معرّف العملية.
  Future<Result<List<Sale>>> search(String query);

  /// يجلب عملية بيع بمعرّفها، أو null إن لم توجد.
  Future<Result<Sale?>> getById(String id);

  /// ينشئ عملية البيع وبنودها ويسجلها في outbox ذريًا.
  Future<Result<void>> create(Sale sale);

  /// يعدّل عملية البيع ويستبدل بنودها ويسجل التعديل في outbox ذريًا.
  Future<Result<void>> update(Sale sale);

  /// يحذف عملية البيع وبنودها حذفًا ناعمًا ويسجل الحذف في outbox ذريًا.
  Future<Result<void>> softDelete(String id);
}
