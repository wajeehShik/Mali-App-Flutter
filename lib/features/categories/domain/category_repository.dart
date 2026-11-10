import '../../../core/errors/failure.dart';
import 'category.dart';

abstract interface class CategoryRepository {
  /// يراقب تصنيفات نوع محدد، غير المحذوفة.
  Stream<List<Category>> watchByKind(CategoryKind kind);

  /// يجلب كل التصنيفات غير المحذوفة.
  Future<Result<List<Category>>> getAll();

  /// يجلب تصنيفًا غير محذوف، أو null إن لم يوجد.
  Future<Result<Category?>> getById(String id);

  /// ينشئ تصنيفًا ويسجل التغيير في outbox ذريًا.
  Future<Result<void>> create(Category category);

  /// يعدّل تصنيفًا ويسجل التغيير في outbox ذريًا.
  Future<Result<void>> update(Category category);

  /// يحذف التصنيف حذفًا ناعمًا ويسجل الحذف في outbox ذريًا.
  Future<Result<void>> softDelete(String id);
}
