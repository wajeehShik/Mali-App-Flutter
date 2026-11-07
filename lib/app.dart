import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/activation/presentation/activation_providers.dart';

/// جذر تطبيق مالي: عربي، RTL، ثيم فاتح، تنقل عبر GoRouter.
class MaliApp extends ConsumerStatefulWidget {
  const MaliApp({super.key});

  @override
  ConsumerState<MaliApp> createState() => _MaliAppState();
}

class _MaliAppState extends ConsumerState<MaliApp> {
  late final _RouterRefreshListenable _routerRefresh;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _routerRefresh = _RouterRefreshListenable();
    _router = createAppRouter(
      readActivationState: () =>
          ref.read(activationControllerProvider).value,
      refreshListenable: _routerRefresh,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _routerRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // يضمن بدء تحميل حالة التفعيل عند تشغيل التطبيق.
    ref.watch(activationControllerProvider);

    // يعيد تقييم redirect في GoRouter عند تغير حالة التفعيل.
    ref.listen(activationControllerProvider, (previous, next) {
      _routerRefresh.notify();
    });

    return MaterialApp.router(
      title: 'مالي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

class _RouterRefreshListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}
