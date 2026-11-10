import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';

/// اتجاه الرصيد بين المنشأة وجهة الاتصال.
enum DebtDirection {
  /// عميل مدين للمنشأة.
  receivable,

  /// المنشأة مدينة للمورد.
  payable,
}

/// أنواع الحركات التي تؤثر على رصيد الدين.
enum DebtMovementType {
  sale,
  purchase,
  debtIn,
  debtOut,
}

/// حركة مالية تدخل في حساب الدين.
/// المبالغ تُخزَّن بأصغر وحدة نقدية عبر Money.
@immutable
final class DebtMovement {
  const DebtMovement({
    required this.contactId,
    required this.type,
    required this.total,
    required this.paidAmount,
  });

  final String? contactId;
  final DebtMovementType type;
  final Money total;
  final Money paidAmount;
}

/// رصيد دين مشتق لجهة اتصال، ولا يُخزَّن منفصلًا في قاعدة البيانات.
@immutable
final class DebtBalance {
  const DebtBalance({
    required this.contactId,
    required this.direction,
    required this.amount,
  });

  final String contactId;
  final DebtDirection direction;

  /// موجب يعني دينًا مستحقًا، وسالب يعني رصيدًا دائنًا زائدًا.
  final Money amount;

  bool get isSettled => amount.isZero;

  @override
  bool operator ==(Object other) =>
      other is DebtBalance &&
      other.contactId == contactId &&
      other.direction == direction &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(contactId, direction, amount);

  @override
  String toString() => 'DebtBalance($contactId, $direction, $amount)';
}

/// يحسب أرصدة العملاء والموردين من سجل العمليات.
/// البيع يزيد دين العميل بمقدار غير المدفوع، وdebtIn يخفضه.
/// الشراء يزيد دين المورد بمقدار غير المدفوع، وdebtOut يخفضه.
abstract final class DebtCalculator {
  static List<DebtBalance> calculate(
    Iterable<DebtMovement> movements,
  ) {
    final balances = <String, Map<DebtDirection, int>>{};

    void addAmount(
      String contactId,
      DebtDirection direction,
      int amount,
    ) {
      final byDirection = balances.putIfAbsent(
        contactId,
        () => <DebtDirection, int>{},
      );
      byDirection.update(
        direction,
        (current) => current + amount,
        ifAbsent: () => amount,
      );
    }

    for (final movement in movements) {
      final contactId = movement.contactId?.trim();
      if (contactId == null || contactId.isEmpty) continue;

      switch (movement.type) {
        case DebtMovementType.sale:
          addAmount(
            contactId,
            DebtDirection.receivable,
            movement.total.minor - movement.paidAmount.minor,
          );
        case DebtMovementType.purchase:
          addAmount(
            contactId,
            DebtDirection.payable,
            movement.total.minor - movement.paidAmount.minor,
          );
        case DebtMovementType.debtIn:
          addAmount(
            contactId,
            DebtDirection.receivable,
            -movement.paidAmount.minor,
          );
        case DebtMovementType.debtOut:
          addAmount(
            contactId,
            DebtDirection.payable,
            -movement.paidAmount.minor,
          );
      }
    }

    final result = <DebtBalance>[];

    for (final contactEntry in balances.entries) {
      for (final directionEntry in contactEntry.value.entries) {
        if (directionEntry.value == 0) continue;

        result.add(
          DebtBalance(
            contactId: contactEntry.key,
            direction: directionEntry.key,
            amount: Money(directionEntry.value),
          ),
        );
      }
    }

    result.sort((a, b) {
      final directionOrder = a.direction.index.compareTo(b.direction.index);
      if (directionOrder != 0) return directionOrder;
      return a.contactId.compareTo(b.contactId);
    });

    return List<DebtBalance>.unmodifiable(result);
  }
}
