import 'package:flutter_test/flutter_test.dart';
import 'package:mali/features/categories/domain/category.dart';

void main() {
  const category = Category(
    id: 'category-1',
    name: 'مبيعات',
    kind: CategoryKind.income,
  );

  test('يحفظ بيانات التصنيف', () {
    expect(category.id, 'category-1');
    expect(category.name, 'مبيعات');
    expect(category.kind, CategoryKind.income);
  });

  test('copyWith يغيّر الحقول المحددة ويحافظ على الباقي', () {
    final updated = category.copyWith(
      name: 'مبيعات المنتجات',
      kind: CategoryKind.product,
    );

    expect(updated.id, category.id);
    expect(updated.name, 'مبيعات المنتجات');
    expect(updated.kind, CategoryKind.product);
  });

  test('التصنيفات المتطابقة متساوية', () {
    const sameCategory = Category(
      id: 'category-1',
      name: 'مبيعات',
      kind: CategoryKind.income,
    );

    expect(category, sameCategory);
    expect(category.hashCode, sameCategory.hashCode);
  });
}
