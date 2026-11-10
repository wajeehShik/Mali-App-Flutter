import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/debts/domain/debt_balance.dart';

void main() {
  group('DebtCalculator', () {
    test('يحسب رصيد العميل ويخصم سداد الدين الوارد', () {
      final balances = DebtCalculator.calculate([
        const DebtMovement(
          contactId: 'customer-1',
          type: DebtMovementType.sale,
          total: Money(10000),
          paidAmount: Money(3000),
        ),
        const DebtMovement(
          contactId: 'customer-1',
          type: DebtMovementType.debtIn,
          total: Money(2000),
          paidAmount: Money(2000),
        ),
      ]);

      expect(balances, hasLength(1));
      expect(balances.single.contactId, 'customer-1');
      expect(balances.single.direction, DebtDirection.receivable);
      expect(balances.single.amount, const Money(5000));
      expect(balances.single.isSettled, isFalse);
    });

    test('يحسب رصيد المورد ويخصم سداد الدين الصادر', () {
      final balances = DebtCalculator.calculate([
        const DebtMovement(
          contactId: 'supplier-1',
          type: DebtMovementType.purchase,
          total: Money(8000),
          paidAmount: Money(1000),
        ),
        const DebtMovement(
          contactId: 'supplier-1',
          type: DebtMovementType.debtOut,
          total: Money(1500),
          paidAmount: Money(1500),
        ),
      ]);

      expect(balances, hasLength(1));
      expect(balances.single.contactId, 'supplier-1');
      expect(balances.single.direction, DebtDirection.payable);
      expect(balances.single.amount, const Money(5500));
    });

    test('يعيد رصيد العميل صفرًا ويستبعده من النتائج', () {
      final balances = DebtCalculator.calculate([
        const DebtMovement(
          contactId: 'customer-1',
          type: DebtMovementType.sale,
          total: Money(5000),
          paidAmount: Money(3000),
        ),
        const DebtMovement(
          contactId: 'customer-1',
          type: DebtMovementType.debtIn,
          total: Money(2000),
          paidAmount: Money(2000),
        ),
      ]);

      expect(balances, isEmpty);
    });

    test('يتجاهل الحركات التي لا تحمل معرّف جهة اتصال صالحًا', () {
      final balances = DebtCalculator.calculate([
        const DebtMovement(
          contactId: null,
          type: DebtMovementType.sale,
          total: Money(5000),
          paidAmount: Money(0),
        ),
        const DebtMovement(
          contactId: '   ',
          type: DebtMovementType.purchase,
          total: Money(3000),
          paidAmount: Money(0),
        ),
      ]);

      expect(balances, isEmpty);
    });

    test('يعيد نتائج مرتبة حسب الاتجاه ثم معرّف جهة الاتصال', () {
      final balances = DebtCalculator.calculate([
        const DebtMovement(
          contactId: 'supplier-b',
          type: DebtMovementType.purchase,
          total: Money(1000),
          paidAmount: Money(0),
        ),
        const DebtMovement(
          contactId: 'customer-b',
          type: DebtMovementType.sale,
          total: Money(1000),
          paidAmount: Money(0),
        ),
        const DebtMovement(
          contactId: 'customer-a',
          type: DebtMovementType.sale,
          total: Money(1000),
          paidAmount: Money(0),
        ),
      ]);

      expect(
        balances.map((balance) => balance.contactId),
        ['customer-a', 'customer-b', 'supplier-b'],
      );
      expect(
        balances.map((balance) => balance.direction),
        [
          DebtDirection.receivable,
          DebtDirection.receivable,
          DebtDirection.payable,
        ],
      );
    });
  });
}
