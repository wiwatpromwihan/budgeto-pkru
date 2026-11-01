import 'package:budgeto/gold_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses Thai gold sell close and buy-back separately', () {
    final rows = parseGoldHistory('''{"data":[
      {"date":"2026-10-31","buy":62000.00,"close":62200.50},
      {"date":"2026-10-30","buy":62100.00,"close":62300.00}
    ]}''');
    expect(rows.map((e) => e.date), ['2026-10-30', '2026-10-31']);
    expect(rows.last.buySatang, 6200000);
    expect(rows.last.sellSatang, 6220050);
  });

  test('requests daily year and monthly five-year series', () async {
    final uris = <Uri>[];
    final api = GoldHistoryApi(
      clock: () => DateTime(2026, 11, 1),
      client: MockClient((request) async {
        uris.add(request.url);
        return http.Response(
          '{"data":[{"date":"2026-11-01","buy":62050,"close":62250}]}',
          200,
        );
      }),
    );
    await api.history(GoldChartRange.year);
    await api.history(GoldChartRange.fiveYears);
    expect(uris[0].queryParameters['from'], '2025-11-01');
    expect(uris[0].queryParameters['interval'], 'day');
    expect(uris[1].queryParameters['from'], '2021-11-01');
    expect(uris[1].queryParameters['interval'], 'month');
    await api.history(GoldChartRange.year);
    expect(uris.length, 2); // Cached by range.
    api.close();
  });
}
