import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/errors/failure.dart';
import '../data/transaction_repository_impl.dart';
import '../domain/transaction_entry.dart';
import '../domain/transaction_repository.dart';

/// مستودع سجل المعاملات للقراءة فقط.
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// يراقب كامل سجل المعاملات غير المحذوفة.
final transactionsProvider = StreamProvider<List<TransactionEntry>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchTransactions();
});

/// يبحث في سجل المعاملات بمعرّف العملية أو الملاحظة.
final transactionSearchProvider =
    FutureProvider.family<Result<List<TransactionEntry>>, String>(
  (ref, query) {
    return ref.watch(transactionRepositoryProvider).search(query);
  },
);

/// يجلب معاملة واحدة مع بنودها، أو null إذا لم تكن موجودة.
final transactionDetailsProvider =
    FutureProvider.family<Result<TransactionEntry?>, String>((ref, id) {
  return ref.watch(transactionRepositoryProvider).getById(id);
});
