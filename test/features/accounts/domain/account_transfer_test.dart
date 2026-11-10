import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/accounts/domain/account_transfer.dart';

void main() {
  final date = DateTime.utc(2026, 11, 9, 10);

  final transfer = AccountTransfer(
    id: 'transfer-1',
    fromAccountId: 'cash-1',
    toAccountId: 'bank-1',
    amount: const Money(2500),
    date: date,
    note: 'إيداع',
  );

  group('AccountTransfer', () {
    test('يحفظ تفاصيل التحويل', () {
      expect(transfer.id, 'transfer-1');
      expect(transfer.fromAccountId, 'cash-1');
      expect(transfer.toAccountId, 'bank-1');
      expect(transfer.amount, const Money(2500));
      expect(transfer.date, date);
      expect(transfer.note, 'إيداع');
    });

    test('copyWith يغير الحقول المطلوبة ويحافظ على الباقي', () {
      final updated = transfer.copyWith(
        amount: const Money(4000),
        note: 'إيداع معدّل',
      );

      expect(updated.id, transfer.id);
      expect(updated.fromAccountId, transfer.fromAccountId);
      expect(updated.toAccountId, transfer.toAccountId);
      expect(updated.amount, const Money(4000));
      expect(updated.date, transfer.date);
      expect(updated.note, 'إيداع معدّل');
    });

    test('copyWith يمسح الملاحظة عند طلب ذلك', () {
      final updated = transfer.copyWith(clearNote: true);

      expect(updated.note, isNull);
      expect(updated.amount, transfer.amount);
    });

    test('القيم المتطابقة متساوية ولها hashCode متساوٍ', () {
      final sameTransfer = AccountTransfer(
        id: 'transfer-1',
        fromAccountId: 'cash-1',
        toAccountId: 'bank-1',
        amount: const Money(2500),
        date: date,
        note: 'إيداع',
      );

      expect(transfer, sameTransfer);
      expect(transfer.hashCode, sameTransfer.hashCode);
    });

    test('التحويلات المختلفة غير متساوية', () {
      final differentTransfer = transfer.copyWith(id: 'transfer-2');

      expect(transfer, isNot(differentTransfer));
    });
  });
}
