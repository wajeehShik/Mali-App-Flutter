import '../../../core/errors/failure.dart';
import 'purchase.dart';

/// عقد الوصول إلى عمليات الشراء.
abstract interface class PurchaseRepository {
  /// يراقب المشتريات ضمن المدى [from, to)، مع استثناء الحد الأعلى.
  ///
  /// يمكن تمرير [supplierId] لتصفية النتائج حسب المورد.
  Stream<List<Purchase>> watchPurchases({
    DateTime? from,
    DateTime? to,
    String? supplierId,
  });

  /// يجلب جميع المشتريات غير المحذوفة.
  Future<Result<List<Purchase>>> getAll();

  /// يبحث في المشتريات بالملاحظة أو معرّف العملية.
  Future<Result<List<Purchase>>> search(String query);

  /// يجلب عملية شراء بمعرّفها، أو null إن لم توجد.
  Future<Result<Purchase?>> getById(String id);

  /// ينشئ عملية الشراء وبنودها ويسجلها في outbox ذريًا.
  Future<Result<void>> create(Purchase purchase);

  /// يعدّل عملية الشراء ويستبدل بنودها ويسجل التعديل في outbox ذريًا.
  Future<Result<void>> update(Purchase purchase);

  /// يحذف عملية الشراء وبنودها حذفًا ناعمًا ويسجل الحذف في outbox ذريًا.
  Future<Result<void>> softDelete(String id);
}
