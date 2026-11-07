import 'package:flutter/foundation.dart';

import 'activation_token.dart';

/// حالة التفعيل الحالية للتطبيق. تتحكم بما يُسمح به للمستخدم.
@immutable
sealed class ActivationState {
  const ActivationState();

  /// استخدام كامل: إضافة وتعديل وحذف العمليات.
  bool get canWrite;

  /// قراءة وتصدير البيانات (حتى لا تُحتجز بيانات المستخدم بعد الانتهاء).
  bool get canRead;
}

/// لا يوجد تصريح صالح. [rejectedMessage] يُعرض إن كان آخر طلب قد رُفض.
final class NotActivated extends ActivationState {
  const NotActivated({this.rejectedMessage});

  final String? rejectedMessage;

  @override
  bool get canWrite => false;

  @override
  bool get canRead => false;

  @override
  bool operator ==(Object other) =>
      other is NotActivated && other.rejectedMessage == rejectedMessage;

  @override
  int get hashCode => Object.hash(NotActivated, rejectedMessage);

  @override
  String toString() => 'NotActivated($rejectedMessage)';
}

/// الطلب مُرسَل وينتظر موافقة المسؤول.
final class ActivationPending extends ActivationState {
  const ActivationPending({required this.requestId});

  final String requestId;

  @override
  bool get canWrite => false;

  @override
  bool get canRead => false;

  @override
  bool operator ==(Object other) =>
      other is ActivationPending && other.requestId == requestId;

  @override
  int get hashCode => Object.hash(ActivationPending, requestId);

  @override
  String toString() => 'ActivationPending($requestId)';
}

/// تصريح صالح (التوقيع والجهاز والصلاحية).
final class ActivationActive extends ActivationState {
  const ActivationActive(this.token);

  final ActivationToken token;

  @override
  bool get canWrite => true;

  @override
  bool get canRead => true;

  @override
  bool operator ==(Object other) =>
      other is ActivationActive && other.token == token;

  @override
  int get hashCode => Object.hash(ActivationActive, token);

  @override
  String toString() => 'ActivationActive($token)';
}

/// تصريح صحيح التوقيع ولهذا الجهاز لكنه منتهٍ: قراءة وتصدير فقط.
final class ActivationExpired extends ActivationState {
  const ActivationExpired(this.token);

  final ActivationToken token;

  @override
  bool get canWrite => false;

  @override
  bool get canRead => true;

  @override
  bool operator ==(Object other) =>
      other is ActivationExpired && other.token == token;

  @override
  int get hashCode => Object.hash(ActivationExpired, token);

  @override
  String toString() => 'ActivationExpired($token)';
}