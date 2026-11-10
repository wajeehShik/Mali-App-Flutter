import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/accounts/domain/account.dart';
import 'package:mali/features/accounts/domain/account_repository.dart';
import 'package:mali/features/accounts/presentation/account_controller.dart';

class _FakeAccountRepository implements AccountRepository {
  int createCalls = 0;
  Account? createdAccount;

  @override
  Stream<List<Account>> watchActive() => const Stream.empty();

  @override
  Future<Result<List<Account>>> getAll() async => const Ok([]);

  @override
  Future<Result<Account?>> getById(String id) async => const Ok(null);

  @override
  Future<Result<void>> create(Account account) async {
    createCalls += 1;
    createdAccount = account;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> update(Account account) async => const Ok<void>(null);

  @override
  Future<Result<void>> archive(String id) async => const Ok<void>(null);

  @override
  Future<Result<void>> softDelete(String id) async => const Ok<void>(null);

  @override
  Future<Result<Money>> getBalance(String id) async => const Ok(Money.zero);
}

void main() {
  const account = Account(
    id: 'cash-1',
    name: 'الصندوق',
    type: AccountType.cash,
  );

  group('AccountController', () {
    test('يمنع إنشاء حساب عندما لا توجد صلاحية كتابة', () async {
      final repository = _FakeAccountRepository();
      final controller = AccountController(
        repository: repository,
        canWrite: () => false,
      );

      final failure = await controller.create(account);

      expect(failure, isA<ActivationFailure>());
      expect(
        (failure! as ActivationFailure).reason,
        ActivationFailureReason.expired,
      );
      expect(repository.createCalls, 0);
      expect(repository.createdAccount, isNull);
    });

    test('ينشئ الحساب عبر المستودع عندما تكون الكتابة مسموحة', () async {
      final repository = _FakeAccountRepository();
      final controller = AccountController(
        repository: repository,
        canWrite: () => true,
      );

      final failure = await controller.create(account);

      expect(failure, isNull);
      expect(repository.createCalls, 1);
      expect(repository.createdAccount, account);
    });
  });
}
