import '../../transactions/domain/transaction_repository.dart';
import '../domain/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

/// يبني ملخص لوحة التحكم مباشرة من سجل المعاملات المتدفق.
class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._transactionRepository);

  final TransactionRepository _transactionRepository;

  @override
  Stream<DashboardSummary> watchSummary() {
    return _transactionRepository
        .watchTransactions()
        .map(DashboardSummary.fromTransactions);
  }
}
