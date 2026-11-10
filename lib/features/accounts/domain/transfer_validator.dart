import '../../../core/errors/failure.dart';
import 'account_transfer.dart';

/// يتحقق من سلامة بيانات التحويل قبل تمريرها إلى المستودع.
final class TransferValidator {
  const TransferValidator._();

  static Failure? validate(AccountTransfer transfer) {
    final errors = <String, String>{};

    if (transfer.id.trim().isEmpty) {
      errors['id'] = 'معرّف التحويل مطلوب.';
    }

    if (transfer.fromAccountId.trim().isEmpty) {
      errors['fromAccountId'] = 'حساب المصدر مطلوب.';
    }

    if (transfer.toAccountId.trim().isEmpty) {
      errors['toAccountId'] = 'حساب الوجهة مطلوب.';
    } else if (transfer.toAccountId == transfer.fromAccountId) {
      errors['toAccountId'] = 'يجب أن يختلف حساب الوجهة عن حساب المصدر.';
    }

    if (transfer.amount.minor <= 0) {
      errors['amount'] = 'مبلغ التحويل يجب أن يكون أكبر من صفر.';
    }

    final note = transfer.note;
    if (note != null && note.length > 500) {
      errors['note'] = 'ملاحظة التحويل طويلة جدًا.';
    }

    if (errors.isEmpty) return null;

    return ValidationFailure(
      'تحقق من بيانات التحويل.',
      fieldErrors: errors,
    );
  }
}
