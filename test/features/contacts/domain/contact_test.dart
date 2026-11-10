import 'package:flutter_test/flutter_test.dart';
import 'package:mali/features/contacts/domain/contact.dart';

void main() {
  const contact = Contact(
    id: 'contact-1',
    name: 'أحمد',
    kind: ContactKind.customer,
    phone: '0599123456',
    note: 'عميل دائم',
  );

  group('Contact', () {
    test('يحفظ بيانات جهة الاتصال', () {
      expect(contact.id, 'contact-1');
      expect(contact.name, 'أحمد');
      expect(contact.kind, ContactKind.customer);
      expect(contact.phone, '0599123456');
      expect(contact.note, 'عميل دائم');
    });

    test('copyWith يغيّر الحقول المحددة ويحافظ على الباقي', () {
      final updated = contact.copyWith(
        name: 'أحمد علي',
        kind: ContactKind.both,
      );

      expect(updated.id, contact.id);
      expect(updated.name, 'أحمد علي');
      expect(updated.kind, ContactKind.both);
      expect(updated.phone, contact.phone);
      expect(updated.note, contact.note);
    });

    test('copyWith يمسح الهاتف والملاحظة عند طلب ذلك', () {
      final updated = contact.copyWith(clearPhone: true, clearNote: true);

      expect(updated.phone, isNull);
      expect(updated.note, isNull);
      expect(updated.id, contact.id);
      expect(updated.name, contact.name);
    });

    test('القيم المتطابقة متساوية ولها hashCode متساوٍ', () {
      const sameContact = Contact(
        id: 'contact-1',
        name: 'أحمد',
        kind: ContactKind.customer,
        phone: '0599123456',
        note: 'عميل دائم',
      );

      expect(contact, sameContact);
      expect(contact.hashCode, sameContact.hashCode);
    });

    test('الجهات المختلفة غير متساوية', () {
      final differentContact = contact.copyWith(id: 'contact-2');

      expect(contact, isNot(differentContact));
    });
  });
}
