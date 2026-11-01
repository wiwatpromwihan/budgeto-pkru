import 'package:budgeto/budget.dart';
import 'package:budgeto/gold_price.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses Thai Gold API and rounds valuation to satang', () {
    final price = GoldPrice.fromJson({
      'response': {
        'update_date': '31/10/2569',
        'update_time': 'เวลา 09:12 น.',
        'price': {
          'gold_bar': {'buy': '62,000.00', 'sell': '62,200.00'},
        },
      },
    });
    expect(price.buySatang, 6200000);
    expect(price.sellSatang, 6220000);
    expect(price.estimateSatang(1), 620);
    expect(price.estimateSatang(12345), 7653900);
  });
  test('weight has four decimal places', () {
    expect(parseWeightUnits('0.0001'), 1);
    expect(parseWeightUnits('1.23456'), isNull);
  });
  test('cash rolls across months and rejects edits that overspend', () {
    var cash = nextCashBalance(0, newSavings: 100000);
    cash = nextCashBalance(cash, newSavings: 20000);
    cash = nextCashBalance(cash, newGoldCost: 60000);
    expect(cash, 60000);
    expect(() => nextCashBalance(cash, oldSavings: 100000), throwsStateError);
    cash = nextCashBalance(cash, oldGoldCost: 60000, newGoldCost: 40000);
    expect(cash, 80000);
    cash = nextCashBalance(cash, oldGoldCost: 40000);
    expect(cash, 120000);
  });
  test('API failure throws and success is cached', () async {
    var calls = 0;
    final api = GoldPriceApi(
      client: MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('error', 503);
        return http.Response(
          '{"status":"success","response":{"update_date":"1/11/2569","update_time":"10:00","price":{"gold_bar":{"buy":"62,000.00","sell":"62,200.00"}}}}',
          200,
        );
      }),
    );
    await expectLater(api.latest(), throwsStateError);
    final value = await api.latest();
    expect(value.buySatang, 6200000);
    expect((await api.latest()).buySatang, 6200000);
    expect(calls, 2);
    api.close();
  });
}
