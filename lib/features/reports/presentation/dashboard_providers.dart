import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/presentation/transaction_providers.dart';
import '../data/dashboard_repository_impl.dart';
import '../domain/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

/// مستودع لوحة التحكم المبني على سجل المعاملات.
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
    ref.watch(transactionRepositoryProvider),
  );
});

/// ملخص مالي مباشر يتحدث عند تغيّر المعاملات.
final dashboardSummaryProvider = StreamProvider<DashboardSummary>((ref) {
  return ref.watch(dashboardRepositoryProvider).watchSummary();
});
