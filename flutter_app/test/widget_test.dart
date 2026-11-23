import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('Dashboard renders fetch button', (WidgetTester tester) async {
    await tester.pumpWidget(const CryptoDataMonitorApp());

    expect(find.text('BTC Market Data'), findsOneWidget);
    expect(find.text('FETCH BTC DATA'), findsOneWidget);
  });
}
