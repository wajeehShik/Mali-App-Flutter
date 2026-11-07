import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/features/activation/domain/activation_token.dart';
import 'package:mali/features/activation/domain/license_verifier.dart';

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Future<SimpleKeyPair> _keyPair(int offset) {
  return Ed25519().newKeyPairFromSeed(
    List<int>.generate(32, (i) => (i + offset) % 256),
  );
}

Future<String> _signToken(
  Map<String, Object?> payload,
  SimpleKeyPair keyPair,
) async {
  final bytes = utf8.encode(jsonEncode(payload));
  final signature = await Ed25519().sign(bytes, keyPair: keyPair);
  return '${_b64(bytes)}.${_b64(signature.bytes)}';
}

void _expectReason(Result<Object?> result, ActivationFailureReason reason) {
  expect(result.isErr, isTrue, reason: 'expected a failure, got $result');
  final failure = result.failureOrNull;
  expect(failure, isA<ActivationFailure>());
  expect((failure! as ActivationFailure).reason, reason);
}

void main() {
  final now = DateTime.utc(2026, 11, 7, 12);
  int secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  Map<String, Object?> payload({
    String deviceId = 'dev-1',
    String plan = 'pro',
    DateTime? issuedAt,
    DateTime? expiresAt,
  }) {
    return {
      'v': 1,
      'user_id': 'user-1',
      'device_id': deviceId,
      'plan': plan,
      'issued_at': secs(issuedAt ?? now.subtract(const Duration(days: 1))),
      'expires_at': secs(expiresAt ?? now.add(const Duration(days: 30))),
    };
  }

  late SimpleKeyPair serverKey;
  late SimpleKeyPair otherKey;
  late LicenseVerifier verifier;

  setUp(() async {
    serverKey = await _keyPair(0);
    otherKey = await _keyPair(100);
    final publicKey = await serverKey.extractPublicKey();
    verifier = LicenseVerifier.fromPublicKeyBytes(
      publicKey.bytes,
      clock: () => now,
    ).unwrap();
  });

  group('LicenseVerifier.verify', () {
    test('توقيع صحيح يرجع محتوى التصريح', () async {
      final raw = await _signToken(payload(), serverKey);

      final result = await verifier.verify(raw, deviceId: 'dev-1');

      expect(result.isOk, isTrue);
      final token = result.unwrap();
      expect(token.userId, 'user-1');
      expect(token.deviceId, 'dev-1');
      expect(token.plan, 'pro');
      expect(token.expiresAt, now.add(const Duration(days: 30)));
      expect(token.daysLeftAt(now), 30);
    });

    test('يقبل مسافات حول النص', () async {
      final raw = await _signToken(payload(), serverKey);

      final result = await verifier.verify('  $raw\n', deviceId: 'dev-1');

      expect(result.isOk, isTrue);
    });

    test('محتوى معدَّل مع إبقاء التوقيع يُرفض', () async {
      final original = await _signToken(payload(plan: 'basic'), serverKey);
      final forged = await _signToken(payload(plan: 'enterprise'), serverKey);
      final tampered =
          '${forged.split('.').first}.${original.split('.').last}';

      final result = await verifier.verify(tampered, deviceId: 'dev-1');

      _expectReason(result, ActivationFailureReason.invalidSignature);
    });

    test('توقيع بمفتاح آخر يُرفض', () async {
      final raw = await _signToken(payload(), otherKey);

      final result = await verifier.verify(raw, deviceId: 'dev-1');

      _expectReason(result, ActivationFailureReason.invalidSignature);
    });

    test('جهاز مختلف يُرفض', () async {
      final raw = await _signToken(payload(deviceId: 'dev-1'), serverKey);

      final result = await verifier.verify(raw, deviceId: 'dev-2');

      _expectReason(result, ActivationFailureReason.deviceMismatch);
    });

    test('التصريح المنتهي يُرفض', () async {
      final raw = await _signToken(
        payload(
          issuedAt: now.subtract(const Duration(days: 40)),
          expiresAt: now.subtract(const Duration(days: 10)),
        ),
        serverKey,
      );

      final result = await verifier.verify(raw, deviceId: 'dev-1');

      _expectReason(result, ActivationFailureReason.expired);
    });

    test('لحظة الانتهاء نفسها تُعدّ منتهية', () async {
      final raw = await _signToken(
        payload(
          issuedAt: now.subtract(const Duration(days: 30)),
          expiresAt: now,
        ),
        serverKey,
      );

      final result = await verifier.verify(raw, deviceId: 'dev-1');

      _expectReason(result, ActivationFailureReason.expired);
    });

    test('allowExpired يرجع التصريح المنتهي صحيح التوقيع', () async {
      final raw = await _signToken(
        payload(
          issuedAt: now.subtract(const Duration(days: 40)),
          expiresAt: now.subtract(const Duration(days: 10)),
        ),
        serverKey,
      );

      final result = await verifier.verify(
        raw,
        deviceId: 'dev-1',
        allowExpired: true,
      );

      expect(result.isOk, isTrue);
      expect(result.unwrap().isExpiredAt(now), isTrue);
      expect(result.unwrap().daysLeftAt(now), 0);
    });

    test('allowExpired لا يتجاوز فحص التوقيع ولا الجهاز', () async {
      final forged = await _signToken(
        payload(expiresAt: now.subtract(const Duration(days: 1))),
        otherKey,
      );
      final wrongDevice = await _signToken(
        payload(
          deviceId: 'dev-9',
          issuedAt: now.subtract(const Duration(days: 40)),
          expiresAt: now.subtract(const Duration(days: 1)),
        ),
        serverKey,
      );

      _expectReason(
        await verifier.verify(forged, deviceId: 'dev-1', allowExpired: true),
        ActivationFailureReason.invalidSignature,
      );
      _expectReason(
        await verifier.verify(
          wrongDevice,
          deviceId: 'dev-1',
          allowExpired: true,
        ),
        ActivationFailureReason.deviceMismatch,
      );
    });
  });

  group('SignedActivationToken.parse: صيغ معطوبة', () {
    final fakeSignature = _b64(List<int>.filled(64, 1));
    String withPayload(String json) =>
        '${_b64(utf8.encode(json))}.$fakeSignature';

    final validJson = jsonEncode(payload());

    final cases = <String, String>{
      'نص فارغ': '',
      'بلا نقطة': 'abcdef',
      'ثلاثة أجزاء': 'a.b.c',
      'جزء فارغ': 'abc.',
      'base64 غير صالح': '!!!.@@@',
      'توقيع بطول خاطئ': '${_b64(utf8.encode(validJson))}.${_b64([1, 2, 3])}',
      'JSON غير صالح': withPayload('not json'),
      'JSON ليس كائنًا': withPayload('[1,2,3]'),
      'نسخة غير مدعومة': withPayload(
        jsonEncode({...payload(), 'v': 2}),
      ),
      'حقل ناقص': withPayload(
        jsonEncode(Map.of(payload())..remove('plan')),
      ),
      'حقل بنوع خاطئ': withPayload(
        jsonEncode({...payload(), 'issued_at': 'yesterday'}),
      ),
      'انتهاء قبل الإصدار': withPayload(
        jsonEncode({
          ...payload(),
          'issued_at': secs(now),
          'expires_at': secs(now.subtract(const Duration(days: 1))),
        }),
      ),
    };

    cases.forEach((name, raw) {
      test(name, () async {
        final parsed = SignedActivationToken.parse(raw);
        _expectReason(parsed, ActivationFailureReason.invalidSignature);

        final verified = await verifier.verify(raw, deviceId: 'dev-1');
        _expectReason(verified, ActivationFailureReason.invalidSignature);
      });
    });
  });

  group('LicenseVerifier إنشاء المحقِّق', () {
    test('مفتاح بطول خاطئ يُرفض', () {
      final result = LicenseVerifier.fromPublicKeyBytes(List<int>.filled(31, 1));

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<ActivationFailure>());
    });

    test('نص مفتاح غير صالح يُرفض', () {
      expect(LicenseVerifier.fromEncodedKey('!!!').isErr, isTrue);
      expect(LicenseVerifier.fromEncodedKey('').isErr, isTrue);
    });

    test('نص مفتاح صالح يُقبل ويتحقق من توقيع صحيح', () async {
      final publicKey = await serverKey.extractPublicKey();
      final fromText = LicenseVerifier.fromEncodedKey(
        _b64(publicKey.bytes),
        clock: () => now,
      ).unwrap();
      final raw = await _signToken(payload(), serverKey);

      final result = await fromText.verify(raw, deviceId: 'dev-1');

      expect(result.isOk, isTrue);
    });
  });
}