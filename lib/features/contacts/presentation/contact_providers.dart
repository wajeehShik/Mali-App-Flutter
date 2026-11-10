import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../activation/presentation/activation_providers.dart';
import '../data/contact_repository_impl.dart';
import '../domain/contact_repository.dart';
import 'contact_controller.dart';

/// مستودع جهات الاتصال المحلي.
final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// متحكم الكتابة على جهات الاتصال مع فحص صلاحية التفعيل الحالية.
final contactControllerProvider = Provider<ContactController>((ref) {
  return ContactController(
    repository: ref.watch(contactRepositoryProvider),
    canWrite: () =>
        ref.read(activationControllerProvider).value?.canWrite ?? false,
  );
});
