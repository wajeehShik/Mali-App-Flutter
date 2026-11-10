import 'package:flutter/foundation.dart';

/// يحدد مجال استخدام التصنيف.
enum CategoryKind {
  income,
  expense,
  product,
}

@immutable
final class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
  });

  final String id;
  final String name;
  final CategoryKind kind;

  Category copyWith({
    String? id,
    String? name,
    CategoryKind? kind,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Category && other.id == id && other.name == name && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, name, kind);

  @override
  String toString() => 'Category($id, $name, $kind)';
}
