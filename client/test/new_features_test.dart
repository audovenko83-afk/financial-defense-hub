import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/widgets/stock_logo.dart';
import 'package:client/widgets/info_helper_sheet.dart';
import 'package:client/widgets/interactive_stock_chart.dart';

void main() {
  testWidgets('StockLogo renders clean widget for known ticker', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StockLogo(ticker: 'AAPL', size: 48),
        ),
      ),
    );

    expect(find.byType(StockLogo), findsOneWidget);
  });

  testWidgets('InfoButton displays icon and opens InfoHelperSheet on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoButton(topic: InfoTopic.millionGoal),
        ),
      ),
    );

    expect(find.byType(InfoButton), findsOneWidget);
    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();

    expect(find.text('Що це таке?'), findsOneWidget);
    expect(find.text('Чому це важливо?'), findsOneWidget);
    expect(find.text('ПОРАДА ДЛЯ НОВАЧКА'), findsOneWidget);
  });

  testWidgets('InteractiveStockChart renders points and timeframe controls', (tester) async {
    final points = [
      const ChartPoint(date: '2024-01-01', close: 100.0),
      const ChartPoint(date: '2024-01-02', close: 105.0),
      const ChartPoint(date: '2024-01-03', close: 110.0),
    ];

    String selectedRange = '1y';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveStockChart(
            points: points,
            selectedRange: selectedRange,
            onRangeChanged: (r) => selectedRange = r,
          ),
        ),
      ),
    );

    expect(find.text('5Д'), findsOneWidget);
    expect(find.text('1М'), findsOneWidget);
    expect(find.text('6М'), findsOneWidget);
    expect(find.text('1Р'), findsOneWidget);
    expect(find.text('5Р'), findsOneWidget);
    expect(find.text('\$110.00'), findsOneWidget);

    await tester.tap(find.text('1М'));
    await tester.pump();
    expect(selectedRange, '1mo');
  });
}
