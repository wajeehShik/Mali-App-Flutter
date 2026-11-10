import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';

/// منتج؛ كمية المخزون الفعلية تُحسب من العمليات ولا تُخزّن هنا.
@immutable
final class Product {
  const Product({
    required this.id,
    required this.name,
    this.categoryId,
    this.barcode,
    this.unit = 'قطعة',
    this.salePrice = Money.zero,
    this.costPrice = Money.zero,
    this.minStock = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? categoryId;
  final String? barcode;
  final String unit;
  final Money salePrice;
  final Money costPrice;

  /// حد المخزون بالألف؛ 1500 تعني 1.5 وحدة.
  final int minStock;

  final bool isActive;

  Product copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? barcode,
    String? unit,
    Money? salePrice,
    Money? costPrice,
    int? minStock,
    bool? isActive,
    bool clearCategoryId = false,
    bool clearBarcode = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      unit: unit ?? this.unit,
      salePrice: salePrice ?? this.salePrice,
      costPrice: costPrice ?? this.costPrice,
      minStock: minStock ?? this.minStock,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Product &&
      other.id == id &&
      other.name == name &&
      other.categoryId == categoryId &&
      other.barcode == barcode &&
      other.unit == unit &&
      other.salePrice == salePrice &&
      other.costPrice == costPrice &&
      other.minStock == minStock &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        categoryId,
        barcode,
        unit,
        salePrice,
        costPrice,
        minStock,
        isActive,
      );

  @override
  String toString() => 'Product($id, $name, $salePrice)';
}
