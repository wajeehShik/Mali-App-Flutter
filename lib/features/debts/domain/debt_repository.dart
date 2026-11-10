import '../../../core/errors/failure.dart';
import 'debt_balance.dart';
import 'debt_payment.dart';

/// عقد الوصول إلى أرصدة الديون وعمليات السداد.
abstract interface class DebtRepository {
  /// يراقب أرصدة العملاء والموردين المشتقة من سجل العمليات.
  Stream<List<DebtBalance>> watchBalances();

  /// يجلب أرصدة الديون الحالية.
  Future<Result<List<DebtBalance>>> getBalances();

  /// يجلب رصيد جهة اتصال باتجاه محدد، أو null إذا لم يكن عليها رصيد.
  Future<Result<DebtBalance?>> getBalance(
    String contactId,
    DebtDirection direction,
  );

  /// يسجل سدادًا أو تحصيلًا كعملية مالية، مع outbox ذريًا.
  Future<Result<void>> recordPayment(DebtPayment payment);
}
