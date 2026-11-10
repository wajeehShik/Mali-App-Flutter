import 'package:flutter/foundation.dart';

/// يحدد استخدام جهة الاتصال في التطبيق.
enum ContactKind {
  customer,
  supplier,
  both,
}

/// نموذج عميل أو مورد أو جهة تقوم بالدورين.
@immutable
final class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.kind,
    this.phone,
    this.note,
  });

  /// معرّف جهة الاتصال المحلي (UUID).
  final String id;

  final String name;
  final ContactKind kind;
  final String? phone;
  final String? note;

  Contact copyWith({
    String? id,
    String? name,
    ContactKind? kind,
    String? phone,
    String? note,
    bool clearPhone = false,
    bool clearNote = false,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      phone: clearPhone ? null : (phone ?? this.phone),
      note: clearNote ? null : (note ?? this.note),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Contact &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.phone == phone &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, name, kind, phone, note);

  @override
  String toString() => 'Contact($id, $name, $kind)';
}
