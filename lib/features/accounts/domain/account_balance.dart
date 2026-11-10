import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';
import 'account.dart';

/// نوع الحركة التي تؤثر على رصيد الحساب.
enum AccountMovementType {
  income,
  expense,
  sale,
  purchase,
  transfer,
  debtIn,
  debtOut,
}

/// بيانات الحركة اللازمة لحساب رصيد حساب واحد.
///
/// [amount] هو المبلغ الذي أثّر فعليًا على الحساب، وليس بالضرورة إجمالي
/// العملية؛ سيحدد مستودع البيانات لاحقًا القيمة المناسبة من سجل العملية.
@immutable
final class AccountMovement {
  const AccountMovement({
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
  });

  final AccountMovementType type;
  final Money amount;

  /// الحساب المصدر، أو الحساب الوحيد للعملية.
  final String accountId;

  /// الحساب الوجهة للتحويل فقط.
  final String? toAccountId;
}

/// يحسب الرصيد من الرصيد الافتتاحي والحركات غير المحذوفة التي يزوّدها المستدعي.
///
/// مسؤولية المستودع لاحقًا أن يمرر الحركات الفعّالة فقط.
Money calculateAccountBalance({
  required Account account,
  required Iterable<AccountMovement> movements,
}) {
  var balance = account.openingBalance;

  for (final movement in movements) {
    switch (movement.type) {
      case AccountMovementType.income:
      case AccountMovementType.sale:
      case AccountMovementType.debtIn:
        if (movement.accountId == account.id) {
          balance += movement.amount;
        }

      case AccountMovementType.expense:
      case AccountMovementType.purchase:
      case AccountMovementType.debtOut:
        if (movement.accountId == account.id) {
          balance -= movement.amount;
        }

      case AccountMovementType.transfer:
        if (movement.accountId == account.id) {
          balance -= movement.amount;
        } else if (movement.toAccountId == account.id) {
          balance += movement.amount;
        }
    }
  }

  return balance;
}
