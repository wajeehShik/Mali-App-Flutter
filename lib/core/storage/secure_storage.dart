import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../errors/failure.dart';

/// مفاتيح التخزين الآمن. المصدر الوحيد لها في المشروع.
abstract final class SecureKeys {
  /// نص تصريح التفعيل الموقَّع (payload.signature).
  static const String activationToken = 'activation_token';

  /// معرّف هذا التثبيت (UUID عشوائي يُولَّد مرة واحدة).
  static const String deviceId = 'device_id';

  /// آخر وقت شوهد (ثوانٍ Unix)، لكشف التراجع بساعة الجهاز.
  static const String lastSeenAt = 'last_seen_at';

  /// معرّف طلب التفعيل المعلَّق لدى الخادم.
  static const String pendingRequestId = 'pending_request_id';
}

/// تخزين مفتاح/قيمة نصية للبيانات الحساسة.
/// الواجهة مجردة ليُستبدل تنفيذها في الاختبارات.
abstract interface class SecureKeyValueStore {
  Future<Result<String?>> read(String key);

  Future<Result<void>> write(String key, String value);

  Future<Result<void>> delete(String key);
}

/// التنفيذ الحقيقي: Keychain على iOS، وKeystore على Android.
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  static const Failure _failure = UnexpectedFailure(
    'تعذّر الوصول إلى التخزين الآمن على الجهاز.',
  );

  @override
  Future<Result<String?>> read(String key) {
    return guardAsync(
      () => _storage.read(key: key),
      onError: (e) => UnexpectedFailure(_failure.message, e),
    );
  }

  @override
  Future<Result<void>> write(String key, String value) {
    return guardAsync(
      () => _storage.write(key: key, value: value),
      onError: (e) => UnexpectedFailure(_failure.message, e),
    );
  }

  @override
  Future<Result<void>> delete(String key) {
    return guardAsync(
      () => _storage.delete(key: key),
      onError: (e) => UnexpectedFailure(_failure.message, e),
    );
  }
}