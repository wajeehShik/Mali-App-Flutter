import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../../core/errors/failure.dart';
import 'activation_token.dart';

/// يتحقق من تصريح التفعيل بالمفتاح العام (Ed25519). لا يحمل أي مفتاح خاص.
///
/// ترتيب الفحص: الصيغة ← التوقيع ← الجهاز ← الصلاحية.
/// محتوى التصريح لا يُعتمد عليه قبل نجاح التوقيع.
class LicenseVerifier {
  LicenseVerifier._(this._publicKey, this._clock);

  /// طول المفتاح العام لـ Ed25519 بالبايت.
  static const int publicKeyLength = 32;

  final SimplePublicKey _publicKey;
  final DateTime Function() _clock;
  final Ed25519 _algorithm = Ed25519();

  /// ينشئ المحقِّق من بايتات المفتاح العام. [clock] للاختبار فقط.
  static Result<LicenseVerifier> fromPublicKeyBytes(
    List<int> bytes, {
    DateTime Function()? clock,
  }) {
    if (bytes.length != publicKeyLength) {
      return const Err(
        ActivationFailure('مفتاح التحقق المضمَّن في التطبيق غير صالح.'),
      );
    }
    return Ok(
      LicenseVerifier._(
        SimplePublicKey(bytes, type: KeyPairType.ed25519),
        clock ?? DateTime.now,
      ),
    );
  }

  /// ينشئ المحقِّق من نص المفتاح العام (base64url بلا حشو)،
  /// وهو محتوى ملف assets/keys/license_public_key.txt.
  static Result<LicenseVerifier> fromEncodedKey(
    String encoded, {
    DateTime Function()? clock,
  }) {
    try {
      final bytes = base64Url.decode(base64Url.normalize(encoded.trim()));
      return fromPublicKeyBytes(bytes, clock: clock);
    } on FormatException {
      return const Err(
        ActivationFailure('مفتاح التحقق المضمَّن في التطبيق غير صالح.'),
      );
    }
  }

  /// يتحقق من [raw] لجهاز [deviceId].
  ///
  /// عند [allowExpired] = true لا يُعدّ انتهاء الصلاحية فشلًا،
  /// ويقرر المستدعي بنفسه عبر [ActivationToken.isExpiredAt].
  Future<Result<ActivationToken>> verify(
    String raw, {
    required String deviceId,
    bool allowExpired = false,
  }) async {
    final parsed = SignedActivationToken.parse(raw);
    final signed = parsed.valueOrNull;
    if (signed == null) {
      return Err(parsed.failureOrNull!);
    }

    final isValid = await _algorithm.verify(
      signed.payloadBytes,
      signature: Signature(signed.signature, publicKey: _publicKey),
    );
    if (!isValid) {
      return const Err(
        ActivationFailure(
          'توقيع التصريح غير صحيح.',
          reason: ActivationFailureReason.invalidSignature,
        ),
      );
    }

    final token = signed.token;

    if (!token.isForDevice(deviceId)) {
      return const Err(
        ActivationFailure(
          'هذا التصريح صادر لجهاز آخر.',
          reason: ActivationFailureReason.deviceMismatch,
        ),
      );
    }

    if (!allowExpired && token.isExpiredAt(_clock())) {
      return const Err(
        ActivationFailure(
          'انتهت صلاحية التفعيل.',
          reason: ActivationFailureReason.expired,
        ),
      );
    }

    return Ok(token);
  }
}