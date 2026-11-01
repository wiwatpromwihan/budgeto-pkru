import 'package:budgeto/budget.dart';
import 'package:budgeto/gold_history.dart';
import 'package:budgeto/gold_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses historical buy-back prices in satang', () {
    final rows = parseGoldHistory('''{"data":[
      {"date":"2026-10-30","buy":62000.50},
      {"date":"2026-10-31","buy":62100.00}
    ]}''');
    expect(rows.map((e) => e.buySatang), [6200050, 6210000]);
  });

  test(
    'portfolio uses actual holdings on each priced day and latest quote',
    () {
      final purchases = [
        const GoldPurchase(
          id: 'a',
          gramsUnits: 152440,
          costSatang: 6000000,
          date: '2026-10-29',
          note: '',
        ),
        const GoldPurchase(
          id: 'b',
          gramsUnits: 152440,
          costSatang: 6100000,
          date: '2026-10-31',
          note: '',
        ),
      ];
      final points = portfolioHistory(
        history: const [
          DailyGoldPrice('2026-10-30', 6200000),
          DailyGoldPrice('2026-11-01', 6200000),
        ],
        purchases: purchases,
        days: 7,
        now: DateTime(2026, 11, 1),
        latest: const GoldPrice(
          buySatang: 6300000,
          sellSatang: 6320000,
          updateDate: '1/11/2569',
          updateTime: '10:00',
        ),
      );
      expect(points.length, 2); // Missing October 31 is not filled in.
      expect(points.first.valueSatang, 6200000);
      expect(points.first.costSatang, 6000000);
      expect(points.last.valueSatang, 12600000);
      expect(points.last.costSatang, 12100000);
      expect(points.last.isLatest, isTrue);
    },
  );

  test('editing an old purchase recomputes historic cost and weight', () {
    final original = [
      const GoldPurchase(
        id: 'a',
        gramsUnits: 152440,
        costSatang: 6000000,
        date: '2026-10-30',
        note: '',
      ),
    ];
    final edited = [
      const GoldPurchase(
        id: 'a',
        gramsUnits: 304880,
        costSatang: 12000000,
        date: '2026-10-30',
        note: '',
      ),
    ];
    const history = [DailyGoldPrice('2026-10-31', 6200000)];
    final before = portfolioHistory(
      history: history,
      purchases: original,
      days: 7,
      now: DateTime(2026, 11, 1),
    );
    final after = portfolioHistory(
      history: history,
      purchases: edited,
      days: 7,
      now: DateTime(2026, 11, 1),
    );
    expect(after.single.valueSatang, before.single.valueSatang * 2);
    expect(after.single.costSatang, before.single.costSatang * 2);
  });
}
