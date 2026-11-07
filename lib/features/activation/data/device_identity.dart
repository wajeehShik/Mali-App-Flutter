import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failure.dart';
import '../../../core/storage/secure_storage.dart';

/// هوية هذا التثبيت لدى خادم التفعيل.
@immutable
final class DeviceIdentity {
  const DeviceIdentity({required this.deviceId, required this.deviceName});

  /// UUID عشوائي ثابت لهذا التثبيت. يدخل في التحقق من التصريح.
  final String deviceId;

  /// اسم للعرض فقط (يراه المسؤول عند مراجعة الطلب). لا يدخل في التحقق.
  final String deviceName;

  @override
  bool operator ==(Object other) =>
      other is DeviceIdentity &&
      other.deviceId == deviceId &&
      other.deviceName == deviceName;

  @override
  int get hashCode => Object.hash(deviceId, deviceName);

  @override
  String toString() => 'DeviceIdentity($deviceName)';
}

/// مصدر اسم الجهاز. واجهة مجردة لتسهيل الاختبار.
abstract interface class DeviceNameSource {
  Future<String> name();
}

/// يقرأ اسم الجهاز من النظام. أي فشل يرجع اسمًا احتياطيًا ولا يرمي.
class PlatformDeviceNameSource implements DeviceNameSource {
  PlatformDeviceNameSource([DeviceInfoPlugin? plugin])
      : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  static const String fallback = 'جهاز غير معروف';
  static const int _maxLength = 60;

  @override
  Future<String> name() async {
    try {
      if (kIsWeb) {
        return 'متصفح الويب';
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await _plugin.androidInfo;
          return _join([info.brand, info.model]);
        case TargetPlatform.iOS:
          final info = await _plugin.iosInfo;
          return _join([info.model]);
        case TargetPlatform.windows:
          final info = await _plugin.windowsInfo;
          return _join([info.computerName]);
        case TargetPlatform.macOS:
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          return fallback;
      }
    } catch (_) {
      return fallback;
    }
  }

  static String _join(List<String> parts) {
    final text = parts
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(' ');
    if (text.isEmpty) {
      return fallback;
    }
    return text.length > _maxLength ? text.substring(0, _maxLength) : text;
  }
}

/// يوفّر هوية الجهاز، ويولّد معرّفًا ويخزّنه عند أول استخدام.
class DeviceIdentityService {
  DeviceIdentityService({
    required SecureKeyValueStore store,
    required DeviceNameSource nameSource,
    String Function()? idGenerator,
  })  : _store = store,
        _nameSource = nameSource,
        _idGenerator = idGenerator ?? (() => const Uuid().v4());

  /// أقصر معرّف مخزَّن نقبله كصالح.
  static const int _minIdLength = 8;

  final SecureKeyValueStore _store;
  final DeviceNameSource _nameSource;
  final String Function() _idGenerator;

  DeviceIdentity? _cached;
  Future<Result<DeviceIdentity>>? _inFlight;

  /// يرجع الهوية (من الذاكرة أو التخزين أو يولّدها). الفشل يرجع [Err] دون معرّف مؤقت.
  Future<Result<DeviceIdentity>> load() {
    final cached = _cached;
    if (cached != null) {
      return Future.value(Ok(cached));
    }
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  Future<Result<DeviceIdentity>> _load() async {
    final read = await _store.read(SecureKeys.deviceId);
    final readFailure = read.failureOrNull;
    if (readFailure != null) {
      return Err(readFailure);
    }

    var id = read.valueOrNull?.trim();
    if (id == null || id.length < _minIdLength) {
      id = _idGenerator();
      final write = await _store.write(SecureKeys.deviceId, id);
      final writeFailure = write.failureOrNull;
      if (writeFailure != null) {
        return Err(writeFailure);
      }
    }

    final identity = DeviceIdentity(
      deviceId: id,
      deviceName: await _nameSource.name(),
    );
    _cached = identity;
    return Ok(identity);
  }
}