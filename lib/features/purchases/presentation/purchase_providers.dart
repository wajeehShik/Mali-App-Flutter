import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/errors/failure.dart';
import '../../activation/presentation/activation_providers.dart';
import '../data/purchase_repository_impl.dart';
import '../domain/purchase.dart';
import '../domain/purchase_repository.dart';
import 'purchase_controller.dart';

/// مستودع المشتريات المحلي.
final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// متحكم المشتريات مع التحقق من صلاحية الكتابة الحالية.
final purchaseControllerProvider = Provider<PurchaseController>((ref) {
  return PurchaseController(
    repository: ref.watch(purchaseRepositoryProvider),
    canWrite: () =>
        ref.read(activationControllerProvider).value?.canWrite ?? false,
  );
});

/// يراقب عمليات الشراء غير المحذوفة.
final purchasesProvider = StreamProvider<List<Purchase>>((ref) {
  return ref.watch(purchaseRepositoryProvider).watchPurchases();
});

/// يبحث في عمليات الشراء بالملاحظة أو معرّف العملية.
final purchaseSearchProvider =
    FutureProvider.family<Result<List<Purchase>>, String>((ref, query) {
  return ref.watch(purchaseRepositoryProvider).search(query);
});

/// يجلب جميع عمليات الشراء غير المحذوفة.
final allPurchasesProvider = FutureProvider<Result<List<Purchase>>>((ref) {
  return ref.watch(purchaseRepositoryProvider).getAll();
});
