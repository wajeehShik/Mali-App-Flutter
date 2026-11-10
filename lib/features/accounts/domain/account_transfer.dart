import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';

/// طلب تحويل مبلغ من حساب إلى حساب آخر.
///
/// المبلغ موجب دائمًا؛ اتجاه التحويل يتحدد بحسابي المصدر والوجهة.
/// تاريخ العملية هو تاريخها المحاسبي، وليس وقت إنشاء سجل قاعدة البيانات.
@immutable
final class AccountTransfer {
  const AccountTransfer({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.date,
    this.note,
  });

  /// معرّف العملية المحلي (UUID).
  final String id;

  final String fromAccountId;
  final String toAccountId;

  /// مبلغ التحويل بأصغر وحدة نقدية.
  final Money amount;

  /// تاريخ التحويل.
  final DateTime date;

  final String? note;

  AccountTransfer copyWith({
    String? id,
    String? fromAccountId,
    String? toAccountId,
    Money? amount,
    DateTime? date,
    String? note,
    bool clearNote = false,
  }) {
    return AccountTransfer(
      id: id ?? this.id,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AccountTransfer &&
      other.id == id &&
      other.fromAccountId == fromAccountId &&
      other.toAccountId == toAccountId &&
      other.amount == amount &&
      other.date == date &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(id, fromAccountId, toAccountId, amount, date, note);

  @override
  String toString() =>
      'AccountTransfer($id, $fromAccountId -> $toAccountId, $amount)';
}
