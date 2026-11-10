import '../../../core/errors/failure.dart';
import 'account_transfer.dart';

/// عقد عمليات تحويل الأموال بين الحسابات.
///
/// التنفيذ المحلي يحفظ سجل التحويل وعنصر outbox المرتبط به داخل
/// معاملة قاعدة بيانات واحدة، لضمان عدم تسجيل أحدهما دون الآخر.
abstract interface class TransferRepository {
  /// ينشئ تحويلًا جديدًا بعد التحقق من الحسابين والطلب.
  Future<Result<void>> createTransfer(AccountTransfer transfer);

  /// يجلب تحويلًا غير محذوف، أو null إن لم يوجد.
  Future<Result<AccountTransfer?>> getTransferById(String id);

  /// يحذف التحويل حذفًا ناعمًا ويسجل عملية الحذف في outbox ذريًا.
  Future<Result<void>> softDeleteTransfer(String id);
}
