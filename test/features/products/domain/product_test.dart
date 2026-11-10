import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/products/domain/product.dart';

void main() {
  const product = Product(
    id: 'product-1',
    name: 'قهوة',
    categoryId: 'category-1',
    barcode: '123456',
    unit: 'كغ',
    salePrice: Money(2500),
    costPrice: Money(1800),
    minStock: 1500,
  );

  test('يحفظ الأسعار والحقول وحد المخزون بالألف', () {
    expect(product.id, 'product-1');
    expect(product.name, 'قهوة');
    expect(product.categoryId, 'category-1');
    expect(product.barcode, '123456');
    expect(product.unit, 'كغ');
    expect(product.salePrice, const Money(2500));
    expect(product.costPrice, const Money(1800));
    expect(product.minStock, 1500);
    expect(product.isActive, isTrue);
  });

  test('copyWith يعدّل الحقول ويحافظ على الباقي', () {
    final updated = product.copyWith(
      name: 'قهوة عربية',
      salePrice: const Money(2700),
    );

    expect(updated.name, 'قهوة عربية');
    expect(updated.salePrice, const Money(2700));
    expect(updated.costPrice, product.costPrice);
    expect(updated.categoryId, product.categoryId);
    expect(updated.minStock, product.minStock);
  });

  test('copyWith يمسح التصنيف والباركود صراحةً', () {
    final updated = product.copyWith(
      clearCategoryId: true,
      clearBarcode: true,
    );

    expect(updated.categoryId, isNull);
    expect(updated.barcode, isNull);
  });

  test('القيم المتطابقة متساوية', () {
    const sameProduct = Product(
      id: 'product-1',
      name: 'قهوة',
      categoryId: 'category-1',
      barcode: '123456',
      unit: 'كغ',
      salePrice: Money(2500),
      costPrice: Money(1800),
      minStock: 1500,
    );

    expect(product, sameProduct);
    expect(product.hashCode, sameProduct.hashCode);
  });
}
