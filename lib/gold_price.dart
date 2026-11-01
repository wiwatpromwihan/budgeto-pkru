import 'dart:convert';
import 'package:http/http.dart' as http;

const gramUnitsPerBahtGold = 152440; // 15.244 g × 10,000 units/g.

int gramsForAmount(int amountSatang, int sellSatang) {
  if (amountSatang <= 0 || sellSatang <= 0) {
    throw ArgumentError('จำนวนเงินและราคาทองต้องมากกว่า 0');
  }
  return (amountSatang * gramUnitsPerBahtGold + sellSatang ~/ 2) ~/ sellSatang;
}

String formatGrams(int units) {
  final fraction = (units.abs() % 10000).toString().padLeft(4, '0');
  return '${units < 0 ? '-' : ''}${units.abs() ~/ 10000}.$fraction';
}

class GoldPrice {
  const GoldPrice({
    required this.buySatang,
    required this.sellSatang,
    required this.updateDate,
    required this.updateTime,
  });
  final int buySatang;
  final int sellSatang;
  final String updateDate;
  final String updateTime;

  factory GoldPrice.fromJson(Map<String, dynamic> json) {
    final response = json['response'] as Map<String, dynamic>;
    final bar =
        (response['price'] as Map<String, dynamic>)['gold_bar']
            as Map<String, dynamic>;
    int parse(String value) {
      final cleaned = value.replaceAll(',', '');
      if (!RegExp(r'^\d+\.\d{2}$').hasMatch(cleaned)) {
        throw const FormatException('Invalid gold price');
      }
      final parts = cleaned.split('.');
      return int.parse(parts[0]) * 100 + int.parse(parts[1]);
    }

    return GoldPrice(
      buySatang: parse(bar['buy'] as String),
      sellSatang: parse(bar['sell'] as String),
      updateDate: response['update_date'] as String,
      updateTime: response['update_time'] as String,
    );
  }

  int estimateSatang(int gramsUnits) =>
      (gramsUnits * buySatang + gramUnitsPerBahtGold ~/ 2) ~/
      gramUnitsPerBahtGold;
}

class GoldPriceApi {
  GoldPriceApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  GoldPrice? _cached;
  DateTime? _fetchedAt;

  bool get isFresh =>
      _fetchedAt != null &&
      DateTime.now().difference(_fetchedAt!) < const Duration(seconds: 60);

  Future<GoldPrice> latest({bool force = false}) async {
    if (!force &&
        _cached != null &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < const Duration(seconds: 60)) {
      return _cached!;
    }
    final response = await _client
        .get(Uri.parse('https://api.chnwt.dev/thai-gold-api/latest'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw StateError('โหลดราคาทองไม่สำเร็จ');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] != 'success') throw StateError('ข้อมูลราคาทองไม่พร้อม');
    final price = GoldPrice.fromJson(json);
    _cached = price;
    _fetchedAt = DateTime.now();
    return price;
  }

  void close() => _client.close();
}
