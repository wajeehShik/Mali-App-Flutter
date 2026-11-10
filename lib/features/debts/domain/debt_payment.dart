import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';
import 'debt_balance.dart';

/// سداد أو تحصيل جزء من دين جهة اتصال.
@immutable
final class DebtPayment {
  const DebtPayment({
    required this.id,
    required this.date,
    required this.accountId,
    required this.contactId,
    required this.direction,
    required this.amount,
    this.note,
  });

  final String id;
  final DateTime date;
  final String accountId;
  final String contactId;

  /// receivable: العميل يسدد لنا.
  /// payable: نسدد للمورد.
  final DebtDirection direction;

  final Money amount;
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is DebtPayment &&
      other.id == id &&
      other.date == date &&
      other.accountId == accountId &&
      other.contactId == contactId &&
      other.direction == direction &&
      other.amount == amount &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
        id,
        date,
        accountId,
        contactId,
        direction,
        amount,
        note,
      );

  @override
  String toString() => 'DebtPayment($id, $direction, $amount)';
}
