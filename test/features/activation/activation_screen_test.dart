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
  Future<void> pumpActivationScreen(WidgetTester tester) async {
    // مساحة كافية لعرض عناصر الشاشة دون تمرير داخل الاختبار.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    expect(find.text('تفعيل الرمز'), findsOneWidget);
  });

  testWidgets('يعرض خطأ الاسم عند إرسال النموذج فارغًا', (tester) async {
    await pumpActivationScreen(tester);

    await tester.tap(find.text('إرسال طلب التفعيل'));
    await tester.pumpAndSettle();

    expect(find.text('الاسم مطلوب.'), findsOneWidget);
  });
}
