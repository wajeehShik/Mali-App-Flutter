import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';

/// محتوى تصريح التفعيل (الـ payload) بعد فك ترميزه.
/// لا يُعتدّ به قبل التحقق من التوقيع (يتم في خدمة التحقق لاحقًا).
@immutable
final class ActivationToken {
  const ActivationToken({
    required this.userId,
    required this.deviceId,
    required this.plan,
    required this.issuedAt,
    required this.expiresAt,
  });

  /// رقم النسخة المدعومة من صيغة الـ payload.
  static const int formatVersion = 1;

  final String userId;
  final String deviceId;
  final String plan;
  final DateTime issuedAt;
  final DateTime expiresAt;

  /// منتهٍ عند [now] أو بعده.
  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt);

  /// هل صدر التصريح لهذا الجهاز.
  bool isForDevice(String currentDeviceId) => deviceId == currentDeviceId;

  /// الأيام المتبقية (تُقرَّب للأسفل، والصفر إن انتهى).
  int daysLeftAt(DateTime now) {
    final diff = expiresAt.difference(now.toUtc());
    return diff.isNegative ? 0 : diff.inDays;
  }

  Map<String, Object> toJson() => {
        'v': formatVersion,
        'user_id': userId,
        'device_id': deviceId,
        'plan': plan,
        'issued_at': issuedAt.millisecondsSinceEpoch ~/ 1000,
        'expires_at': expiresAt.millisecondsSinceEpoch ~/ 1000,
      };

  @override
  bool operator ==(Object other) =>
      other is ActivationToken &&
      other.userId == userId &&
      other.deviceId == deviceId &&
      other.plan == plan &&
      other.issuedAt == issuedAt &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode =>
      Object.hash(userId, deviceId, plan, issuedAt, expiresAt);

  @override
  String toString() =>
      'ActivationToken(user: $userId, plan: $plan, expires: $expiresAt)';
}

/// تصريح خام مفكَّك الصيغة: النص الأصلي + البايتات الموقَّعة + التوقيع + المحتوى.
/// فكّ الصيغة هنا لا يعني أن التوقيع صحيح.
@immutable
final class SignedActivationToken {
  const SignedActivationToken._({
    required this.raw,
    required this.payloadBytes,
    required this.signature,
    required this.token,
  });

  /// طول توقيع Ed25519 بالبايت.
  static const int signatureLength = 64;

  /// النص الكامل كما يُخزَّن في التخزين الآمن.
  final String raw;

  /// البايتات التي وُقِّعت (يُتحقق من التوقيع عليها مباشرة).
  final Uint8List payloadBytes;

  final Uint8List signature;

  final ActivationToken token;

  /// يفكّ نص التصريح. أي صيغة معطوبة تُرجع [ActivationFailure]
  /// بسبب [ActivationFailureReason.invalidSignature].
  static Result<SignedActivationToken> parse(String raw) {
    final text = raw.trim();
    final parts = text.split('.');
    if (parts.length != 2 || parts.any((p) => p.isEmpty)) {
      return _bad('صيغة التصريح غير صحيحة.');
    }

    final Uint8List payloadBytes;
    final Uint8List signature;
    try {
      payloadBytes = base64Url.decode(base64Url.normalize(parts[0]));
      signature = base64Url.decode(base64Url.normalize(parts[1]));
    } on FormatException {
      return _bad('تعذّر قراءة التصريح.');
    }

    if (signature.length != signatureLength) {
      return _bad('توقيع التصريح غير صحيح.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(payloadBytes));
    } on FormatException {
      return _bad('محتوى التصريح تالف.');
    }
    if (decoded is! Map<String, Object?>) {
      return _bad('محتوى التصريح تالف.');
    }

    if (decoded['v'] != ActivationToken.formatVersion) {
      return _bad('نسخة التصريح غير مدعومة. حدّث التطبيق.');
    }

    final userId = decoded['user_id'];
    final deviceId = decoded['device_id'];
    final plan = decoded['plan'];
    final issuedAt = decoded['issued_at'];
    final expiresAt = decoded['expires_at'];

    if (userId is! String ||
        userId.isEmpty ||
        deviceId is! String ||
        deviceId.isEmpty ||
        plan is! String ||
        plan.isEmpty ||
        issuedAt is! int ||
        expiresAt is! int) {
      return _bad('بيانات التصريح ناقصة أو غير صالحة.');
    }
    if (expiresAt <= issuedAt) {
      return _bad('تواريخ التصريح غير منطقية.');
    }

    return Ok(
      SignedActivationToken._(
        raw: text,
        payloadBytes: payloadBytes,
        signature: signature,
        token: ActivationToken(
          userId: userId,
          deviceId: deviceId,
          plan: plan,
          issuedAt:
              DateTime.fromMillisecondsSinceEpoch(issuedAt * 1000, isUtc: true),
          expiresAt: DateTime.fromMillisecondsSinceEpoch(
            expiresAt * 1000,
            isUtc: true,
          ),
        ),
      ),
    );
  }

  static Result<SignedActivationToken> _bad(String message) {
    return Err(
      ActivationFailure(
        message,
        reason: ActivationFailureReason.invalidSignature,
      ),
    );
  }

  @override
  String toString() => 'SignedActivationToken(${token.userId})';
}