import '../../../core/errors/failure.dart';
import 'transaction_entry.dart';

/// عقد القراءة لسجل المعاملات.
abstract interface class TransactionRepository {
  /// يراقب المعاملات غير المحذوفة مرتبة من الأحدث إلى الأقدم.
  ///
  /// المدى الزمني نصف مفتوح: [from, to)، أي أن [to] غير مشمول.
  Stream<List<TransactionEntry>> watchTransactions({
    DateTime? from,
    DateTime? to,
    FinancialTransactionType? type,
    String? accountId,
  });

  /// يجلب المعاملات غير المحذوفة مع تطبيق الفلاتر نفسها.
  Future<Result<List<TransactionEntry>>> getTransactions({
    DateTime? from,
    DateTime? to,
    FinancialTransactionType? type,
    String? accountId,
  });

  /// يبحث في رقم المعاملة والملاحظة، مع إمكانية تحديد النوع.
  Future<Result<List<TransactionEntry>>> search(
    String query, {
    FinancialTransactionType? type,
  });

  /// يجلب معاملة غير محذوفة مع بنودها، أو null إن لم توجد.
  Future<Result<TransactionEntry?>> getById(String id);
}
