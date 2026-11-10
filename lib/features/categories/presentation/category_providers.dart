import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../activation/presentation/activation_providers.dart';
import '../data/category_repository_impl.dart';
import '../domain/category_repository.dart';
import 'category_controller.dart';

/// مستودع التصنيفات المحلي.
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// متحكم التصنيفات مع التحقق من صلاحية الكتابة الحالية.
final categoryControllerProvider = Provider<CategoryController>((ref) {
  return CategoryController(
    repository: ref.watch(categoryRepositoryProvider),
    canWrite: () =>
        ref.read(activationControllerProvider).value?.canWrite ?? false,
  );
});
