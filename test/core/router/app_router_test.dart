import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mali/core/router/app_router.dart';
import 'package:mali/core/router/app_routes.dart';
import 'package:mali/features/activation/domain/activation_state.dart';
import 'package:mali/features/activation/domain/activation_token.dart';
import 'package:mali/features/activation/presentation/activation_providers.dart';
import 'package:mali/features/activation/presentation/activation_screen.dart';

final ActivationToken _testToken = ActivationToken(
  userId: 'user-1',
  deviceId: 'test-device-id',
  plan: 'pro',
  issuedAt: DateTime.utc(2026, 11, 6),
  expiresAt: DateTime.utc(2026, 12, 7),
);

class _TestActivationController extends ActivationController {
  _TestActivationController(this.initialState);

  final ActivationState initialState;

  @override
  Future<ActivationState> build() async => initialState;
}

class _TestRouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _RouterSetup {
  const _RouterSetup({
    required this.container,
    required this.router,
    required this.refresh,
  });

  final ProviderContainer container;
  final GoRouter router;
  final _TestRouterRefresh refresh;

  void dispose() {
    router.dispose();
    refresh.dispose();
    container.dispose();
  }
}

Future<_RouterSetup> _pumpRouter(
  WidgetTester tester, {
  required ActivationState activationState,
}) async {
  final container = ProviderContainer(
    overrides: [
      activationControllerProvider.overrideWith(
        () => _TestActivationController(activationState),
      ),
      deviceIdProvider.overrideWith((ref) async => 'test-device-id'),
    ],
  );

  // ننتظر تحميل الحالة قبل إنشاء الراوتر ليكون اختبار redirect حتميًا.
  await container.read(activationControllerProvider.future);

  final refresh = _TestRouterRefresh();
  final router = createAppRouter(
    readActivationState: () =>
        container.read(activationControllerProvider).value,
    refreshListenable: refresh,
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return _RouterSetup(
    container: container,
    router: router,
    refresh: refresh,
  );
}

void main() {
  testWidgets('غير المفعّل يُوجّه إلى شاشة التفعيل', (tester) async {
    final setup = await _pumpRouter(
      tester,
      activationState: const NotActivated(),
    );
    addTearDown(setup.dispose);

    expect(
      setup.router.routeInformationProvider.value.uri.path,
      AppRoutes.activation,
    );
    expect(find.byType(ActivationScreen), findsOneWidget);
  });

  testWidgets('المفعّل يُوجّه بعيدًا عن شاشة التفعيل', (tester) async {
    final setup = await _pumpRouter(
      tester,
      activationState: ActivationActive(_testToken),
    );
    addTearDown(setup.dispose);

    setup.router.go(AppRoutes.activation);
    await tester.pumpAndSettle();

    expect(
      setup.router.routeInformationProvider.value.uri.path,
      AppRoutes.dashboard,
    );
  });

  testWidgets('المنتهي يُسمح له بالنسخ الاحتياطي ويُمنع من المبيعات',
      (tester) async {
    final setup = await _pumpRouter(
      tester,
      activationState: ActivationExpired(_testToken),
    );
    addTearDown(setup.dispose);

    setup.router.go(AppRoutes.backup);
    await tester.pumpAndSettle();

    expect(
      setup.router.routeInformationProvider.value.uri.path,
      AppRoutes.backup,
    );

    setup.router.go(AppRoutes.sales);
    await tester.pumpAndSettle();

    expect(
      setup.router.routeInformationProvider.value.uri.path,
      AppRoutes.dashboard,
    );
  });
}
