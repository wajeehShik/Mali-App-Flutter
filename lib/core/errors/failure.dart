import 'package:flutter/foundation.dart';

/// فشل متوقع في العمليات. كل نوع يحمل رسالة عربية صالحة للعرض للمستخدم.
@immutable
sealed class Failure {
  const Failure(this.message, {this.cause});

  /// رسالة للمستخدم.
  final String message;

  /// الخطأ الأصلي للتشخيص فقط (لا يُعرض في الواجهة).
  final Object? cause;

  @override
  String toString() => '$runtimeType($message)';
}

/// مدخلات غير صالحة. [fieldErrors] تربط اسم الحقل برسالة خطئه.
final class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    this.fieldErrors = const {},
  });

  final Map<String, String> fieldErrors;
}

/// عنصر غير موجود.
final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'العنصر المطلوب غير موجود.']);
}

/// تعارض مع حالة البيانات الحالية (اسم مكرر، رصيد غير كافٍ، حذف عنصر مرتبط...).
final class ConflictFailure extends Failure {
  const ConflictFailure(super.message);
}

/// خطأ في قاعدة البيانات المحلية.
final class DatabaseFailure extends Failure {
  const DatabaseFailure([
    super.message = 'تعذّر حفظ البيانات أو قراءتها من الجهاز.',
    Object? cause,
  ]) : super(cause: cause);
}

/// خطأ في الاتصال بالخادم أو عدم توفر إنترنت.
final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'تعذّر الاتصال بالخادم. تحقق من الإنترنت وحاول مجددًا.',
    Object? cause,
  ]) : super(cause: cause);
}

/// رفض من الخادم (رمز حالة غير ناجح).
final class ServerFailure extends Failure {
  const ServerFailure(
    super.message, {
    this.statusCode,
    super.cause,
  });

  final int? statusCode;
}

/// مشكلة في التفعيل: غير مفعّل، قيد الانتظار، توقيع غير صالح، جهاز مختلف، منتهي.
final class ActivationFailure extends Failure {
  const ActivationFailure(super.message, {this.reason});

  final ActivationFailureReason? reason;
}

enum ActivationFailureReason {
  notActivated,
  pending,
  rejected,
  invalidSignature,
  deviceMismatch,
  expired,
}

/// خطأ في الملفات: نسخة احتياطية تالفة، صيغة غير مدعومة، فشل الكتابة...
final class FileFailure extends Failure {
  const FileFailure(super.message, {super.cause});
}

/// خطأ غير متوقع.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    super.message = 'حدث خطأ غير متوقع. حاول مرة أخرى.',
    Object? cause,
  ]) : super(cause: cause);
}

/// نتيجة عملية: نجاح [Ok] أو فشل [Err].
@immutable
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  Failure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };

  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) {
    return switch (this) {
      Ok<T>(:final value) => onOk(value),
      Err<T>(:final failure) => onErr(failure),
    };
  }

  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Ok<T>(:final value) => Ok<R>(transform(value)),
      Err<T>(:final failure) => Err<R>(failure),
    };
  }

  /// يعيد القيمة أو يرمي [FailureException]. للاستخدام في الاختبارات والحالات الاستثنائية فقط.
  T unwrap() => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>(:final failure) => throw FailureException(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}

/// استثناء يلف [Failure] حيث يلزم الرمي.
class FailureException implements Exception {
  const FailureException(this.failure);

  final Failure failure;

  @override
  String toString() => 'FailureException(${failure.message})';
}

/// ينفذ [body] ويحوّل أي استثناء غير متوقع إلى [Err].
/// الاستثناء من نوع [FailureException] يُحوَّل إلى الـ [Failure] الذي يحمله.
Future<Result<T>> guardAsync<T>(
  Future<T> Function() body, {
  Failure Function(Object error)? onError,
}) async {
  try {
    return Ok<T>(await body());
  } on FailureException catch (e) {
    return Err<T>(e.failure);
  } catch (e) {
    return Err<T>(onError?.call(e) ?? UnexpectedFailure(
      'حدث خطأ غير متوقع. حاول مرة أخرى.',
      e,
    ));
  }
}