import 'package:epsilon/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the auth screen', (tester) async {
    SharedPreferences.setMockInitialValues({'epsilon_onboarding_seen': true});

    await tester.pumpWidget(
      const EpsilonApp(backendStatus: BackendBootstrap(isReady: false)),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('رقم الهاتف'), findsWidgets);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.text('نتائج المسابقات الوطنية'), findsNothing);
    expect(find.text('Google'), findsNothing);
    expect(find.text('Facebook'), findsNothing);
    expect(find.text('Apple'), findsNothing);
    expect(find.text('إنشاء حساب'), findsOneWidget);
  });
}
