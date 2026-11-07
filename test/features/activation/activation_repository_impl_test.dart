import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/storage/secure_storage.dart';
import 'package:mali/features/activation/data/activation_repository_impl.dart';
import 'package:mali/features/activation/data/device_identity.dart';
import 'package:mali/features/activation/data/mock_activation_remote_source.dart';
import 'package:mali/features/activation/domain/activation_state.dart';
import 'package:mali/features/activation/domain/license_verifier.dart';

import 'in_memory_secure_store.dart';

class _FakeNameSource implements DeviceNameSource {
  @override
  Future<String> name() async => 'Test Phone';
}

const String _deviceId = 'device-1234';

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Future<SimpleKeyPair> _keyPair(int offset) {
  return Ed25519().newKeyPairFromSeed(
    List<int>.generate(32, (i) => (i + offset) % 256),
  );
}

ActivationFailureReason? _reasonOf(Result<Object?> result) {
  final failure = result.failureOrNull;
  return failure is ActivationFailure ? failure.reason : null;
}

void main() {
  late DateTime now;
  late InMemorySecureStore store;
  late SimpleKeyPair serverKey;
  late SimpleKeyPair otherKey;
  late LicenseVerifier verifier;
  late Future<String?> Function(String deviceId) resolver;

  int secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;
  int? lastSeen() => int.tryParse(store.values[SecureKeys.lastSeenAt] ?? '');

  Future<String> signToken({
    String device = _deviceId,
    String plan = 'pro',
    DateTime? issuedAt,
    DateTime? expiresAt,
    SimpleKeyPair? key,
  }) async {
    final payload = {
      'v': 1,
      'user_id': 'user-1',
      'device_id': device,
      'plan': plan,
      'issued_at': secs(issuedAt ?? now.subtract(const Duration(days: 1))),
      'expires_at': secs(expiresAt ?? now.add(const Duration(days: 30))),
    };
    final bytes = utf8.encode(jsonEncode(payload));
    final signature = await Ed25519().sign(bytes, keyPair: key ?? serverKey);
    return '${_b64(bytes)}.${_b64(signature.bytes)}';
  }

  ActivationRepositoryImpl makeRepo({
    bool offline = false,
    bool reject = false,
    int polls = 0,
  }) {
    return ActivationRepositoryImpl(
      store: store,
      identity: DeviceIdentityService(
        store: store,
        nameSource: _FakeNameSource(),
      ),
      verifier: verifier,
      remote: MockActivationRemoteSource(
        tokenResolver: (id) => resolver(id),
        pollsBeforeDecision: polls,
        rejectRequests: reject,
        offline: offline,
        latency: Duration.zero,
      ),
      clock: () => now,
    );
  }

  setUp(() async {
    now = DateTime.utc(2026, 11, 7, 12);
    store = InMemorySecureStore({SecureKeys.deviceId: _deviceId});
    serverKey = await _keyPair(0);
    otherKey = await _keyPair(100);
    final publicKey = await serverKey.extractPublicKey();
    verifier = LicenseVerifier.fromPublicKeyBytes(
      publicKey.bytes,
      clock: () => now,
    ).unwrap();
    resolver = (id) async => null;
  });

  group('getDeviceId', () {
    test('يرجع معرّف الجهاز المخزَّن', () async {
      final result = await makeRepo().getDeviceId();

      expect(result.unwrap(), _deviceId);
    });

    test('فشل التخزين يرجع Err', () async {
      store.failReads = true;

      final result = await makeRepo().getDeviceId();

      expect(result.isErr, isTrue);
    });
  });

  group('loadState', () {
    test('لا شيء مخزَّن: NotActivated', () async {
      final state = (await makeRepo().loadState()).unwrap();

      expect(state, const NotActivated());
      expect(state.canWrite, isFalse);
      expect(state.canRead, isFalse);
    });

    test('طلب معلَّق مخزَّن: Pending', () async {
      store.values[SecureKeys.pendingRequestId] = 'req-9';

      final state = (await makeRepo().loadState()).unwrap();

      expect(state, const ActivationPending(requestId: 'req-9'));
    });

    test('تصريح صالح: Active وتُسجَّل آخر مرة شوهد', () async {
      store.values[SecureKeys.activationToken] = await signToken();

      final state = (await makeRepo().loadState()).unwrap();

      expect(state, isA<ActivationActive>());
      expect(state.canWrite, isTrue);
      expect(state.canRead, isTrue);
      expect((state as ActivationActive).token.plan, 'pro');
      expect(lastSeen(), secs(now));
    });

    test('تصريح منتهٍ: Expired (قراءة وتصدير فقط)', () async {
      store.values[SecureKeys.activationToken] = await signToken(
        issuedAt: now.subtract(const Duration(days: 40)),
        expiresAt: now.subtract(const Duration(days: 10)),
      );

      final state = (await makeRepo().loadState()).unwrap();

      expect(state, isA<ActivationExpired>());
      expect(state.canWrite, isFalse);
      expect(state.canRead, isTrue);
    });

    test('تصريح لجهاز آخر يُحذف ويرجع NotActivated', () async {
      store.values[SecureKeys.activationToken] =
          await signToken(device: 'someone-else');

      final state = (await makeRepo().loadState()).unwrap();

      expect(state, const NotActivated());
      expect(store.values.containsKey(SecureKeys.activationToken), isFalse);
    });

    test('تصريح تالف يُحذف ويرجع إلى الطلب المعلَّق إن وُجد', () async {
      store.values[SecureKeys.activationToken] = 'garbage';
      store.values[SecureKeys.pendingRequestId] = 'req-9';

      final state = (await makeRepo().loadState()).unwrap();

      expect(state, const ActivationPending(requestId: 'req-9'));
      expect(store.values.containsKey(SecureKeys.activationToken), isFalse);
    });

    test('تصريح بتوقيع مفتاح آخر يُحذف', () async {
      store.values[SecureKeys.activationToken] =
          await signToken(key: otherKey);

      final state = (await makeRepo().loadState()).unwrap();

      expect(state, const NotActivated());
      expect(store.values.containsKey(SecureKeys.activationToken), isFalse);
    });

    test('تراجع الساعة بأكثر من الهامش: Expired رغم صلاحية التصريح', () async {
      store.values[SecureKeys.activationToken] = await signToken();
      store.values[SecureKeys.lastSeenAt] = '${secs(now) + 3600}';

      final state = (await makeRepo().loadState()).unwrap();

      expect(state, isA<ActivationExpired>());
      expect(lastSeen(), secs(now) + 3600, reason: 'لا يُخفَّض الحاجز');
    });

    test('تراجع ضمن الهامش (300 ثانية): Active دون تخفيض الحاجز', () async {
      store.values[SecureKeys.activationToken] = await signToken();
      store.values[SecureKeys.lastSeenAt] = '${secs(now) + 300}';

      final state = (await makeRepo().loadState()).unwrap();

      expect(state, isA<ActivationActive>());
      expect(lastSeen(), secs(now) + 300);
    });

    test('حدّ الهامش: 600 ثانية مقبولة و601 مرفوضة', () async {
      store.values[SecureKeys.activationToken] = await signToken();

      store.values[SecureKeys.lastSeenAt] = '${secs(now) + 600}';
      expect(
        (await makeRepo().loadState()).unwrap(),
        isA<ActivationActive>(),
      );

      store.values[SecureKeys.lastSeenAt] = '${secs(now) + 601}';
      expect(
        (await makeRepo().loadState()).unwrap(),
        isA<ActivationExpired>(),
      );
    });

    test('مرور الوقت الطبيعي يقدّم آخر مرة شوهد', () async {
      store.values[SecureKeys.activationToken] = await signToken();
      store.values[SecureKeys.lastSeenAt] = '${secs(now) - 1000}';

      await makeRepo().loadState();

      expect(lastSeen(), secs(now));
    });

    test('فشل القراءة يرجع Err', () async {
      store.failReads = true;

      final result = await makeRepo().loadState();

      expect(result.isErr, isTrue);
    });
  });

  group('submitRequest', () {
    test('اسم فارغ يُرفض قبل أي اتصال', () async {
      final result = await makeRepo().submitRequest(name: '   ');

      final failure = result.failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).fieldErrors.keys, ['name']);
      expect(store.values.containsKey(SecureKeys.pendingRequestId), isFalse);
    });

    test('اسم أطول من 80 حرفًا يُرفض', () async {
      final result = await makeRepo().submitRequest(name: 'ا' * 81);

      final failure = result.failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).fieldErrors.keys, ['name']);
    });

    test('هاتف أطول من 30 حرفًا يُرفض', () async {
      final result = await makeRepo().submitRequest(
        name: 'Ahmad',
        phone: '1' * 31,
      );

      final failure = result.failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).fieldErrors.keys, ['phone']);
    });

    test('نجاح الطلب: Pending ويُخزَّن المعرّف', () async {
      final state = (await makeRepo().submitRequest(
        name: ' Ahmad ',
        phone: '0599',
      ))
          .unwrap();

      expect(state, const ActivationPending(requestId: 'mock-request-1'));
      expect(store.values[SecureKeys.pendingRequestId], 'mock-request-1');
    });

    test('انقطاع الإنترنت: NetworkFailure ولا يُخزَّن شيء', () async {
      final result = await makeRepo(offline: true).submitRequest(name: 'Ahmad');

      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(store.values.containsKey(SecureKeys.pendingRequestId), isFalse);
    });

    test('فشل حفظ معرّف الطلب يرجع Err', () async {
      store.failWrites = true;

      final result = await makeRepo().submitRequest(name: 'Ahmad');

      expect(result.isErr, isTrue);
    });
  });

  group('refreshPending', () {
    test('لا طلب معلَّق: NotActivated', () async {
      final state = (await makeRepo().refreshPending()).unwrap();

      expect(state, const NotActivated());
    });

    test('معلَّق ثم موافقة: Active ويُخزَّن التصريح', () async {
      resolver = (id) => signToken(device: id);
      final repo = makeRepo(polls: 1);
      await repo.submitRequest(name: 'Ahmad');

      final first = (await repo.refreshPending()).unwrap();
      expect(first, const ActivationPending(requestId: 'mock-request-1'));

      final second = (await repo.refreshPending()).unwrap();
      expect(second, isA<ActivationActive>());
      expect(store.values[SecureKeys.activationToken], isNotNull);
      expect(store.values.containsKey(SecureKeys.pendingRequestId), isFalse);
      expect(lastSeen(), secs(now));
    });

    test('الرفض: NotActivated مع رسالة ويُحذف الطلب', () async {
      final repo = makeRepo(reject: true);
      await repo.submitRequest(name: 'Ahmad');

      final state = (await repo.refreshPending()).unwrap();

      expect(state, isA<NotActivated>());
      expect((state as NotActivated).rejectedMessage, isNotEmpty);
      expect(store.values.containsKey(SecureKeys.pendingRequestId), isFalse);
    });

    test('انقطاع الإنترنت: Err ويبقى الطلب كما هو', () async {
      store.values[SecureKeys.pendingRequestId] = 'mock-request-1';

      final result = await makeRepo(offline: true).refreshPending();

      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(store.values[SecureKeys.pendingRequestId], 'mock-request-1');
    });

    test('موافقة بتصريح لجهاز آخر تُرفض ولا يُخزَّن', () async {
      resolver = (id) => signToken(device: 'someone-else');
      final repo = makeRepo();
      await repo.submitRequest(name: 'Ahmad');

      final result = await repo.refreshPending();

      expect(_reasonOf(result), ActivationFailureReason.deviceMismatch);
      expect(store.values.containsKey(SecureKeys.activationToken), isFalse);
      expect(store.values[SecureKeys.pendingRequestId], 'mock-request-1');
    });

    test('موافقة بتصريح مزوَّر التوقيع تُرفض', () async {
      resolver = (id) => signToken(device: id, key: otherKey);
      final repo = makeRepo();
      await repo.submitRequest(name: 'Ahmad');

      final result = await repo.refreshPending();

      expect(_reasonOf(result), ActivationFailureReason.invalidSignature);
      expect(store.values.containsKey(SecureKeys.activationToken), isFalse);
    });

    test('الموافقة تصفّر حاجز الساعة (دليل اتصال سليم)', () async {
      resolver = (id) => signToken(device: id);
      store.values[SecureKeys.lastSeenAt] = '${secs(now) + 7200}';
      final repo = makeRepo();
      await repo.submitRequest(name: 'Ahmad');

      await repo.refreshPending();

      expect(lastSeen(), secs(now));
    });
  });

  group('activateWithCode', () {
    test('نص فارغ يرجع ValidationFailure على code', () async {
      final result = await makeRepo().activateWithCode('   ');

      final failure = result.failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).fieldErrors.keys, ['code']);
    });

    test('رمز صحيح: Active ويُخزَّن ويُحذف الطلب المعلَّق', () async {
      store.values[SecureKeys.pendingRequestId] = 'req-9';
      final code = await signToken();

      final state = (await makeRepo().activateWithCode(' $code\n')).unwrap();

      expect(state, isA<ActivationActive>());
      expect(store.values[SecureKeys.activationToken], code);
      expect(store.values.containsKey(SecureKeys.pendingRequestId), isFalse);
    });

    test('جهاز آخر يُرفض ولا يُخزَّن', () async {
      final result = await makeRepo().activateWithCode(
        await signToken(device: 'someone-else'),
      );

      expect(_reasonOf(result), ActivationFailureReason.deviceMismatch);
      expect(store.values.containsKey(SecureKeys.activationToken), isFalse);
    });

    test('منتهٍ يُرفض ولا يُخزَّن', () async {
      final result = await makeRepo().activateWithCode(
        await signToken(
          issuedAt: now.subtract(const Duration(days: 40)),
          expiresAt: now.subtract(const Duration(days: 10)),
        ),
      );

      expect(_reasonOf(result), ActivationFailureReason.expired);
      expect(store.values.containsKey(SecureKeys.activationToken), isFalse);
    });

    test('مزوَّر التوقيع يُرفض', () async {
      final result = await makeRepo().activateWithCode(
        await signToken(key: otherKey),
      );

      expect(_reasonOf(result), ActivationFailureReason.invalidSignature);
    });

    test('رمز تالف يُرفض', () async {
      final result = await makeRepo().activateWithCode('not-a-token');

      expect(_reasonOf(result), ActivationFailureReason.invalidSignature);
    });

    test('التفعيل اليدوي لا يخفّض حاجز الساعة ولا يتجاوزه', () async {
      store.values[SecureKeys.lastSeenAt] = '${secs(now) + 3600}';
      final repo = makeRepo();

      final activated = (await repo.activateWithCode(await signToken())).unwrap();
      expect(activated, isA<ActivationActive>());
      expect(lastSeen(), secs(now) + 3600);

      final reloaded = (await repo.loadState()).unwrap();
      expect(reloaded, isA<ActivationExpired>());
    });
  });

  group('renew', () {
    test('بلا تصريح مخزَّن: notActivated', () async {
      final result = await makeRepo().renew();

      expect(_reasonOf(result), ActivationFailureReason.notActivated);
    });

    test('نجاح التجديد: يستبدل التصريح ويصفّر الحاجز', () async {
      final old = await signToken(plan: 'basic');
      store.values[SecureKeys.activationToken] = old;
      store.values[SecureKeys.lastSeenAt] = '${secs(now) + 3600}';
      resolver = (id) => signToken(
            device: id,
            plan: 'pro',
            expiresAt: now.add(const Duration(days: 60)),
          );

      final state = (await makeRepo().renew()).unwrap();

      expect(state, isA<ActivationActive>());
      expect((state as ActivationActive).token.plan, 'pro');
      expect(store.values[SecureKeys.activationToken], isNot(old));
      expect(lastSeen(), secs(now));
    });

    test('انقطاع الإنترنت: Err ويبقى التصريح القديم', () async {
      final old = await signToken();
      store.values[SecureKeys.activationToken] = old;

      final result = await makeRepo(offline: true).renew();

      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(store.values[SecureKeys.activationToken], old);
    });

    test('تصريح مُجدَّد غير صالح يُرفض ويبقى القديم', () async {
      final old = await signToken();
      store.values[SecureKeys.activationToken] = old;
      resolver = (id) => signToken(device: 'someone-else');

      final result = await makeRepo().renew();

      expect(_reasonOf(result), ActivationFailureReason.deviceMismatch);
      expect(store.values[SecureKeys.activationToken], old);
    });
  });

  group('clear', () {
    test('يحذف التصريح والطلب ويُبقي حاجز الساعة', () async {
      store.values[SecureKeys.activationToken] = await signToken();
      store.values[SecureKeys.pendingRequestId] = 'req-9';
      store.values[SecureKeys.lastSeenAt] = '${secs(now)}';

      final result = await makeRepo().clear();

      expect(result.isOk, isTrue);
      expect(store.values.containsKey(SecureKeys.activationToken), isFalse);
      expect(store.values.containsKey(SecureKeys.pendingRequestId), isFalse);
      expect(lastSeen(), secs(now));
    });

    test('فشل الحذف يرجع Err', () async {
      store.values[SecureKeys.activationToken] = await signToken();
      store.failDeletes = true;

      final result = await makeRepo().clear();

      expect(result.isErr, isTrue);
    });
  });
}