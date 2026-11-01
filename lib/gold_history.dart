import 'dart:convert';

import 'package:budgeto/budget.dart';
import 'package:budgeto/gold_price.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DailyGoldPrice {
  const DailyGoldPrice(this.date, this.buySatang);
  final String date;
  final int buySatang;
}

class GoldPortfolioPoint {
  const GoldPortfolioPoint(
    this.date,
    this.valueSatang,
    this.costSatang, {
    this.isLatest = false,
  });
  final String date;
  final int valueSatang;
  final int costSatang;
  final bool isLatest;
}

List<DailyGoldPrice> parseGoldHistory(String body) {
  final root = jsonDecode(body) as Map<String, dynamic>;
  final rows = root['data'] as List<dynamic>;
  final result = <DailyGoldPrice>[];
  for (final raw in rows) {
    final row = raw as Map<String, dynamic>;
    final date = row['date'] as String;
    final buy = row['buy'] as num;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.tryParse(date) == null ||
        buy <= 0) {
      throw const FormatException('Invalid gold history');
    }
    result.add(DailyGoldPrice(date, (buy * 100).round()));
  }
  result.sort((a, b) => a.date.compareTo(b.date));
  return result;
}

List<GoldPortfolioPoint> portfolioHistory({
  required List<DailyGoldPrice> history,
  required List<GoldPurchase> purchases,
  required int days,
  required DateTime now,
  GoldPrice? latest,
}) {
  final today = DateFormat('yyyy-MM-dd').format(now);
  final from = DateFormat(
    'yyyy-MM-dd',
  ).format(now.subtract(Duration(days: days - 1)));
  final prices = <String, DailyGoldPrice>{
    for (final row in history)
      if (row.date.compareTo(from) >= 0 && row.date.compareTo(today) <= 0)
        row.date: row,
  };
  if (latest != null) prices[today] = DailyGoldPrice(today, latest.buySatang);
  return prices.values
      .map((row) {
        var grams = 0;
        var cost = 0;
        for (final purchase in purchases) {
          if (purchase.date.compareTo(row.date) <= 0) {
            grams += purchase.gramsUnits;
            cost += purchase.costSatang;
          }
        }
        final value =
            (grams * row.buySatang + gramUnitsPerBahtGold ~/ 2) ~/
            gramUnitsPerBahtGold;
        return GoldPortfolioPoint(
          row.date,
          value,
          cost,
          isLatest: latest != null && row.date == today,
        );
      })
      .where((point) => point.costSatang > 0)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

class GoldHistoryApi {
  GoldHistoryApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  List<DailyGoldPrice>? _cached;
  DateTime? _fetchedAt;

  Future<List<DailyGoldPrice>> history({bool force = false}) async {
    if (!force &&
        _cached != null &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < const Duration(minutes: 5)) {
      return _cached!;
    }
    final now = DateTime.now();
    final from = DateFormat(
      'yyyy-MM-dd',
    ).format(now.subtract(const Duration(days: 89)));
    final to = DateFormat('yyyy-MM-dd').format(now);
    final uri = Uri.https('xn--42cg1c5bwc1ab.live', '/api/v1/history.json', {
      'from': from,
      'to': to,
    });
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('โหลดประวัติราคาทองไม่สำเร็จ');
    }
    final rows = parseGoldHistory(utf8.decode(response.bodyBytes));
    _cached = rows;
    _fetchedAt = now;
    return rows;
  }

  void close() => _client.close();
}
