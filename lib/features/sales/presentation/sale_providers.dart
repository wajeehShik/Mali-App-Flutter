import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/errors/failure.dart';
import '../../activation/presentation/activation_providers.dart';
import '../data/sale_repository_impl.dart';
import '../domain/sale.dart';
import '../domain/sale_repository.dart';
import 'sale_controller.dart';

/// مستودع المبيعات المحلي.
final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// متحكم المبيعات مع التحقق من صلاحية الكتابة الحالية.
final saleControllerProvider = Provider<SaleController>((ref) {
  return SaleController(
    repository: ref.watch(saleRepositoryProvider),
    canWrite: () =>
        ref.read(activationControllerProvider).value?.canWrite ?? false,
  );
});

/// يراقب عمليات البيع غير المحذوفة.
final salesProvider = StreamProvider<List<Sale>>((ref) {
  return ref.watch(saleRepositoryProvider).watchSales();
});

/// يبحث في عمليات البيع بالملاحظة أو معرّف العملية.
final saleSearchProvider =
    FutureProvider.family<Result<List<Sale>>, String>((ref, query) {
  return ref.watch(saleRepositoryProvider).search(query);
});

/// يجلب جميع عمليات البيع غير المحذوفة.
final allSalesProvider = FutureProvider<Result<List<Sale>>>((ref) {
  return ref.watch(saleRepositoryProvider).getAll();
});
