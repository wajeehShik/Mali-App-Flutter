import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/inventory/domain/inventory_balance.dart';
import 'package:mali/features/products/domain/product.dart';

void main() {
  group('InventoryCalculator', () {
    test('يضيف المشتريات ويطرح المبيعات بوحدات الألف', () {
      const movements = [
        InventoryMovement(
          type: InventoryMovementType.purchase,
          quantityMilli: 5000,
        ),
        InventoryMovement(
          type: InventoryMovementType.sale,
          quantityMilli: 1250,
        ),
      ];

      expect(InventoryCalculator.calculate(movements), 3750);
    });

    test('لا تؤثر الحركات غير المرتبطة بالمخزون على الرصيد', () {
      const movements = [
        InventoryMovement(
          type: InventoryMovementType.purchase,
          quantityMilli: 2000,
        ),
        InventoryMovement(
          type: InventoryMovementType.other,
          quantityMilli: 9000,
        ),
      ];

      expect(InventoryCalculator.calculate(movements), 2000);
    });

    test('يسمح برصيد سالب إذا تجاوزت المبيعات المشتريات', () {
      const movements = [
        InventoryMovement(
          type: InventoryMovementType.sale,
          quantityMilli: 1500,
        ),
      ];

      expect(InventoryCalculator.calculate(movements), -1500);
    });
  });

  test('يحدد أن الرصيد بلغ حد التنبيه', () {
    const balance = InventoryBalance(
      product: Product(
        id: 'product-1',
        name: 'قهوة',
        salePrice: Money(2500),
        minStock: 1500,
      ),
      quantityMilli: 1500,
    );

    expect(balance.isBelowMinimum, isTrue);
  });

  test('لا يعتبر المنتج منخفض المخزون دون حد تنبيه موجب', () {
    const balance = InventoryBalance(
      product: Product(id: 'product-1', name: 'قهوة'),
      quantityMilli: 0,
    );

    expect(balance.isBelowMinimum, isFalse);
  });
}
