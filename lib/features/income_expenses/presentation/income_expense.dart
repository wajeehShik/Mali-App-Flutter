import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';

/// نوع الحركة المالية غير المرتبطة ببنود البيع أو الشراء.
enum IncomeExpenseType {
  income,
  expense,
}

/// إيراد أو مصروف محفوظ كعملية مالية.
@immutable
final class IncomeExpense {
  const IncomeExpense({
    required this.id,
    required this.type,
    required this.date,
    required this.accountId,
    required this.amount,
    this.categoryId,
    this.note,
  });

  final String id;
  final IncomeExpenseType type;
  final DateTime date;
  final String accountId;
  final Money amount;
  final String? categoryId;
  final String? note;

  IncomeExpense copyWith({
    String? id,
    IncomeExpenseType? type,
    DateTime? date,
    String? accountId,
    Money? amount,
    String? categoryId,
    String? note,
    bool clearCategoryId = false,
    bool clearNote = false,
  }) {
    return IncomeExpense(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      note: clearNote ? null : (note ?? this.note),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IncomeExpense &&
      other.id == id &&
      other.type == type &&
      other.date == date &&
      other.accountId == accountId &&
      other.amount == amount &&
      other.categoryId == categoryId &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
        id,
        type,
        date,
        accountId,
        amount,
        categoryId,
        note,
      );

  @override
  String toString() => 'IncomeExpense($id, $type, $amount)';
}
