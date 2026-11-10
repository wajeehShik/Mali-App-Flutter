import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/features/contacts/domain/contact.dart';
import 'package:mali/features/contacts/domain/contact_repository.dart';
import 'package:mali/features/contacts/presentation/contact_controller.dart';
import 'package:mali/features/contacts/presentation/contact_providers.dart';
import 'package:mali/features/contacts/presentation/contacts_screen.dart';

class _FakeContactRepository implements ContactRepository {
  static const customer = Contact(
    id: 'customer-1',
    name: 'عميل تجريبي',
    kind: ContactKind.customer,
    phone: '0599000001',
  );

  static const supplier = Contact(
    id: 'supplier-1',
    name: 'مورد تجريبي',
    kind: ContactKind.supplier,
    phone: '0599000002',
  );

  Contact? createdContact;

  @override
  Stream<List<Contact>> watchCustomers() => Stream.value([customer]);

  @override
  Stream<List<Contact>> watchSuppliers() => Stream.value([supplier]);

  @override
  Future<Result<List<Contact>>> getAll() async =>
      const Ok([customer, supplier]);

  @override
  Future<Result<List<Contact>>> search(String query) async => const Ok([]);

  @override
  Future<Result<Contact?>> getById(String id) async => const Ok(null);

  @override
  Future<Result<void>> create(Contact contact) async {
    createdContact = contact;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> update(Contact contact) async => const Ok<void>(null);

  @override
  Future<Result<void>> softDelete(String id) async => const Ok<void>(null);
}

void main() {
  late _FakeContactRepository repository;

  Future<void> pumpScreen(WidgetTester tester) async {
    repository = _FakeContactRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contactRepositoryProvider.overrideWithValue(repository),
          contactControllerProvider.overrideWithValue(
            ContactController(
              repository: repository,
              canWrite: () => true,
            ),
          ),
        ],
        child: const MaterialApp(home: ContactsScreen()),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('يعرض تبويبي العملاء والموردين وبياناتهما', (tester) async {
    await pumpScreen(tester);

    expect(find.text('العملاء والموردون'), findsOneWidget);
    expect(find.text('العملاء'), findsOneWidget);
    expect(find.text('الموردون'), findsOneWidget);
    expect(find.text('عميل تجريبي'), findsOneWidget);

    await tester.tap(find.text('الموردون'));
    await tester.pumpAndSettle();

    expect(find.text('مورد تجريبي'), findsOneWidget);
  });

  testWidgets('ينشئ جهة اتصال من النموذج', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('إضافة جهة'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'عميل جديد');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(repository.createdContact, isNotNull);
    expect(repository.createdContact!.name, 'عميل جديد');
    expect(repository.createdContact!.kind, ContactKind.customer);
  });
}
