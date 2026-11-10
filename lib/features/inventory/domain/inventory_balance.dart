import 'package:flutter/foundation.dart';

import '../../products/domain/product.dart';

/// نوع الحركة المؤثرة على المخزون.
enum InventoryMovementType { purchase, sale, other }

/// حركة كمية من بنود عملية؛ الكمية مخزنة بالألف.
@immutable
final class InventoryMovement {
  const InventoryMovement({
    required this.type,
    required this.quantityMilli,
  });

  final InventoryMovementType type;
  final int quantityMilli;
}

/// رصيد مشتق للعرض فقط، ولا يُخزَّن في قاعدة البيانات.
@immutable
final class InventoryBalance {
  const InventoryBalance({
    required this.product,
    required this.quantityMilli,
  });

  final Product product;
  final int quantityMilli;

  bool get isBelowMinimum =>
      product.minStock > 0 && quantityMilli <= product.minStock;
}

/// يحسب الرصيد من الحركات: الشراء يزيده والبيع ينقصه.
abstract final class InventoryCalculator {
  static int calculate(Iterable<InventoryMovement> movements) {
    var balance = 0;

    for (final movement in movements) {
      switch (movement.type) {
        case InventoryMovementType.purchase:
          balance += movement.quantityMilli;
          break;
        case InventoryMovementType.sale:
          balance -= movement.quantityMilli;
          break;
        case InventoryMovementType.other:
          break;
      }
    }

    return balance;
  }
}
