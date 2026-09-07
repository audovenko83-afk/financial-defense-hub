import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:client/main.dart';
import 'package:client/screens/portfolio_screen.dart';
import 'package:client/screens/simulator_screen.dart';
import 'package:client/screens/history_screen.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Показує екран входу', (WidgetTester tester) async {
    await tester.pumpWidget(const MillionDollarWayApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Фінансовий Захист'), findsOneWidget);
    expect(find.text('Увійти'), findsOneWidget);
  });
  testWidgets('Показує екран портфеля', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PortfolioScreen(token: 'fake-token'),
      ),
    );
    await tester.pump();
  });

  testWidgets('Показує екран симулятора', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SimulatorScreen(token: 'fake-token'),
      ),
    );
    await tester.pump();
  });

  testWidgets('Показує екран історії', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryScreen(token: 'fake-token'),
      ),
    );
    await tester.pump();
  });

}

