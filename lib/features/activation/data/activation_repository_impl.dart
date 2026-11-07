import '../../../core/errors/failure.dart';
import '../../../core/storage/secure_storage.dart';
import '../domain/activation_remote_source.dart';
import '../domain/activation_repository.dart';
import '../domain/activation_state.dart';
import '../domain/activation_token.dart';
import '../domain/license_verifier.dart';
import 'device_identity.dart';

class ActivationRepositoryImpl implements ActivationRepository {
  ActivationRepositoryImpl({
    required SecureKeyValueStore store,
    required DeviceIdentityService identity,
    required LicenseVerifier verifier,
    required ActivationRemoteSource remote,
    DateTime Function()? clock,
  })  : _store = store,
        _identity = identity,
        _verifier = verifier,
        _remote = remote,
        _clock = clock ?? DateTime.now;

  /// أقصى تراجع مقبول للساعة (تفاوت عادي أو تغيير توقيت).
  static const int clockRollbackToleranceSeconds = 600;

  static const int _maxNameLength = 80;
  static const int _maxPhoneLength = 30;

  final SecureKeyValueStore _store;
  final DeviceIdentityService _identity;
  final LicenseVerifier _verifier;
  final ActivationRemoteSource _remote;
  final DateTime Function() _clock;

  @override
  Future<Result<String>> getDeviceId() async {
    final identity = await _identity.load();
    return identity.map((value) => value.deviceId);
  }

  @override
  Future<Result<ActivationState>> loadState() async {
    final identityResult = await _identity.load();
    final identityFailure = identityResult.failureOrNull;
    if (identityFailure != null) {
      return Err(identityFailure);
    }
    final deviceId = identityResult.unwrap().deviceId;

    final tokenRead = await _store.read(SecureKeys.activationToken);
    final tokenReadFailure = tokenRead.failureOrNull;
    if (tokenReadFailure != null) {
      return Err(tokenReadFailure);
    }

    final raw = tokenRead.valueOrNull;
    if (raw != null && raw.isNotEmpty) {
      final verified = await _verifier.verify(
        raw,
        deviceId: deviceId,
        allowExpired: true,
      );
      final token = verified.valueOrNull;
      if (token != null) {
        return Ok(await _stateForStoredToken(token));
      }
      // تصريح تالف أو لجهاز آخر: نحذفه ونتابع كأنه غير موجود.
      await _store.delete(SecureKeys.activationToken);
    }

    return _pendingOrNotActivated();
  }

  @override
  Future<Result<ActivationState>> submitRequest({
    required String name,
    String? phone,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phone?.trim();

    final errors = <String, String>{};
    if (cleanName.isEmpty) {
      errors['name'] = 'الاسم مطلوب.';
    } else if (cleanName.length > _maxNameLength) {
      errors['name'] = 'الاسم طويل جدًا.';
    }
    if (cleanPhone != null && cleanPhone.length > _maxPhoneLength) {
      errors['phone'] = 'رقم الهاتف طويل جدًا.';
    }
    if (errors.isNotEmpty) {
      return Err(
        ValidationFailure('تحقق من البيانات المدخلة.', fieldErrors: errors),
      );
    }

    final identityResult = await _identity.load();
    final identityFailure = identityResult.failureOrNull;
    if (identityFailure != null) {
      return Err(identityFailure);
    }
    final identity = identityResult.unwrap();

    final submitted = await _remote.submitRequest(
      ActivationApplicant(
        name: cleanName,
        phone: (cleanPhone == null || cleanPhone.isEmpty) ? null : cleanPhone,
        deviceId: identity.deviceId,
        deviceName: identity.deviceName,
      ),
    );
    final submitFailure = submitted.failureOrNull;
    if (submitFailure != null) {
      return Err(submitFailure);
    }

    final requestId = submitted.unwrap().requestId;
    final write = await _store.write(SecureKeys.pendingRequestId, requestId);
    final writeFailure = write.failureOrNull;
    if (writeFailure != null) {
      return Err(writeFailure);
    }
    return Ok(ActivationPending(requestId: requestId));
  }

  @override
  Future<Result<ActivationState>> refreshPending() async {
    final pendingRead = await _store.read(SecureKeys.pendingRequestId);
    final pendingFailure = pendingRead.failureOrNull;
    if (pendingFailure != null) {
      return Err(pendingFailure);
    }
    final requestId = pendingRead.valueOrNull;
    if (requestId == null || requestId.isEmpty) {
      return const Ok(NotActivated());
    }

    final identityResult = await _identity.load();
    final identityFailure = identityResult.failureOrNull;
    if (identityFailure != null) {
      return Err(identityFailure);
    }
    final deviceId = identityResult.unwrap().deviceId;

    final fetched = await _remote.fetchRequestState(
      requestId: requestId,
      deviceId: deviceId,
    );
    final fetchFailure = fetched.failureOrNull;
    if (fetchFailure != null) {
      return Err(fetchFailure);
    }

    final state = fetched.unwrap();
    switch (state.status) {
      case ActivationRequestStatus.pending:
        return Ok(ActivationPending(requestId: requestId));
      case ActivationRequestStatus.rejected:
        await _store.delete(SecureKeys.pendingRequestId);
        return Ok(NotActivated(rejectedMessage: state.message));
      case ActivationRequestStatus.approved:
        final raw = state.token;
        if (raw == null || raw.isEmpty) {
          return const Err(
            ServerFailure('رد الخادم غير صالح: لا يوجد تصريح مع الموافقة.'),
          );
        }
        return _acceptToken(raw, deviceId: deviceId, resetClockGuard: true);
    }
  }

  @override
  Future<Result<ActivationState>> activateWithCode(String code) async {
    final raw = code.trim();
    if (raw.isEmpty) {
      return const Err(
        ValidationFailure(
          'الصق رمز التفعيل أولًا.',
          fieldErrors: {'code': 'رمز التفعيل مطلوب.'},
        ),
      );
    }

    final identityResult = await _identity.load();
    final identityFailure = identityResult.failureOrNull;
    if (identityFailure != null) {
      return Err(identityFailure);
    }

    return _acceptToken(
      raw,
      deviceId: identityResult.unwrap().deviceId,
      resetClockGuard: false,
    );
  }

  @override
  Future<Result<ActivationState>> renew() async {
    final tokenRead = await _store.read(SecureKeys.activationToken);
    final tokenReadFailure = tokenRead.failureOrNull;
    if (tokenReadFailure != null) {
      return Err(tokenReadFailure);
    }
    final current = tokenRead.valueOrNull;
    if (current == null || current.isEmpty) {
      return const Err(
        ActivationFailure(
          'لا يوجد تفعيل لتجديده.',
          reason: ActivationFailureReason.notActivated,
        ),
      );
    }

    final identityResult = await _identity.load();
    final identityFailure = identityResult.failureOrNull;
    if (identityFailure != null) {
      return Err(identityFailure);
    }
    final deviceId = identityResult.unwrap().deviceId;

    final renewed = await _remote.renewToken(
      currentToken: current,
      deviceId: deviceId,
    );
    final renewFailure = renewed.failureOrNull;
    if (renewFailure != null) {
      return Err(renewFailure);
    }

    return _acceptToken(
      renewed.unwrap(),
      deviceId: deviceId,
      resetClockGuard: true,
    );
  }

  @override
  Future<Result<void>> clear() async {
    final tokenDelete = await _store.delete(SecureKeys.activationToken);
    final tokenFailure = tokenDelete.failureOrNull;
    if (tokenFailure != null) {
      return Err(tokenFailure);
    }
    final pendingDelete = await _store.delete(SecureKeys.pendingRequestId);
    final pendingFailure = pendingDelete.failureOrNull;
    if (pendingFailure != null) {
      return Err(pendingFailure);
    }
    // نبقي lastSeenAt عمدًا: مسح التفعيل لا يجوز أن يصفّر حماية الساعة.
    return const Ok<void>(null);
  }

  // ---------------------------------------------------------------------------

  /// يتحقق من [raw] (غير منتهٍ)، ثم يخزّنه ويصفّي الطلب المعلَّق.
  Future<Result<ActivationState>> _acceptToken(
    String raw, {
    required String deviceId,
    required bool resetClockGuard,
  }) async {
    final verified = await _verifier.verify(raw, deviceId: deviceId);
    final verifyFailure = verified.failureOrNull;
    if (verifyFailure != null) {
      return Err(verifyFailure);
    }
    final token = verified.unwrap();

    final write = await _store.write(SecureKeys.activationToken, raw);
    final writeFailure = write.failureOrNull;
    if (writeFailure != null) {
      return Err(writeFailure);
    }
    await _store.delete(SecureKeys.pendingRequestId);

    final now = _nowSeconds();
    if (resetClockGuard) {
      await _writeLastSeen(now);
    } else {
      final lastSeen = await _readLastSeen();
      if (lastSeen == null || now > lastSeen) {
        await _writeLastSeen(now);
      }
    }
    return Ok(ActivationActive(token));
  }

  Future<ActivationState> _stateForStoredToken(ActivationToken token) async {
    final now = _nowSeconds();
    final lastSeen = await _readLastSeen();

    final rolledBack =
        lastSeen != null && now < lastSeen - clockRollbackToleranceSeconds;
    if (!rolledBack && (lastSeen == null || now > lastSeen)) {
      await _writeLastSeen(now);
    }

    if (rolledBack || token.isExpiredAt(_clock())) {
      return ActivationExpired(token);
    }
    return ActivationActive(token);
  }

  Future<Result<ActivationState>> _pendingOrNotActivated() async {
    final pendingRead = await _store.read(SecureKeys.pendingRequestId);
    final pendingFailure = pendingRead.failureOrNull;
    if (pendingFailure != null) {
      return Err(pendingFailure);
    }
    final requestId = pendingRead.valueOrNull;
    if (requestId != null && requestId.isNotEmpty) {
      return Ok(ActivationPending(requestId: requestId));
    }
    return const Ok(NotActivated());
  }

  int _nowSeconds() => _clock().toUtc().millisecondsSinceEpoch ~/ 1000;

  /// قراءة بأفضل جهد: الفشل أو القيمة التالفة تُعامل كأنها غير موجودة.
  Future<int?> _readLastSeen() async {
    final read = await _store.read(SecureKeys.lastSeenAt);
    final text = read.valueOrNull;
    return text == null ? null : int.tryParse(text);
  }

  /// كتابة بأفضل جهد: فشلها لا يُفشل العملية الأصلية.
  Future<void> _writeLastSeen(int seconds) async {
    await _store.write(SecureKeys.lastSeenAt, seconds.toString());
  }
}