import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';

/// بيانات مقدِّم طلب التفعيل.
@immutable
final class ActivationApplicant {
  const ActivationApplicant({
    required this.name,
    required this.deviceId,
    required this.deviceName,
    this.phone,
  });

  /// اسم المستخدم أو النشاط التجاري.
  final String name;

  final String? phone;

  /// معرّف التثبيت (يُربط به التصريح).
  final String deviceId;

  /// اسم الجهاز للعرض فقط عند مراجعة المسؤول.
  final String deviceName;
}

/// إيصال طلب التفعيل المُرسَل. يُحفظ [requestId] لمتابعة حالة الطلب.
@immutable
final class ActivationRequestTicket {
  const ActivationRequestTicket({required this.requestId});

  final String requestId;
}

enum ActivationRequestStatus { pending, approved, rejected }

/// حالة الطلب لدى الخادم.
/// عند [ActivationRequestStatus.approved] يجب أن يحمل [token].
@immutable
final class ActivationRequestState {
  const ActivationRequestState.pending()
      : status = ActivationRequestStatus.pending,
        token = null,
        message = null;

  const ActivationRequestState.approved(String this.token)
      : status = ActivationRequestStatus.approved,
        message = null;

  const ActivationRequestState.rejected([this.message])
      : status = ActivationRequestStatus.rejected,
        token = null;

  final ActivationRequestStatus status;

  /// نص التصريح الموقَّع (payload.signature). غير موجود إلا عند الموافقة.
  /// لا يُعتمد عليه قبل التحقق من توقيعه بالمفتاح العام.
  final String? token;

  /// سبب الرفض إن وفّره المسؤول.
  final String? message;
}

/// عقد الاتصال بخادم التفعيل (Laravel مستقبلًا، وهو غير موجود حاليًا).
///
/// المسارات المقترحة للخادم عند بنائه:
///   POST /activation/requests       ← submitRequest
///   GET  /activation/requests/{id}  ← fetchRequestState
///   POST /activation/renew          ← renewToken
///
/// كل الدوال ترجع [Result]: انقطاع الاتصال = [NetworkFailure]،
/// ورفض الخادم = [ServerFailure]. لا تُرمى استثناءات إلى الطبقات العليا.
abstract interface class ActivationRemoteSource {
  /// يرسل طلب تفعيل جديد ويبقى معلَّقًا حتى موافقة المسؤول.
  Future<Result<ActivationRequestTicket>> submitRequest(
    ActivationApplicant applicant,
  );

  /// يستعلم عن حالة طلب سبق إرساله.
  Future<Result<ActivationRequestState>> fetchRequestState({
    required String requestId,
    required String deviceId,
  });

  /// يطلب تجديد تصريح قائم، ويرجع نص التصريح الجديد.
  Future<Result<String>> renewToken({
    required String currentToken,
    required String deviceId,
  });
}