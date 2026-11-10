import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';

/// نوع الحساب المالي.
enum AccountType {
  cash,
  bank,
  wallet,
}

/// نموذج الحساب في طبقة المجال.
///
/// الرصيد الحالي لا يُخزَّن في الحساب؛ يُحسب لاحقًا من
/// [openingBalance] والعمليات المرتبطة به.
@immutable
final class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    this.openingBalance = Money.zero,
    this.currency = 'ILS',
    this.isArchived = false,
  });

  /// المعرّف المحلي للحساب (UUID).
  final String id;

  /// اسم الحساب.
  final String name;

  final AccountType type;

  /// الرصيد الافتتاحي بأصغر وحدة نقدية.
  final Money openingBalance;

  /// رمز العملة، والافتراضي شيكل.
  final String currency;

  /// الحساب المؤرشف لا يظهر ضمن الحسابات النشطة.
  final bool isArchived;

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    Money? openingBalance,
    String? currency,
    bool? isArchived,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      currency: currency ?? this.currency,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.openingBalance == openingBalance &&
      other.currency == currency &&
      other.isArchived == isArchived;

  @override
  int get hashCode =>
      Object.hash(id, name, type, openingBalance, currency, isArchived);

  @override
  String toString() => 'Account($id, $name, $type)';
}
