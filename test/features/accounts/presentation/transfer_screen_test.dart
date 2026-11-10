import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/accounts/domain/account.dart';
import 'package:mali/features/accounts/domain/account_repository.dart';
import 'package:mali/features/accounts/domain/account_transfer.dart';
import 'package:mali/features/accounts/domain/transfer_repository.dart';
import 'package:mali/features/accounts/presentation/account_providers.dart';
import 'package:mali/features/accounts/presentation/transfer_controller.dart';
import 'package:mali/features/accounts/presentation/transfer_screen.dart';

class _FakeAccountRepository implements AccountRepository {
  @override
  Stream<List<Account>> watchActive() => Stream.value(const [
        Account(id: 'cash-1', name: 'الصندوق', type: AccountType.cash),
        Account(id: 'bank-1', name: 'البنك', type: AccountType.bank),
      ]);

  @override
  Future<Result<List<Account>>> getAll() async => const Ok([]);

  @override
  Future<Result<Account?>> getById(String id) async => const Ok(null);

  @override
  Future<Result<void>> create(Account account) async => const Ok<void>(null);

  @override
  Future<Result<void>> update(Account account) async => const Ok<void>(null);

  @override
  Future<Result<void>> archive(String id) async => const Ok<void>(null);

  @override
  Future<Result<void>> softDelete(String id) async => const Ok<void>(null);

  @override
  Future<Result<Money>> getBalance(String id) async => const Ok(Money.zero);
}

class _FakeTransferRepository implements TransferRepository {
  AccountTransfer? createdTransfer;

  @override
  Future<Result<void>> createTransfer(AccountTransfer transfer) async {
    createdTransfer = transfer;
    return const Ok<void>(null);
  }

  @override
  Future<Result<AccountTransfer?>> getTransferById(String id) async =>
      const Ok(null);

  @override
  Future<Result<void>> softDeleteTransfer(String id) async =>
      const Ok<void>(null);
}

void main() {
  late _FakeTransferRepository transferRepository;

  Future<void> pumpTransferScreen(WidgetTester tester) async {
    transferRepository = _FakeTransferRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(_FakeAccountRepository()),
          transferControllerProvider.overrideWithValue(
            TransferController(
              repository: transferRepository,
              canWrite: () => true,
            ),
          ),
        ],
        child: const MaterialApp(
          home: TransferScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('يعرض حسابي المصدر والوجهة وزر التأكيد', (tester) async {
    await pumpTransferScreen(tester);

    expect(find.text('تحويل بين الحسابات'), findsOneWidget);
    expect(find.text('من الحساب'), findsOneWidget);
    expect(find.text('إلى الحساب'), findsOneWidget);
    expect(find.text('تأكيد التحويل'), findsOneWidget);
    expect(find.textContaining('الصندوق'), findsOneWidget);
    expect(find.textContaining('البنك'), findsOneWidget);
  });

  testWidgets('يرسل التحويل بالمبلغ والحسابين المختارين', (tester) async {
    await pumpTransferScreen(tester);

    await tester.enterText(find.byType(TextFormField).first, '25.00');

    final submitButton = find.text('تأكيد التحويل');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    final transfer = transferRepository.createdTransfer;
    expect(transfer, isNotNull);
    expect(transfer!.fromAccountId, 'cash-1');
    expect(transfer.toAccountId, 'bank-1');
    expect(transfer.amount, const Money(2500));
  });
}
