import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../activation/presentation/activation_providers.dart';
import '../data/account_repository_impl.dart';
import '../data/transfer_repository_impl.dart';
import '../domain/account_repository.dart';
import '../domain/transfer_repository.dart';
import 'account_controller.dart';
import 'transfer_controller.dart';

/// مستودع الحسابات المحلي.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// مستودع التحويلات المحلي.
final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return TransferRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// متحكم تعديل الحسابات مع التحقق من صلاحية الكتابة الحالية.
final accountControllerProvider = Provider<AccountController>((ref) {
  return AccountController(
    repository: ref.watch(accountRepositoryProvider),
    canWrite: () =>
        ref.read(activationControllerProvider).value?.canWrite ?? false,
  );
});

/// متحكم إنشاء وحذف التحويلات مع التحقق من صلاحية الكتابة الحالية.
final transferControllerProvider = Provider<TransferController>((ref) {
  return TransferController(
    repository: ref.watch(transferRepositoryProvider),
    canWrite: () =>
        ref.read(activationControllerProvider).value?.canWrite ?? false,
  );
});
