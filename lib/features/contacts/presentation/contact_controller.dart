import '../../../core/errors/failure.dart';
import '../domain/contact.dart';
import '../domain/contact_repository.dart';

/// عمليات الكتابة على جهات الاتصال مع التحقق من صلاحية التفعيل.
class ContactController {
  const ContactController({
    required ContactRepository repository,
    required bool Function() canWrite,
  })  : _repository = repository,
        _canWrite = canWrite;

  final ContactRepository _repository;
  final bool Function() _canWrite;

  Future<Failure?> create(Contact contact) async {
    final failure = _permissionFailure();
    if (failure != null) return failure;

    final result = await _repository.create(contact);
    return result.failureOrNull;
  }

  Future<Failure?> update(Contact contact) async {
    final failure = _permissionFailure();
    if (failure != null) return failure;

    final result = await _repository.update(contact);
    return result.failureOrNull;
  }

  Future<Failure?> softDelete(String id) async {
    final failure = _permissionFailure();
    if (failure != null) return failure;

    final result = await _repository.softDelete(id);
    return result.failureOrNull;
  }

  Failure? _permissionFailure() {
    if (_canWrite()) return null;

    return const ActivationFailure(
      'انتهى التفعيل. يمكنك قراءة البيانات وتصديرها فقط.',
      reason: ActivationFailureReason.expired,
    );
  }
}
