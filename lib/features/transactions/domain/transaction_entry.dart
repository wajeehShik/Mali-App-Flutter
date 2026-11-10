import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';

/// أنواع العمليات التي تظهر في سجل المعاملات.
enum FinancialTransactionType {
  income,
  expense,
  sale,
  purchase,
  transfer,
  debtIn,
  debtOut,
}

/// عملية مالية موحدة للعرض في سجل المعاملات.
@immutable
final class TransactionEntry {
  const TransactionEntry({
    required this.id,
    required this.type,
    required this.date,
    required this.accountId,
    required this.total,
    required this.paidAmount,
    this.toAccountId,
    this.contactId,
    this.categoryId,
    this.note,
    this.items = const [],
  });

  final String id;
  final FinancialTransactionType type;
  final DateTime date;
  final String accountId;

  /// الحساب المستلم في عملية التحويل فقط.
  final String? toAccountId;

  final String? contactId;
  final String? categoryId;
  final Money total;
  final Money paidAmount;
  final String? note;
  final List<TransactionEntryItem> items;

  /// الرصيد المتبقي على العميل أو للمورد في البيع والشراء.
  Money get remainingAmount => total - paidAmount;

  bool get hasItems => items.isNotEmpty;

  TransactionEntry copyWith({
    String? id,
    FinancialTransactionType? type,
    DateTime? date,
    String? accountId,
    String? toAccountId,
    String? contactId,
    String? categoryId,
    Money? total,
    Money? paidAmount,
    String? note,
    List<TransactionEntryItem>? items,
    bool clearToAccountId = false,
    bool clearContactId = false,
    bool clearCategoryId = false,
    bool clearNote = false,
  }) {
    return TransactionEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
      toAccountId:
          clearToAccountId ? null : (toAccountId ?? this.toAccountId),
      contactId: clearContactId ? null : (contactId ?? this.contactId),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      total: total ?? this.total,
      paidAmount: paidAmount ?? this.paidAmount,
      note: clearNote ? null : (note ?? this.note),
      items: items ?? this.items,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TransactionEntry &&
      other.id == id &&
      other.type == type &&
      other.date == date &&
      other.accountId == accountId &&
      other.toAccountId == toAccountId &&
      other.contactId == contactId &&
      other.categoryId == categoryId &&
      other.total == total &&
      other.paidAmount == paidAmount &&
      other.note == note &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(
        id,
        type,
        date,
        accountId,
        toAccountId,
        contactId,
        categoryId,
        total,
        paidAmount,
        note,
        Object.hashAll(items),
      );

  @override
  String toString() => 'TransactionEntry($id, $type, $total)';
}

/// بند منتج في معاملة بيع أو شراء.
/// الكمية بالألف؛ 1500 تعني 1.5 وحدة.
@immutable
final class TransactionEntryItem {
  const TransactionEntryItem({
    required this.productId,
    required this.quantityMilli,
    required this.unitPrice,
    required this.unitCost,
  });

  final String productId;
  final int quantityMilli;
  final Money unitPrice;
  final Money unitCost;

  Money get lineTotal {
    final numerator = unitPrice.minor * quantityMilli;
    final roundedMagnitude = (numerator.abs() + 500) ~/ 1000;
    return Money(numerator < 0 ? -roundedMagnitude : roundedMagnitude);
  }

  @override
  bool operator ==(Object other) =>
      other is TransactionEntryItem &&
      other.productId == productId &&
      other.quantityMilli == quantityMilli &&
      other.unitPrice == unitPrice &&
      other.unitCost == unitCost;

  @override
  int get hashCode => Object.hash(
        productId,
        quantityMilli,
        unitPrice,
        unitCost,
      );

  @override
  String toString() =>
      'TransactionEntryItem($productId, $quantityMilli, $unitPrice)';
}
