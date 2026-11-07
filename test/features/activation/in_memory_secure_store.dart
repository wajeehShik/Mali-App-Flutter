import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/storage/secure_storage.dart';

/// مخزن آمن وهمي في الذاكرة للاختبارات فقط.
class InMemorySecureStore implements SecureKeyValueStore {
  InMemorySecureStore([Map<String, String>? initial])
      : values = {...?initial};

  /// المحتوى الحالي. متاح للفحص والتعديل المباشر في الاختبارات.
  final Map<String, String> values;

  /// فعّلها لإجبار العملية المقابلة على الفشل.
  bool failReads = false;
  bool failWrites = false;
  bool failDeletes = false;

  /// عدد مرات الكتابة الناجحة لمفتاح معيّن (لإثبات أن المعرّف يُولَّد مرة واحدة).
  final Map<String, int> writeCounts = {};

  static const Failure _failure = UnexpectedFailure(
    'فشل مخزن الاختبار (متعمَّد).',
  );

  @override
  Future<Result<String?>> read(String key) async {
    if (failReads) {
      return const Err(_failure);
    }
    return Ok(values[key]);
  }

  @override
  Future<Result<void>> write(String key, String value) async {
    if (failWrites) {
      return const Err(_failure);
    }
    values[key] = value;
    writeCounts[key] = (writeCounts[key] ?? 0) + 1;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> delete(String key) async {
    if (failDeletes) {
      return const Err(_failure);
    }
    values.remove(key);
    return const Ok<void>(null);
  }
}