import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/features/contacts/domain/contact.dart';
import 'package:mali/features/contacts/domain/contact_repository.dart';
import 'package:mali/features/contacts/presentation/contact_controller.dart';

class _FakeContactRepository implements ContactRepository {
  int createCalls = 0;

  @override
  Stream<List<Contact>> watchCustomers() => const Stream.empty();

  @override
  Stream<List<Contact>> watchSuppliers() => const Stream.empty();

  @override
  Future<Result<List<Contact>>> getAll() async => const Ok([]);

  @override
  Future<Result<List<Contact>>> search(String query) async => const Ok([]);

  @override
  Future<Result<Contact?>> getById(String id) async => const Ok(null);

  @override
  Future<Result<void>> create(Contact contact) async {
    createCalls++;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> update(Contact contact) async => const Ok<void>(null);

  @override
  Future<Result<void>> softDelete(String id) async => const Ok<void>(null);
}

void main() {
  const contact = Contact(
    id: 'contact-1',
    name: 'أحمد',
    kind: ContactKind.customer,
  );

  test('يمنع إنشاء جهة عند انتهاء التفعيل', () async {
    final repository = _FakeContactRepository();
    final controller = ContactController(
      repository: repository,
      canWrite: () => false,
    );

    final failure = await controller.create(contact);

    expect(failure, isA<ActivationFailure>());
    expect(
      (failure! as ActivationFailure).reason,
      ActivationFailureReason.expired,
    );
    expect(repository.createCalls, 0);
  });

  test('يمرر الإنشاء إلى المستودع عندما تكون الكتابة مسموحة', () async {
    final repository = _FakeContactRepository();
    final controller = ContactController(
      repository: repository,
      canWrite: () => true,
    );

    final failure = await controller.create(contact);

    expect(failure, isNull);
    expect(repository.createCalls, 1);
  });
}
