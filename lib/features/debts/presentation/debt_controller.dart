import '../../../core/errors/failure.dart';
import '../domain/debt_payment.dart';
import '../domain/debt_repository.dart';

/// تسجيل سداد الديون مع التحقق من صلاحية الكتابة.
class DebtController {
  const DebtController({
    required DebtRepository repository,
    required bool Function() canWrite,
  })  : _repository = repository,
        _canWrite = canWrite;

  final DebtRepository _repository;
  final bool Function() _canWrite;

  Future<Failure?> recordPayment(DebtPayment payment) async {
    if (!_canWrite()) {
      return const ActivationFailure(
        'انتهى التفعيل. يمكنك قراءة البيانات وتصديرها فقط.',
        reason: ActivationFailureReason.expired,
      );
    }

    final result = await _repository.recordPayment(payment);
    return result.failureOrNull;
  }
}
