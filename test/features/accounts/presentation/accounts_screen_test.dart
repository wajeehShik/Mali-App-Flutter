import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/accounts/domain/account.dart';
import 'package:mali/features/accounts/domain/account_repository.dart';
import 'package:mali/features/accounts/presentation/account_providers.dart';
import 'package:mali/features/accounts/presentation/accounts_screen.dart';

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository(this.accounts);

  final List<Account> accounts;

  @override
  Stream<List<Account>> watchActive() => Stream.value(accounts);

  @override
  Future<Result<List<Account>>> getAll() async => Ok(accounts);

  @override
  Future<Result<Account?>> getById(String id) async {
    for (final account in accounts) {
      if (account.id == id) return Ok(account);
    }
    return const Ok(null);
  }

  @override
  Future<Result<void>> create(Account account) async => const Ok<void>(null);

  @override
  Future<Result<void>> update(Account account) async => const Ok<void>(null);

  @override
  Future<Result<void>> archive(String id) async => const Ok<void>(null);

  @override
  Future<Result<void>> softDelete(String id) async => const Ok<void>(null);

  @override
  Future<Result<Money>> getBalance(String id) async =>
      const Ok(Money(12345));
}

void main() {
  testWidgets('يعرض الحساب ونوعه ورصيده', (tester) async {
    const account = Account(
      id: 'cash-1',
      name: 'الصندوق الرئيسي',
      type: AccountType.cash,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(
            _FakeAccountRepository([account]),
          ),
        ],
        child: const MaterialApp(
          home: AccountsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الحسابات'), findsOneWidget);
    expect(find.text('الصندوق الرئيسي'), findsOneWidget);
    expect(find.text('نقدي'), findsOneWidget);
    expect(find.textContaining('123.45'), findsOneWidget);
  });
}
