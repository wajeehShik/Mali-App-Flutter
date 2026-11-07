import '../../../core/errors/failure.dart';
import '../domain/activation_remote_source.dart';

/// يعيد نص تصريح موقَّع للجهاز [deviceId]، أو null إن لم "يوافق المسؤول" بعد.
typedef MockTokenResolver = Future<String?> Function(String deviceId);

/// MOCK للتطوير والاختبار فقط. ليس خادمًا حقيقيًا ولا يتصل بأي شبكة.
///
/// يحاكي مسار التفعيل في الذاكرة:
/// - [submitRequest] ينشئ طلبًا معلَّقًا.
/// - [fetchRequestState] يبقى معلَّقًا لعدد [pollsBeforeDecision] من الاستعلامات،
///   ثم يرفض إن كان [rejectRequests] مفعّلًا، وإلا يسأل [tokenResolver]:
///   إن أعاد نصًا فالطلب "موافَق عليه"، وإن أعاد null يبقى معلَّقًا.
/// - لا يوقّع هذا الصنف شيئًا ولا يحمل مفتاحًا خاصًا؛ التصريح يجب أن يكون
///   موقَّعًا مسبقًا خارج التطبيق (tool/license_tool.dart).
///
/// يُستبدل بتنفيذ Dio الحقيقي عند بناء خادم Laravel (المرحلة 16).
class MockActivationRemoteSource implements ActivationRemoteSource {
  MockActivationRemoteSource({
    this.tokenResolver,
    this.pollsBeforeDecision = 2,
    this.rejectRequests = false,
    this.offline = false,
    this.latency = const Duration(milliseconds: 500),
  });

  final MockTokenResolver? tokenResolver;

  /// عدد الاستعلامات التي ترجع "معلَّق" قبل القرار.
  final int pollsBeforeDecision;

  /// عند true يُرفض كل طلب بعد انتهاء الاستعلامات المعلَّقة.
  final bool rejectRequests;

  /// عند true ترجع كل الدوال [NetworkFailure] (لمحاكاة انقطاع الإنترنت).
  final bool offline;

  /// زمن تأخير مصطنع. استخدم [Duration.zero] في الاختبارات.
  final Duration latency;

  final Map<String, _MockRequest> _requests = {};
  int _counter = 0;

  Future<void> _delay() {
    return latency == Duration.zero
        ? Future<void>.value()
        : Future<void>.delayed(latency);
  }

  @override
  Future<Result<ActivationRequestTicket>> submitRequest(
    ActivationApplicant applicant,
  ) async {
    await _delay();
    if (offline) {
      return const Err(NetworkFailure());
    }
    if (applicant.name.trim().isEmpty) {
      return const Err(
        ValidationFailure(
          'الاسم مطلوب.',
          fieldErrors: {'name': 'الاسم مطلوب.'},
        ),
      );
    }

    _counter += 1;
    final requestId = 'mock-request-$_counter';
    _requests[requestId] = _MockRequest(applicant.deviceId);
    return Ok(ActivationRequestTicket(requestId: requestId));
  }

  @override
  Future<Result<ActivationRequestState>> fetchRequestState({
    required String requestId,
    required String deviceId,
  }) async {
    await _delay();
    if (offline) {
      return const Err(NetworkFailure());
    }

    final request = _requests[requestId];
    if (request == null) {
      return const Err(NotFoundFailure('طلب التفعيل غير موجود.'));
    }
    if (request.deviceId != deviceId) {
      return const Err(
        ServerFailure('هذا الطلب يخص جهازًا آخر.', statusCode: 403),
      );
    }

    request.polls += 1;
    if (request.polls <= pollsBeforeDecision) {
      return const Ok(ActivationRequestState.pending());
    }
    if (rejectRequests) {
      return const Ok(
        ActivationRequestState.rejected('رُفض الطلب (Mock للتطوير).'),
      );
    }

    final resolver = tokenResolver;
    if (resolver == null) {
      return const Ok(ActivationRequestState.pending());
    }
    final token = await resolver(deviceId);
    if (token == null || token.trim().isEmpty) {
      return const Ok(ActivationRequestState.pending());
    }
    return Ok(ActivationRequestState.approved(token));
  }

  @override
  Future<Result<String>> renewToken({
    required String currentToken,
    required String deviceId,
  }) async {
    await _delay();
    if (offline) {
      return const Err(NetworkFailure());
    }

    final resolver = tokenResolver;
    final token = resolver == null ? null : await resolver(deviceId);
    if (token == null || token.trim().isEmpty) {
      return const Err(
        ServerFailure('لا يوجد تصريح متاح للتجديد (Mock).', statusCode: 404),
      );
    }
    return Ok(token);
  }
}

class _MockRequest {
  _MockRequest(this.deviceId);

  final String deviceId;
  int polls = 0;
}