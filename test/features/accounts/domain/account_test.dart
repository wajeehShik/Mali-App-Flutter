import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/accounts/domain/account.dart';

void main() {
  group('Account', () {
    test('ينشئ حسابًا بالقيم الافتراضية', () {
      const account = Account(
        id: 'account-1',
        name: 'الصندوق',
        type: AccountType.cash,
      );

      expect(account.id, 'account-1');
      expect(account.name, 'الصندوق');
      expect(account.type, AccountType.cash);
      expect(account.openingBalance, Money.zero);
      expect(account.currency, 'ILS');
      expect(account.isArchived, isFalse);
    });

    test('يحفظ الرصيد الافتتاحي والعملة وحالة الأرشفة', () {
      const account = Account(
        id: 'account-2',
        name: 'حساب البنك',
        type: AccountType.bank,
        openingBalance: Money(125050),
        currency: 'ILS',
        isArchived: true,
      );

      expect(account.openingBalance, const Money(125050));
      expect(account.currency, 'ILS');
      expect(account.isArchived, isTrue);
    });

    test('copyWith يغيّر الحقول المحددة ويحافظ على الباقي', () {
      const original = Account(
        id: 'account-3',
        name: 'محفظة',
        type: AccountType.wallet,
        openingBalance: Money(10000),
      );

      final updated = original.copyWith(
        name: 'المحفظة الرئيسية',
        isArchived: true,
      );

      expect(updated.id, original.id);
      expect(updated.name, 'المحفظة الرئيسية');
      expect(updated.type, original.type);
      expect(updated.openingBalance, original.openingBalance);
      expect(updated.currency, original.currency);
      expect(updated.isArchived, isTrue);
    });

    test('الحسابان المتطابقان متساويان ولهما hashCode متساوٍ', () {
      const first = Account(
        id: 'account-4',
        name: 'الصندوق',
        type: AccountType.cash,
        openingBalance: Money(5000),
      );
      const second = Account(
        id: 'account-4',
        name: 'الصندوق',
        type: AccountType.cash,
        openingBalance: Money(5000),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('الحسابان المختلفان غير متساويين', () {
      const first = Account(
        id: 'account-5',
        name: 'الصندوق',
        type: AccountType.cash,
      );
      const second = Account(
        id: 'account-6',
        name: 'الصندوق',
        type: AccountType.cash,
      );

      expect(first, isNot(second));
    });
  });
}
