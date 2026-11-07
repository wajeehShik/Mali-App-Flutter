import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/features/activation/data/mock_activation_remote_source.dart';
import 'package:mali/features/activation/domain/activation_remote_source.dart';

const _applicant = ActivationApplicant(
  name: 'Ahmad',
  deviceId: 'dev-1',
  deviceName: 'Test Phone',
);

MockActivationRemoteSource _make({
  MockTokenResolver? resolver,
  int polls = 2,
  bool reject = false,
  bool offline = false,
}) {
  return MockActivationRemoteSource(
    tokenResolver: resolver,
    pollsBeforeDecision: polls,
    rejectRequests: reject,
    offline: offline,
    latency: Duration.zero,
  );
}

Future<String> _submit(MockActivationRemoteSource source) async {
  final result = await source.submitRequest(_applicant);
  return result.unwrap().requestId;
}

void main() {
  group('submitRequest', () {
    test('يرجع إيصالات فريدة ومتسلسلة', () async {
      final source = _make();

      final first = await _submit(source);
      final second = await _submit(source);

      expect(first, 'mock-request-1');
      expect(second, 'mock-request-2');
    });

    test('اسم فارغ يُرفض مع رسالة على حقل name', () async {
      final result = await _make().submitRequest(
        const ActivationApplicant(
          name: '   ',
          deviceId: 'dev-1',
          deviceName: 'Phone',
        ),
      );

      final failure = result.failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).fieldErrors.keys, ['name']);
    });

    test('بلا إنترنت يرجع NetworkFailure', () async {
      final result = await _make(offline: true).submitRequest(_applicant);

      expect(result.failureOrNull, isA<NetworkFailure>());
    });
  });

  group('fetchRequestState', () {
    test('يبقى معلَّقًا عدد الاستعلامات المحدد ثم يوافق', () async {
      final source = _make(resolver: (_) async => 'signed-token');
      final id = await _submit(source);

      Future<ActivationRequestState> poll() async {
        final result = await source.fetchRequestState(
          requestId: id,
          deviceId: 'dev-1',
        );
        return result.unwrap();
      }

      expect((await poll()).status, ActivationRequestStatus.pending);
      expect((await poll()).status, ActivationRequestStatus.pending);

      final decided = await poll();
      expect(decided.status, ActivationRequestStatus.approved);
      expect(decided.token, 'signed-token');
    });

    test('pollsBeforeDecision = 0 يقرر من أول استعلام', () async {
      final source = _make(resolver: (_) async => 'signed-token', polls: 0);
      final id = await _submit(source);

      final result = await source.fetchRequestState(
        requestId: id,
        deviceId: 'dev-1',
      );

      expect(result.unwrap().status, ActivationRequestStatus.approved);
    });

    test('بلا tokenResolver يبقى معلَّقًا دائمًا', () async {
      final source = _make(polls: 0);
      final id = await _submit(source);

      for (var i = 0; i < 4; i++) {
        final result = await source.fetchRequestState(
          requestId: id,
          deviceId: 'dev-1',
        );
        expect(result.unwrap().status, ActivationRequestStatus.pending);
      }
    });

    test('resolver يرجع null أو نصًا فارغًا: يبقى معلَّقًا', () async {
      for (final answer in <String?>[null, '   ']) {
        final source = _make(resolver: (_) async => answer, polls: 0);
        final id = await _submit(source);

        final result = await source.fetchRequestState(
          requestId: id,
          deviceId: 'dev-1',
        );

        expect(
          result.unwrap().status,
          ActivationRequestStatus.pending,
          reason: 'answer: "$answer"',
        );
      }
    });

    test('يمرّر معرّف الجهاز إلى resolver', () async {
      String? received;
      final source = _make(
        resolver: (deviceId) async {
          received = deviceId;
          return 'signed-token';
        },
        polls: 0,
      );
      final id = await _submit(source);

      await source.fetchRequestState(requestId: id, deviceId: 'dev-1');

      expect(received, 'dev-1');
    });

    test('rejectRequests يرفض بعد الاستعلامات المعلَّقة مع رسالة', () async {
      final source = _make(reject: true, polls: 1);
      final id = await _submit(source);

      final first = await source.fetchRequestState(
        requestId: id,
        deviceId: 'dev-1',
      );
      final second = await source.fetchRequestState(
        requestId: id,
        deviceId: 'dev-1',
      );

      expect(first.unwrap().status, ActivationRequestStatus.pending);
      expect(second.unwrap().status, ActivationRequestStatus.rejected);
      expect(second.unwrap().message, isNotEmpty);
      expect(second.unwrap().token, isNull);
    });

    test('طلب غير موجود يرجع NotFoundFailure', () async {
      final result = await _make().fetchRequestState(
        requestId: 'nope',
        deviceId: 'dev-1',
      );

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('جهاز مختلف يرجع ServerFailure برمز 403', () async {
      final source = _make(resolver: (_) async => 'signed-token', polls: 0);
      final id = await _submit(source);

      final result = await source.fetchRequestState(
        requestId: id,
        deviceId: 'other-device',
      );

      final failure = result.failureOrNull;
      expect(failure, isA<ServerFailure>());
      expect((failure! as ServerFailure).statusCode, 403);
    });

    test('بلا إنترنت يرجع NetworkFailure', () async {
      final result = await _make(offline: true).fetchRequestState(
        requestId: 'mock-request-1',
        deviceId: 'dev-1',
      );

      expect(result.failureOrNull, isA<NetworkFailure>());
    });
  });

  group('renewToken', () {
    test('يرجع التصريح من resolver', () async {
      final source = _make(resolver: (_) async => 'renewed-token');

      final result = await source.renewToken(
        currentToken: 'old',
        deviceId: 'dev-1',
      );

      expect(result.unwrap(), 'renewed-token');
    });

    test('بلا resolver أو بنص فارغ يرجع ServerFailure برمز 404', () async {
      final sources = [
        _make(),
        _make(resolver: (_) async => null),
        _make(resolver: (_) async => ' '),
      ];

      for (final source in sources) {
        final result = await source.renewToken(
          currentToken: 'old',
          deviceId: 'dev-1',
        );

        final failure = result.failureOrNull;
        expect(failure, isA<ServerFailure>());
        expect((failure! as ServerFailure).statusCode, 404);
      }
    });

    test('بلا إنترنت يرجع NetworkFailure', () async {
      final result = await _make(
        offline: true,
        resolver: (_) async => 'renewed-token',
      ).renewToken(currentToken: 'old', deviceId: 'dev-1');

      expect(result.failureOrNull, isA<NetworkFailure>());
    });
  });
}