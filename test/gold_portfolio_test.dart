import 'package:budgeto/gold_history.dart';
import 'package:budgeto/gold_portfolio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('market price chart appears even without gold purchases', (
    tester,
  ) async {
    await initializeDateFormatting('th');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GoldPortfolio(
              purchases: const [],
              cash: 0,
              price: null,
              history: const [
                DailyGoldPrice('2026-10-31', 6200000, sellSatang: 6220000),
                DailyGoldPrice('2026-11-01', 6205000, sellSatang: 6225000),
              ],
              historyError: false,
              historyLoading: false,
              range: GoldChartRange.year,
              onRangeChanged: (_) {},
              onRetry: () {},
              onOpenSource: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('กราฟราคาทองไทย'), findsOneWidget);
    expect(find.textContaining('62,250'), findsOneWidget);
    expect(find.text('1Y'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
