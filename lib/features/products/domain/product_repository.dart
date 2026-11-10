import '../../../core/errors/failure.dart';
import 'product.dart';

/// عقد الوصول إلى المنتجات.
abstract interface class ProductRepository {
  /// يراقب المنتجات النشطة، اختياريًا حسب التصنيف.
  Stream<List<Product>> watchActive({String? categoryId});

  /// يجلب جميع المنتجات غير المحذوفة، بما فيها غير النشطة.
  Future<Result<List<Product>>> getAll();

  /// يبحث بالاسم أو الباركود ضمن المنتجات النشطة.
  Future<Result<List<Product>>> search(String query);

  /// يجلب منتجًا نشطًا بالباركود، أو null إن لم يوجد.
  Future<Result<Product?>> getByBarcode(String barcode);

  /// يجلب منتجًا غير محذوف بالمعرّف، أو null إن لم يوجد.
  Future<Result<Product?>> getById(String id);

  /// ينشئ منتجًا ويسجل العملية في outbox داخل معاملة واحدة.
  Future<Result<void>> create(Product product);

  /// يعدّل منتجًا ويسجل العملية في outbox داخل معاملة واحدة.
  Future<Result<void>> update(Product product);

  /// يفعّل أو يعطّل منتجًا مع تسجيل التغيير في outbox.
  Future<Result<void>> setActive(String id, bool isActive);

  /// يحذف المنتج حذفًا ناعمًا ويسجل العملية في outbox ذريًا.
  Future<Result<void>> softDelete(String id);
}
