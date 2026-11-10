import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import 'account.dart';

/// عقد التعامل مع الحسابات.
///
/// التنفيذ الفعلي يقرأ ويكتب عبر Drift، ويحفظ تغييرات الحسابات
/// وعناصر outbox داخل معاملة واحدة.
abstract interface class AccountRepository {
  /// يراقب الحسابات غير المؤرشفة وغير المحذوفة.
  Stream<List<Account>> watchActive();

  /// يرجع جميع الحسابات غير المحذوفة، بما فيها المؤرشفة.
  Future<Result<List<Account>>> getAll();

  /// يجلب حسابًا غير محذوف، أو null إن لم يوجد.
  Future<Result<Account?>> getById(String id);

  /// ينشئ حسابًا جديدًا.
  Future<Result<void>> create(Account account);

  /// يعدّل بيانات الحساب، ولا يغيّر الرصيد الناتج عن العمليات.
  Future<Result<void>> update(Account account);

  /// يؤرشف الحساب ويبقي سجله وعملياته.
  Future<Result<void>> archive(String id);

  /// يحذف الحساب حذفًا ناعمًا.
  ///
  /// التنفيذ يرفض الحذف إذا كان الحساب مرتبطًا بعمليات فعّالة؛
  /// سنضيف هذا التحقق عند بناء التنفيذ واختباراته.
  Future<Result<void>> softDelete(String id);

  /// يحسب الرصيد من الرصيد الافتتاحي والعمليات غير المحذوفة.
  Future<Result<Money>> getBalance(String id);
}
