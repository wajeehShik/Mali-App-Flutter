import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';

/// عملية شراء مرتبطة بحساب، ويمكن ربطها بمورد.
@immutable
final class Purchase {
  const Purchase({
    required this.id,
    required this.date,
    required this.accountId,
    required this.total,
    required this.paidAmount,
    required this.items,
    this.supplierId,
    this.note,
  });

  final String id;
  final DateTime date;
  final String accountId;
  final String? supplierId;
  final Money total;
  final Money paidAmount;
  final String? note;
  final List<PurchaseItem> items;

  Money get remainingAmount => total - paidAmount;

  Purchase copyWith({
    String? id,
    DateTime? date,
    String? accountId,
    String? supplierId,
    Money? total,
    Money? paidAmount,
    String? note,
    List<PurchaseItem>? items,
    bool clearSupplierId = false,
    bool clearNote = false,
  }) {
    return Purchase(
      id: id ?? this.id,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
      supplierId: clearSupplierId ? null : (supplierId ?? this.supplierId),
      total: total ?? this.total,
      paidAmount: paidAmount ?? this.paidAmount,
      note: clearNote ? null : (note ?? this.note),
      items: items ?? this.items,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Purchase &&
      other.id == id &&
      other.date == date &&
      other.accountId == accountId &&
      other.supplierId == supplierId &&
      other.total == total &&
      other.paidAmount == paidAmount &&
      other.note == note &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(
        id,
        date,
        accountId,
        supplierId,
        total,
        paidAmount,
        note,
        Object.hashAll(items),
      );

  @override
  String toString() => 'Purchase($id, $total, paid: $paidAmount)';
}

/// بند من بنود فاتورة الشراء.
/// الكمية بالألف: 1500 تعني 1.5 وحدة.
@immutable
final class PurchaseItem {
  const PurchaseItem({
    required this.productId,
    required this.quantityMilli,
    required this.unitPrice,
    this.unitCost = Money.zero,
  });

  final String productId;
  final int quantityMilli;

  /// سعر الوحدة في عملية الشراء، بأصغر وحدة نقدية.
  final Money unitPrice;

  /// تكلفة الوحدة المحفوظة وقت الشراء.
  final Money unitCost;

  /// إجمالي البند، محسوب بأعداد صحيحة وبالتقريب إلى أصغر وحدة نقدية.
  Money get lineTotal {
    final numerator = unitPrice.minor * quantityMilli;
    final roundedMagnitude = (numerator.abs() + 500) ~/ 1000;
    return Money(numerator < 0 ? -roundedMagnitude : roundedMagnitude);
  }

  @override
  bool operator ==(Object other) =>
      other is PurchaseItem &&
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
  String toString() => 'PurchaseItem($productId, $quantityMilli, $unitPrice)';
}
