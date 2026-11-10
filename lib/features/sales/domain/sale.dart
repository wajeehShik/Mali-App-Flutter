import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';

/// عملية بيع مرتبطة بحساب، ويمكن ربطها بعميل.
@immutable
final class Sale {
  const Sale({
    required this.id,
    required this.date,
    required this.accountId,
    required this.total,
    required this.paidAmount,
    required this.items,
    this.customerId,
    this.note,
  });

  final String id;
  final DateTime date;
  final String accountId;
  final String? customerId;
  final Money total;
  final Money paidAmount;
  final String? note;
  final List<SaleItem> items;

  /// المبلغ المتبقي على العميل.
  Money get remainingAmount => total - paidAmount;

  Sale copyWith({
    String? id,
    DateTime? date,
    String? accountId,
    String? customerId,
    Money? total,
    Money? paidAmount,
    String? note,
    List<SaleItem>? items,
    bool clearCustomerId = false,
    bool clearNote = false,
  }) {
    return Sale(
      id: id ?? this.id,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      total: total ?? this.total,
      paidAmount: paidAmount ?? this.paidAmount,
      note: clearNote ? null : (note ?? this.note),
      items: items ?? this.items,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Sale &&
      other.id == id &&
      other.date == date &&
      other.accountId == accountId &&
      other.customerId == customerId &&
      other.total == total &&
      other.paidAmount == paidAmount &&
      other.note == note &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(
        id,
        date,
        accountId,
        customerId,
        total,
        paidAmount,
        note,
        Object.hashAll(items),
      );

  @override
  String toString() => 'Sale($id, $total, paid: $paidAmount)';
}

/// بند في فاتورة البيع.
/// الكمية بالألف: 1500 تعني 1.5 وحدة.
@immutable
final class SaleItem {
  const SaleItem({
    required this.productId,
    required this.quantityMilli,
    required this.unitPrice,
    required this.unitCost,
  });

  final String productId;
  final int quantityMilli;

  /// سعر الوحدة وقت البيع، بأصغر وحدة نقدية.
  final Money unitPrice;

  /// تكلفة الوحدة المحفوظة وقت البيع لحساب الربح لاحقًا.
  final Money unitCost;

  /// إجمالي البند، محسوب بأعداد صحيحة مع التقريب لأقرب وحدة نقدية.
  Money get lineTotal {
    final numerator = unitPrice.minor * quantityMilli;
    final roundedMagnitude = (numerator.abs() + 500) ~/ 1000;
    return Money(numerator < 0 ? -roundedMagnitude : roundedMagnitude);
  }

  @override
  bool operator ==(Object other) =>
      other is SaleItem &&
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
  String toString() => 'SaleItem($productId, $quantityMilli, $unitPrice)';
}
