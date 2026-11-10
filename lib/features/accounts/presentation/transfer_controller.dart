import '../../../core/errors/failure.dart';
import '../domain/account_transfer.dart';
import '../domain/transfer_repository.dart';

/// عمليات إنشاء وحذف التحويلات مع التحقق من صلاحية الكتابة.
class TransferController {
  const TransferController({
    required TransferRepository repository,
    required bool Function() canWrite,
  })  : _repository = repository,
        _canWrite = canWrite;

  final TransferRepository _repository;
  final bool Function() _canWrite;

  Future<Failure?> create(AccountTransfer transfer) async {
    final permissionFailure = _permissionFailure();
    if (permissionFailure != null) return permissionFailure;

    final result = await _repository.createTransfer(transfer);
    return result.failureOrNull;
  }

  Future<Failure?> softDelete(String id) async {
    final permissionFailure = _permissionFailure();
    if (permissionFailure != null) return permissionFailure;

    final result = await _repository.softDeleteTransfer(id);
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
