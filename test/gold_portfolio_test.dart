import 'package:budgeto/budget.dart';
import 'package:budgeto/gold_history.dart';
import 'package:budgeto/gold_portfolio.dart';
import 'package:budgeto/gold_price.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('one portfolio date explains why there is no trend line', (
    tester,
  ) async {
    await initializeDateFormatting('th');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GoldPortfolio(
              purchases: [
                GoldPurchase(
                  id: 'a',
                  gramsUnits: 152440,
                  costSatang: 6000000,
                  date: today,
                  note: '',
                ),
              ],
              cash: 0,
              price: const GoldPrice(
                buySatang: 6200000,
                sellSatang: 6220000,
                updateDate: '',
                updateTime: '',
              ),
              history: [DailyGoldPrice(today, 6200000)],
              historyError: false,
              historyLoading: false,
              days: 30,
              onDaysChanged: (_) {},
              onRetry: () {},
              onOpenSource: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('ยังไม่มีแนวโน้ม'), findsOneWidget);
  });
}
