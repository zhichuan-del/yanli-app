import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/main.dart';
import 'package:yanli_app/main.dart' as app;
import 'package:yanli_app/splash_screen.dart';

void main() {
  testWidgets('真实入口所有平台含 Web 展示学校原图，650ms 自动进入日历', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await app.main();
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(
      (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName,
      'assets/launch.jpg',
    );
    expect(find.byType(HomePage), findsNothing);
    await tester.pump(const Duration(milliseconds: 649));
    expect(find.byType(HomePage), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('减少动态效果下启动图结束无额外过渡', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs, showSplash: true));
    final context = tester.element(find.byType(SplashScreen));
    // Widget tests use the platform's reduced motion setting here.
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await tester.pump();
    expect(MediaQuery.disableAnimationsOf(context), isTrue);
    expect(
      find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byType(AnimatedSwitcher),
      ),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
