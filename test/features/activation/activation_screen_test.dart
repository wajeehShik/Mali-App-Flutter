import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/features/activation/domain/activation_state.dart';
import 'package:mali/features/activation/presentation/activation_providers.dart';
import 'package:mali/features/activation/presentation/activation_screen.dart';

class _TestActivationController extends ActivationController {
  @override
  Future<ActivationState> build() async => const NotActivated();
}

void main() {
  final listScrollable = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );

  Future<void> pumpActivationScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activationControllerProvider.overrideWith(
            _TestActivationController.new,
          ),
          deviceIdProvider.overrideWith(
            (ref) async => 'test-device-id-1234',
          ),
        ],
        child: const MaterialApp(
          home: ActivationScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('يعرض شاشة التفعيل ومعرّف الجهاز', (tester) async {
    await pumpActivationScreen(tester);

    expect(find.text('تفعيل مالي'), findsOneWidget);
    expect(find.text('test-device-id-1234'), findsOneWidget);
    expect(find.text('إرسال طلب التفعيل'), findsOneWidget);

    final manualActivationButton = find.text('تفعيل الرمز');
    await tester.scrollUntilVisible(
      manualActivationButton,
      300,
      scrollable: listScrollable,
    );

    expect(manualActivationButton, findsOneWidget);
  });

  testWidgets('يعرض خطأ الاسم عند إرسال النموذج فارغًا', (tester) async {
    await pumpActivationScreen(tester);

    final submitButton = find.text('إرسال طلب التفعيل');
    await tester.scrollUntilVisible(
      submitButton,
      300,
      scrollable: listScrollable,
    );
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('الاسم مطلوب.'), findsOneWidget);
  });
}
