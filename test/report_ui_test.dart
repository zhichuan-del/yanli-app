import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/main.dart';

void main() {
  testWidgets('汇报页面提供自选日期并可查看记录来源', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      YanliApp(prefs: await SharedPreferences.getInstance()),
    );
    await tester.tap(find.text('周报'));
    await tester.pumpAndSettle();
    expect(find.text('自选日期'), findsOneWidget);
    expect(find.text('查看来源'), findsOneWidget);
  });
}
