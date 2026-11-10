import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/accounts/domain/account.dart';
import 'package:mali/features/accounts/domain/account_balance.dart';

void main() {
  const cashAccount = Account(
    id: 'cash',
    name: 'الصندوق',
    type: AccountType.cash,
    openingBalance: Money(10000),
  );

  group('calculateAccountBalance', () {
    test('يرجع الرصيد الافتتاحي إذا لم توجد حركات', () {
      final balance = calculateAccountBalance(
        account: cashAccount,
        movements: const [],
      );

      expect(balance, const Money(10000));
    });

    test('يضيف الدخل والمبيعات والدين الوارد إلى الحساب', () {
      final balance = calculateAccountBalance(
        account: cashAccount,
        movements: const [
          AccountMovement(
            type: AccountMovementType.income,
            amount: Money(2500),
            accountId: 'cash',
          ),
          AccountMovement(
            type: AccountMovementType.sale,
            amount: Money(1500),
            accountId: 'cash',
          ),
          AccountMovement(
            type: AccountMovementType.debtIn,
            amount: Money(500),
            accountId: 'cash',
          ),
        ],
      );

      expect(balance, const Money(14500));
    });

    test('يطرح المصروف والمشتريات والدين الصادر من الحساب', () {
      final balance = calculateAccountBalance(
        account: cashAccount,
        movements: const [
          AccountMovement(
            type: AccountMovementType.expense,
            amount: Money(1000),
            accountId: 'cash',
          ),
          AccountMovement(
            type: AccountMovementType.purchase,
            amount: Money(2000),
            accountId: 'cash',
          ),
          AccountMovement(
            type: AccountMovementType.debtOut,
            amount: Money(500),
            accountId: 'cash',
          ),
        ],
      );

      expect(balance, const Money(6500));
    });

    test('يطرح التحويل من الحساب المصدر', () {
      final balance = calculateAccountBalance(
        account: cashAccount,
        movements: const [
          AccountMovement(
            type: AccountMovementType.transfer,
            amount: Money(3000),
            accountId: 'cash',
            toAccountId: 'bank',
          ),
        ],
      );

      expect(balance, const Money(7000));
    });

    test('يضيف التحويل إلى الحساب الوجهة', () {
      const bankAccount = Account(
        id: 'bank',
        name: 'البنك',
        type: AccountType.bank,
        openingBalance: Money(2000),
      );

      final balance = calculateAccountBalance(
        account: bankAccount,
        movements: const [
          AccountMovement(
            type: AccountMovementType.transfer,
            amount: Money(3000),
            accountId: 'cash',
            toAccountId: 'bank',
          ),
        ],
      );

      expect(balance, const Money(5000));
    });

    test('يتجاهل الحركات التي تخص حسابات أخرى', () {
      final balance = calculateAccountBalance(
        account: cashAccount,
        movements: const [
          AccountMovement(
            type: AccountMovementType.income,
            amount: Money(8000),
            accountId: 'bank',
          ),
          AccountMovement(
            type: AccountMovementType.transfer,
            amount: Money(1200),
            accountId: 'wallet',
            toAccountId: 'bank',
          ),
        ],
      );

      expect(balance, const Money(10000));
    });
  });
}
