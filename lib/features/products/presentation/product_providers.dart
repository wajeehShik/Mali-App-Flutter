import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../activation/presentation/activation_providers.dart';
import '../data/product_repository_impl.dart';
import '../domain/product_repository.dart';
import 'product_controller.dart';

/// مستودع المنتجات المحلي.
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// متحكم المنتجات مع التحقق من صلاحية الكتابة الحالية.
final productControllerProvider = Provider<ProductController>((ref) {
  return ProductController(
    repository: ref.watch(productRepositoryProvider),
    canWrite: () =>
        ref.read(activationControllerProvider).value?.canWrite ?? false,
  );
});
