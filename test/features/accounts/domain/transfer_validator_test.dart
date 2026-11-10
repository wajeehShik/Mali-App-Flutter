import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/accounts/domain/account_transfer.dart';
import 'package:mali/features/accounts/domain/transfer_validator.dart';

void main() {
  final date = DateTime.utc(2026, 11, 9, 12);

  AccountTransfer makeTransfer({
    String id = 'transfer-1',
    String fromAccountId = 'cash-1',
    String toAccountId = 'bank-1',
    Money amount = const Money(1000),
    String? note,
  }) {
    return AccountTransfer(
      id: id,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: amount,
      date: date,
      note: note,
    );
  }

  group('TransferValidator', () {
    test('يقبل تحويلًا صحيحًا', () {
      expect(TransferValidator.validate(makeTransfer()), isNull);
    });

    test('يرفض معرّف التحويل الفارغ', () {
      final failure = TransferValidator.validate(makeTransfer(id: ''));

      expect(failure, isA<ValidationFailure>());
      expect(
        (failure! as ValidationFailure).fieldErrors['id'],
        'معرّف التحويل مطلوب.',
      );
    });

    test('يرفض حساب المصدر الفارغ', () {
      final failure =
          TransferValidator.validate(makeTransfer(fromAccountId: ' '));

      expect(failure, isA<ValidationFailure>());
      expect(
        (failure! as ValidationFailure).fieldErrors['fromAccountId'],
        'حساب المصدر مطلوب.',
      );
    });

    test('يرفض حساب الوجهة الفارغ', () {
      final failure =
          TransferValidator.validate(makeTransfer(toAccountId: ' '));

      expect(failure, isA<ValidationFailure>());
      expect(
        (failure! as ValidationFailure).fieldErrors['toAccountId'],
        'حساب الوجهة مطلوب.',
      );
    });

    test('يرفض تحويل الحساب إلى نفسه', () {
      final failure = TransferValidator.validate(
        makeTransfer(fromAccountId: 'cash-1', toAccountId: 'cash-1'),
      );

      expect(failure, isA<ValidationFailure>());
      expect(
        (failure! as ValidationFailure).fieldErrors['toAccountId'],
        'يجب أن يختلف حساب الوجهة عن حساب المصدر.',
      );
    });

    test('يرفض مبلغًا يساوي صفرًا أو سالبًا', () {
      for (final amount in [Money.zero, const Money(-1)]) {
        final failure = TransferValidator.validate(
          makeTransfer(amount: amount),
        );

        expect(failure, isA<ValidationFailure>());
        expect(
          (failure! as ValidationFailure).fieldErrors['amount'],
          'مبلغ التحويل يجب أن يكون أكبر من صفر.',
        );
      }
    });

    test('يرفض ملاحظة تتجاوز 500 حرف', () {
      final failure = TransferValidator.validate(
        makeTransfer(note: 'أ' * 501),
      );

      expect(failure, isA<ValidationFailure>());
      expect(
        (failure! as ValidationFailure).fieldErrors['note'],
        'ملاحظة التحويل طويلة جدًا.',
      );
    });
  });
}
