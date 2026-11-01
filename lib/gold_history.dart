import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

enum GoldChartRange {
  week('7D'),
  month('1M'),
  threeMonths('3M'),
  sixMonths('6M'),
  year('1Y'),
  fiveYears('5Y'),
  tenYears('10Y'),
  all('MAX');

  const GoldChartRange(this.label);
  final String label;

  bool get monthly => index >= GoldChartRange.fiveYears.index;

  DateTime start(DateTime now) => switch (this) {
    GoldChartRange.week => now.subtract(const Duration(days: 6)),
    GoldChartRange.month => DateTime(now.year, now.month - 1, now.day),
    GoldChartRange.threeMonths => DateTime(now.year, now.month - 3, now.day),
    GoldChartRange.sixMonths => DateTime(now.year, now.month - 6, now.day),
    GoldChartRange.year => DateTime(now.year - 1, now.month, now.day),
    GoldChartRange.fiveYears => DateTime(now.year - 5, now.month, now.day),
    GoldChartRange.tenYears => DateTime(now.year - 10, now.month, now.day),
    GoldChartRange.all => DateTime(2007, 1, 3),
  };
}

class DailyGoldPrice {
  const DailyGoldPrice(this.date, this.buySatang, {this.sellSatang = 0});
  final String date;
  final int buySatang;
  final int sellSatang;
}

List<DailyGoldPrice> parseGoldHistory(String body) {
  final root = jsonDecode(body) as Map<String, dynamic>;
  final rows = root['data'] as List<dynamic>;
  final result = <DailyGoldPrice>[];
  for (final raw in rows) {
    final row = raw as Map<String, dynamic>;
    final date = row['date'] as String;
    final buy = row['buy'] as num;
    final sell = row['close'] as num;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.tryParse(date) == null ||
        buy <= 0 ||
        sell <= 0) {
      throw const FormatException('Invalid gold history');
    }
    result.add(
      DailyGoldPrice(
        date,
        (buy * 100).round(),
        sellSatang: (sell * 100).round(),
      ),
    );
  }
  result.sort((a, b) => a.date.compareTo(b.date));
  return result;
}

class GoldHistoryApi {
  GoldHistoryApi({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;
  final http.Client _client;
  final DateTime Function() _clock;
  final Map<GoldChartRange, List<DailyGoldPrice>> _cache = {};
  final Map<GoldChartRange, DateTime> _fetchedAt = {};

  Future<List<DailyGoldPrice>> history(
    GoldChartRange range, {
    bool force = false,
  }) async {
    final now = _clock();
    final cached = _cache[range];
    if (!force &&
        cached != null &&
        _fetchedAt[range] != null &&
        now.difference(_fetchedAt[range]!) < const Duration(minutes: 5)) {
      return cached;
    }
    final format = DateFormat('yyyy-MM-dd');
    final uri = Uri.https('xn--42cg1c5bwc1ab.live', '/api/v1/history.json', {
      'from': format.format(range.start(now)),
      'to': format.format(now),
      'interval': range.monthly ? 'month' : 'day',
    });
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('โหลดประวัติราคาทองไม่สำเร็จ');
    }
    final rows = parseGoldHistory(utf8.decode(response.bodyBytes));
    _cache[range] = rows;
    _fetchedAt[range] = now;
    return rows;
  }

  void close() => _client.close();
}
