import '../../../core/errors/failure.dart';
import 'contact.dart';

/// عقد الوصول إلى العملاء والموردين.
abstract interface class ContactRepository {
  /// يراقب العملاء (customer وboth) غير المحذوفين.
  Stream<List<Contact>> watchCustomers();

  /// يراقب الموردين (supplier وboth) غير المحذوفين.
  Stream<List<Contact>> watchSuppliers();

  /// يرجع كل جهات الاتصال غير المحذوفة.
  Future<Result<List<Contact>>> getAll();

  /// يبحث بالاسم أو الهاتف.
  Future<Result<List<Contact>>> search(String query);

  /// يجلب جهة غير محذوفة، أو null إن لم توجد.
  Future<Result<Contact?>> getById(String id);

  /// ينشئ جهة اتصال ويسجلها في outbox داخل معاملة واحدة.
  Future<Result<void>> create(Contact contact);

  /// يعدّل جهة اتصال ويسجل التعديل في outbox داخل معاملة واحدة.
  Future<Result<void>> update(Contact contact);

  /// يحذف جهة الاتصال حذفًا ناعمًا ويسجل الحذف في outbox ذريًا.
  Future<Result<void>> softDelete(String id);
}
