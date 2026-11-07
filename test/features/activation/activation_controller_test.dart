import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/features/activation/domain/activation_repository.dart';
import 'package:mali/features/activation/domain/activation_state.dart';
import 'package:mali/features/activation/domain/activation_token.dart';
import 'package:mali/features/activation/presentation/activation_providers.dart';

/// مستودع وهمي: يرجع النتائج المضبوطة ويعدّ الاستدعاءات.
class _FakeRepository implements ActivationRepository {
  Result<ActivationState> loadResult = const Ok(NotActivated());
  Result<ActivationState> submitResult = const Ok(NotActivated());
  Result<ActivationState> refreshResult = const Ok(NotActivated());
  Result<ActivationState> codeResult = const Ok(NotActivated());
  Result<ActivationState> renewResult = const Ok(NotActivated());
  Result<void> clearResult = const Ok<void>(null);

  /// إن ضُبطت يُرمى هذا الكائن بدل إرجاع نتيجة (لاختبار الاستثناءات).
  Object? throwOnCall;

  int loadCalls = 0;
  String? lastName;
  String? lastPhone;
  String? lastCode;

  void _maybeThrow() {
    final error = throwOnCall;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<Result<String>> getDeviceId() async => const Ok('device-1234');

  @override
  Future<Result<ActivationState>> loadState() async {
    loadCalls += 1;
    return loadResult;
  }

  @override
  Future<Result<ActivationState>> submitRequest({
    required String name,
    String? phone,
  }) async {
    _maybeThrow();
    lastName = name;
    lastPhone = phone;
    return submitResult;
  }

  @override
  Future<Result<ActivationState>> refreshPending() async {
    _maybeThrow();
    return refreshResult;
  }

  @override
  Future<Result<ActivationState>> activateWithCode(String code) async {
    _maybeThrow();
    lastCode = code;
    return codeResult;
  }

  @override
  Future<Result<ActivationState>> renew() async {
    _maybeThrow();
    return renewResult;
  }

  @override
  Future<Result<void>> clear() async {
    _maybeThrow();
    return clearResult;
  }
}

ActivationToken _token({String plan = 'pro'}) {
  return ActivationToken(
    userId: 'user-1',
    deviceId: 'device-1234',
    plan: plan,
    issuedAt: DateTime.utc(2026, 11, 6),
    expiresAt: DateTime.utc(2026, 12, 7),
  );
}

void main() {
  late _FakeRepository repo;
  late ProviderContainer container;

  ProviderContainer makeContainer() {
    final created = ProviderContainer(
      // نعطّل إعادة المحاولة التلقائية حتى لا تعلّق اختبارات حالة الخطأ.
      retry: (retryCount, error) => null,
      overrides: [
        activationRepositoryProvider.overrideWith((ref) async => repo),
      ],
    );
    addTearDown(created.dispose);
    return created;
  }

  Future<ActivationState> currentState() {
    return container.read(activationControllerProvider.future);
  }

  setUp(() {
    repo = _FakeRepository();
    container = makeContainer();
  });

  group('التحميل الأول', () {
    test('يقرأ الحالة من المستودع', () async {
      repo.loadResult = Ok(ActivationActive(_token()));

      final state = await currentState();

      expect(state, ActivationActive(_token()));
      expect(repo.loadCalls, 1);
    });

    test('فشل التحميل يظهر كخطأ يحمل Failure', () async {
      repo.loadResult = const Err(DatabaseFailure('تعذر القراءة.'));

      await expectLater(
        currentState(),
        throwsA(
          isA<FailureException>().having(
            (e) => e.failure.message,
            'message',
            'تعذر القراءة.',
          ),
        ),
      );
    });
  });

  group('submitRequest', () {
    test('نجاح: يرجع null ويحدّث الحالة إلى Pending', () async {
      await currentState();
      repo.submitResult = const Ok(ActivationPending(requestId: 'req-1'));

      final failure = await container
          .read(activationControllerProvider.notifier)
          .submitRequest(name: 'Ahmad', phone: '0599');

      expect(failure, isNull);
      expect(await currentState(), const ActivationPending(requestId: 'req-1'));
      expect(repo.lastName, 'Ahmad');
      expect(repo.lastPhone, '0599');
    });

    test('فشل: يرجع السبب وتبقى الحالة كما هي', () async {
      await currentState();
      repo.submitResult = const Err(NetworkFailure());

      final failure = await container
          .read(activationControllerProvider.notifier)
          .submitRequest(name: 'Ahmad');

      expect(failure, isA<NetworkFailure>());
      expect(await currentState(), const NotActivated());
      expect(container.read(activationControllerProvider).hasError, isFalse);
    });

    test('فشل التحقق يحمل رسائل الحقول', () async {
      await currentState();
      repo.submitResult = const Err(
        ValidationFailure('تحقق.', fieldErrors: {'name': 'الاسم مطلوب.'}),
      );

      final failure = await container
          .read(activationControllerProvider.notifier)
          .submitRequest(name: ' ');

      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).fieldErrors['name'], isNotNull);
    });
  });

  group('refreshPending', () {
    test('موافقة: الحالة تصبح Active', () async {
      repo.loadResult = const Ok(ActivationPending(requestId: 'req-1'));
      await currentState();
      repo.refreshResult = Ok(ActivationActive(_token()));

      final failure =
          await container.read(activationControllerProvider.notifier).refreshPending();

      expect(failure, isNull);
      expect(await currentState(), ActivationActive(_token()));
    });

    test('رفض: NotActivated مع رسالة الرفض', () async {
      repo.loadResult = const Ok(ActivationPending(requestId: 'req-1'));
      await currentState();
      repo.refreshResult = const Ok(NotActivated(rejectedMessage: 'مرفوض'));

      await container.read(activationControllerProvider.notifier).refreshPending();

      expect(await currentState(), const NotActivated(rejectedMessage: 'مرفوض'));
    });

    test('انقطاع الإنترنت: Failure وتبقى Pending', () async {
      repo.loadResult = const Ok(ActivationPending(requestId: 'req-1'));
      await currentState();
      repo.refreshResult = const Err(NetworkFailure());

      final failure =
          await container.read(activationControllerProvider.notifier).refreshPending();

      expect(failure, isA<NetworkFailure>());
      expect(await currentState(), const ActivationPending(requestId: 'req-1'));
    });
  });

  group('activateWithCode', () {
    test('نجاح: Active ويمرَّر الرمز كما هو للمستودع', () async {
      await currentState();
      repo.codeResult = Ok(ActivationActive(_token()));

      final failure = await container
          .read(activationControllerProvider.notifier)
          .activateWithCode('payload.signature');

      expect(failure, isNull);
      expect(await currentState(), ActivationActive(_token()));
      expect(repo.lastCode, 'payload.signature');
    });

    test('رمز مرفوض: يرجع ActivationFailure وتبقى الحالة', () async {
      await currentState();
      repo.codeResult = const Err(
        ActivationFailure(
          'هذا التصريح صادر لجهاز آخر.',
          reason: ActivationFailureReason.deviceMismatch,
        ),
      );

      final failure = await container
          .read(activationControllerProvider.notifier)
          .activateWithCode('x.y');

      expect(failure, isA<ActivationFailure>());
      expect(
        (failure! as ActivationFailure).reason,
        ActivationFailureReason.deviceMismatch,
      );
      expect(await currentState(), const NotActivated());
    });
  });

  group('renew', () {
    test('نجاح: يستبدل الحالة بالتصريح الجديد', () async {
      repo.loadResult = Ok(ActivationActive(_token(plan: 'basic')));
      await currentState();
      repo.renewResult = Ok(ActivationActive(_token(plan: 'pro')));

      final failure =
          await container.read(activationControllerProvider.notifier).renew();

      expect(failure, isNull);
      expect(await currentState(), ActivationActive(_token(plan: 'pro')));
    });

    test('فشل الشبكة: تبقى الحالة الحالية دون تغيير', () async {
      repo.loadResult = Ok(ActivationActive(_token(plan: 'basic')));
      await currentState();
      repo.renewResult = const Err(NetworkFailure());

      final failure =
          await container.read(activationControllerProvider.notifier).renew();

      expect(failure, isA<NetworkFailure>());
      expect(await currentState(), ActivationActive(_token(plan: 'basic')));
    });
  });

  group('clear', () {
    test('نجاح: يعيد قراءة الحالة من المستودع', () async {
      repo.loadResult = Ok(ActivationActive(_token()));
      await currentState();
      expect(repo.loadCalls, 1);

      repo.loadResult = const Ok(NotActivated());
      final failure =
          await container.read(activationControllerProvider.notifier).clear();

      expect(failure, isNull);
      expect(await currentState(), const NotActivated());
      expect(repo.loadCalls, 2);
    });

    test('فشل: يرجع السبب ولا يعيد التحميل', () async {
      repo.loadResult = Ok(ActivationActive(_token()));
      await currentState();
      repo.clearResult = const Err(DatabaseFailure());

      final failure =
          await container.read(activationControllerProvider.notifier).clear();

      expect(failure, isA<DatabaseFailure>());
      expect(await currentState(), ActivationActive(_token()));
      expect(repo.loadCalls, 1);
    });
  });

  group('استثناءات غير متوقعة', () {
    test('تتحول إلى UnexpectedFailure دون أن تنهار الحالة', () async {
      await currentState();
      repo.throwOnCall = StateError('boom');
      final notifier = container.read(activationControllerProvider.notifier);

      expect(await notifier.submitRequest(name: 'Ahmad'), isA<UnexpectedFailure>());
      expect(await notifier.refreshPending(), isA<UnexpectedFailure>());
      expect(await notifier.activateWithCode('x.y'), isA<UnexpectedFailure>());
      expect(await notifier.renew(), isA<UnexpectedFailure>());
      expect(await notifier.clear(), isA<UnexpectedFailure>());

      expect(await currentState(), const NotActivated());
    });

    test('FailureException المرمي يتحول إلى الـ Failure الذي يحمله', () async {
      await currentState();
      repo.throwOnCall = const FailureException(NetworkFailure());

      final failure = await container
          .read(activationControllerProvider.notifier)
          .submitRequest(name: 'Ahmad');

      expect(failure, isA<NetworkFailure>());
    });
  });
}