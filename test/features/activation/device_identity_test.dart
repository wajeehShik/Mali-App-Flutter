import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/storage/secure_storage.dart';
import 'package:mali/features/activation/data/device_identity.dart';

import 'in_memory_secure_store.dart';

class _FakeNameSource implements DeviceNameSource {
  @override
  Future<String> name() async => 'Test Phone';
}

void main() {
  late InMemorySecureStore store;
  late int generated;

  DeviceIdentityService makeService() {
    return DeviceIdentityService(
      store: store,
      nameSource: _FakeNameSource(),
      idGenerator: () => 'generated-id-${++generated}',
    );
  }

  setUp(() {
    store = InMemorySecureStore();
    generated = 0;
  });

  group('DeviceIdentityService.load', () {
    test('أول مرة: يولّد معرّفًا ويخزّنه ويرجع اسم الجهاز', () async {
      final result = await makeService().load();

      expect(result.isOk, isTrue);
      final identity = result.unwrap();
      expect(identity.deviceId, 'generated-id-1');
      expect(identity.deviceName, 'Test Phone');
      expect(store.values[SecureKeys.deviceId], 'generated-id-1');
      expect(generated, 1);
    });

    test('المعرّف ثابت بين تشغيلين (نسخة خدمة جديدة)', () async {
      final first = (await makeService().load()).unwrap();
      final second = (await makeService().load()).unwrap();

      expect(second.deviceId, first.deviceId);
      expect(generated, 1);
      expect(store.writeCounts[SecureKeys.deviceId], 1);
    });

    test('النسخة نفسها تخزّن الهوية في الذاكرة', () async {
      final service = makeService();

      await service.load();
      store.failReads = true;
      final again = await service.load();

      expect(again.isOk, isTrue);
      expect(again.unwrap().deviceId, 'generated-id-1');
    });

    test('استدعاءان متزامنان يولّدان معرّفًا واحدًا فقط', () async {
      final service = makeService();

      final results = await Future.wait([service.load(), service.load()]);

      expect(results[0].unwrap().deviceId, results[1].unwrap().deviceId);
      expect(generated, 1);
      expect(store.writeCounts[SecureKeys.deviceId], 1);
    });

    test('يستعمل المعرّف المخزَّن ويقصّ المسافات حوله', () async {
      store.values[SecureKeys.deviceId] = '  existing-device-id  ';

      final result = await makeService().load();

      expect(result.unwrap().deviceId, 'existing-device-id');
      expect(generated, 0);
      expect(store.writeCounts[SecureKeys.deviceId], isNull);
    });

    test('معرّف مخزَّن قصير أو فارغ يُستبدل بمعرّف جديد', () async {
      store.values[SecureKeys.deviceId] = 'abc';
      final shortResult = await makeService().load();
      expect(shortResult.unwrap().deviceId, 'generated-id-1');

      store.values[SecureKeys.deviceId] = '   ';
      final blankResult = await makeService().load();
      expect(blankResult.unwrap().deviceId, 'generated-id-2');
    });
  });

  group('DeviceIdentityService الأخطاء', () {
    test('فشل القراءة يرجع Err ولا يولّد معرّفًا', () async {
      store.failReads = true;

      final result = await makeService().load();

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<Failure>());
      expect(generated, 0);
      expect(store.values.containsKey(SecureKeys.deviceId), isFalse);
    });

    test('فشل الكتابة يرجع Err ولا يعيد معرّفًا مؤقتًا', () async {
      store.failWrites = true;

      final result = await makeService().load();

      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('الفشل لا يُخزَّن: التحميل ينجح بعد زوال العطل', () async {
      final service = makeService();
      store.failWrites = true;
      expect((await service.load()).isErr, isTrue);

      store.failWrites = false;
      final retry = await service.load();

      expect(retry.isOk, isTrue);
      expect(store.values[SecureKeys.deviceId], retry.unwrap().deviceId);
    });
  });

  group('DeviceIdentity', () {
    test('المساواة تعتمد على المعرّف والاسم', () {
      const a = DeviceIdentity(deviceId: 'id-1', deviceName: 'Phone');
      const b = DeviceIdentity(deviceId: 'id-1', deviceName: 'Phone');
      const c = DeviceIdentity(deviceId: 'id-2', deviceName: 'Phone');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}