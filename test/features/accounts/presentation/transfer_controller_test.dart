import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/accounts/domain/account_transfer.dart';
import 'package:mali/features/accounts/domain/transfer_repository.dart';
import 'package:mali/features/accounts/presentation/transfer_controller.dart';

class _FakeTransferRepository implements TransferRepository {
  int createCalls = 0;
  int deleteCalls = 0;
  AccountTransfer? createdTransfer;
  String? deletedId;

  @override
  Future<Result<void>> createTransfer(AccountTransfer transfer) async {
    createCalls += 1;
    createdTransfer = transfer;
    return const Ok<void>(null);
  }

  @override
  Future<Result<AccountTransfer?>> getTransferById(String id) async {
    return const Ok(null);
  }

  @override
  Future<Result<void>> softDeleteTransfer(String id) async {
    deleteCalls += 1;
    deletedId = id;
    return const Ok<void>(null);
  }
}

void main() {
  final transfer = AccountTransfer(
    id: 'transfer-1',
    fromAccountId: 'cash-1',
    toAccountId: 'bank-1',
    amount: const Money(2500),
    date: DateTime.utc(2026, 11, 9),
  );

  group('TransferController', () {
    test('يمنع إنشاء تحويل عندما لا توجد صلاحية كتابة', () async {
      final repository = _FakeTransferRepository();
      final controller = TransferController(
        repository: repository,
        canWrite: () => false,
      );

      final failure = await controller.create(transfer);

      expect(failure, isA<ActivationFailure>());
      expect(
        (failure! as ActivationFailure).reason,
        ActivationFailureReason.expired,
      );
      expect(repository.createCalls, 0);
      expect(repository.createdTransfer, isNull);
    });

    test('ينشئ التحويل عبر المستودع عندما تكون الكتابة مسموحة', () async {
      final repository = _FakeTransferRepository();
      final controller = TransferController(
        repository: repository,
        canWrite: () => true,
      );

      final failure = await controller.create(transfer);

      expect(failure, isNull);
      expect(repository.createCalls, 1);
      expect(repository.createdTransfer, transfer);
    });

    test('يمنع حذف التحويل عندما لا توجد صلاحية كتابة', () async {
      final repository = _FakeTransferRepository();
      final controller = TransferController(
        repository: repository,
        canWrite: () => false,
      );

      final failure = await controller.softDelete('transfer-1');

      expect(failure, isA<ActivationFailure>());
      expect(repository.deleteCalls, 0);
      expect(repository.deletedId, isNull);
    });

    test('يحذف التحويل عبر المستودع عندما تكون الكتابة مسموحة', () async {
      final repository = _FakeTransferRepository();
      final controller = TransferController(
        repository: repository,
        canWrite: () => true,
      );

      final failure = await controller.softDelete('transfer-1');

      expect(failure, isNull);
      expect(repository.deleteCalls, 1);
      expect(repository.deletedId, 'transfer-1');
    });
  });
}
