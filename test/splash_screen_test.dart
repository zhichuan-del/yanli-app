import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/splash_screen.dart';

void main() {
  testWidgets('启动时拉伸图片铺满屏幕，时间到自动进入首页', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(
          duration: Duration(milliseconds: 1600),
          child: Text('日历首页'),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/launch.jpg');
    expect(image.fit, BoxFit.fill);
    expect(find.text('日历首页'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1599));
    expect(find.text('日历首页'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('日历首页'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('启动期间离开页面会取消计时，不产生异常', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(child: Text('首页'))),
    );
    await tester.pumpWidget(const MaterialApp(home: Text('其他页面')));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('其他页面'), findsOneWidget);
  });
}
