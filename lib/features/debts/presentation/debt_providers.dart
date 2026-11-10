import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/errors/failure.dart';
import '../../activation/presentation/activation_providers.dart';
import '../data/debt_repository_impl.dart';
import '../domain/debt_balance.dart';
import '../domain/debt_repository.dart';
import 'debt_controller.dart';

/// مستودع الديون المحلي.
final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// متحكم تسجيل السداد مع التحقق من صلاحية الكتابة الحالية.
final debtControllerProvider = Provider<DebtController>((ref) {
  return DebtController(
    repository: ref.watch(debtRepositoryProvider),
    canWrite: () =>
        ref.read(activationControllerProvider).value?.canWrite ?? false,
  );
});

/// يراقب أرصدة ديون العملاء والموردين.
final debtBalancesProvider = StreamProvider<List<DebtBalance>>((ref) {
  return ref.watch(debtRepositoryProvider).watchBalances();
});

/// يجلب أرصدة الديون الحالية.
final allDebtBalancesProvider =
    FutureProvider<Result<List<DebtBalance>>>((ref) {
  return ref.watch(debtRepositoryProvider).getBalances();
});
