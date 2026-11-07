import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/activation_repository_impl.dart';
import '../data/device_identity.dart';
import '../data/mock_activation_remote_source.dart';
import '../domain/activation_remote_source.dart';
import '../domain/activation_repository.dart';
import '../domain/activation_state.dart';
import '../domain/license_verifier.dart';

/// مسار المفتاح العام المضمَّن (ملف assets/keys/license_public_key.txt).
const String licensePublicKeyAsset = 'assets/keys/license_public_key.txt';

final secureStoreProvider = Provider<SecureKeyValueStore>(
  (ref) => const FlutterSecureKeyValueStore(),
);

final deviceIdentityServiceProvider = Provider<DeviceIdentityService>(
  (ref) => DeviceIdentityService(
    store: ref.watch(secureStoreProvider),
    nameSource: PlatformDeviceNameSource(),
  ),
);

/// يحمّل المفتاح العام من الأصول وينشئ المحقِّق. المفتاح الخاص غير موجود في التطبيق.
final licenseVerifierProvider = FutureProvider<LicenseVerifier>((ref) async {
  final encoded = await rootBundle.loadString(licensePublicKeyAsset);
  return LicenseVerifier.fromEncodedKey(encoded).unwrap();
});

/// مصدر الخادم: Mock في التطوير فقط، وغير متاح في النسخة النهائية.
/// يُستبدل بتنفيذ Dio الحقيقي عند بناء Laravel (المرحلة 16).
final activationRemoteSourceProvider = Provider<ActivationRemoteSource>(
  (ref) {
    if (kDebugMode) {
      return MockActivationRemoteSource();
    }
    return const _UnavailableActivationRemoteSource();
  },
);

final activationRepositoryProvider = FutureProvider<ActivationRepository>(
  (ref) async {
    final verifier = await ref.watch(licenseVerifierProvider.future);
    return ActivationRepositoryImpl(
      store: ref.watch(secureStoreProvider),
      identity: ref.watch(deviceIdentityServiceProvider),
      verifier: verifier,
      remote: ref.watch(activationRemoteSourceProvider),
    );
  },
);

/// معرّف هذا الجهاز للعرض (ليُنسخ ويُوقَّع له تصريح يدويًا).
final deviceIdProvider = FutureProvider<String>((ref) async {
  final repo = await ref.watch(activationRepositoryProvider.future);
  return repo.getDeviceId().then((result) => result.unwrap());
});

/// حالة التفعيل الحالية. التحميل الأول يقرأ التخزين دون إنترنت.
final activationControllerProvider =
    AsyncNotifierProvider<ActivationController, ActivationState>(
  ActivationController.new,
);

class ActivationController extends AsyncNotifier<ActivationState> {
  @override
  Future<ActivationState> build() async {
    final repo = await ref.watch(activationRepositoryProvider.future);
    final result = await repo.loadState();
    return result.fold<ActivationState>(
      (value) => value,
      (failure) => throw FailureException(failure),
    );
  }

  /// يعيد قراءة الحالة من التخزين.
  void reload() => ref.invalidateSelf();

  /// يرسل طلب تفعيل. يرجع null عند النجاح أو سبب الفشل.
  Future<Failure?> submitRequest({required String name, String? phone}) {
    return _run((repo) => repo.submitRequest(name: name, phone: phone));
  }

  /// يستعلم عن الطلب المعلَّق.
  Future<Failure?> refreshPending() => _run((repo) => repo.refreshPending());

  /// تفعيل يدوي برمز موقَّع.
  Future<Failure?> activateWithCode(String code) {
    return _run((repo) => repo.activateWithCode(code));
  }

  /// تجديد التصريح (يحتاج إنترنت).
  Future<Failure?> renew() => _run((repo) => repo.renew());

  /// يمسح التفعيل والطلب المعلَّق (لا يمس بيانات العمل).
  Future<Failure?> clear() async {
    try {
      final repo = await ref.read(activationRepositoryProvider.future);
      final result = await repo.clear();
      final failure = result.failureOrNull;
      if (failure != null) {
        return failure;
      }
      if (ref.mounted) {
        ref.invalidateSelf();
      }
      return null;
    } on FailureException catch (e) {
      return e.failure;
    } catch (e) {
      return UnexpectedFailure('حدث خطأ غير متوقع. حاول مرة أخرى.', e);
    }
  }

  Future<Failure?> _run(
    Future<Result<ActivationState>> Function(ActivationRepository repo) action,
  ) async {
    try {
      final repo = await ref.read(activationRepositoryProvider.future);
      final result = await action(repo);
      return result.fold<Failure?>(
        (newState) {
          if (ref.mounted) {
            state = AsyncData(newState);
          }
          return null;
        },
        (failure) => failure,
      );
    } on FailureException catch (e) {
      return e.failure;
    } catch (e) {
      return UnexpectedFailure('حدث خطأ غير متوقع. حاول مرة أخرى.', e);
    }
  }
}

/// بديل النسخة النهائية قبل وجود الخادم: يرفض كل شيء برسالة صريحة.
class _UnavailableActivationRemoteSource implements ActivationRemoteSource {
  const _UnavailableActivationRemoteSource();

  static const Failure _failure = NetworkFailure(
    'خدمة التفعيل عبر الإنترنت غير متاحة بعد. استخدم رمز التفعيل اليدوي.',
  );

  @override
  Future<Result<ActivationRequestTicket>> submitRequest(
    ActivationApplicant applicant,
  ) async {
    return const Err(_failure);
  }

  @override
  Future<Result<ActivationRequestState>> fetchRequestState({
    required String requestId,
    required String deviceId,
  }) async {
    return const Err(_failure);
  }

  @override
  Future<Result<String>> renewToken({
    required String currentToken,
    required String deviceId,
  }) async {
    return const Err(_failure);
  }
}