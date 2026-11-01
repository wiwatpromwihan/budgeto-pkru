import 'package:budgeto/budget.dart';
import 'package:budgeto/gold_history.dart';
import 'package:budgeto/gold_market_chart.dart';
import 'package:budgeto/gold_price.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GoldPortfolio extends StatelessWidget {
  const GoldPortfolio({
    super.key,
    required this.purchases,
    required this.cash,
    required this.price,
    required this.history,
    required this.historyError,
    required this.historyLoading,
    required this.range,
    required this.onRangeChanged,
    required this.onRetry,
    required this.onOpenSource,
  });

  final List<GoldPurchase> purchases;
  final int cash;
  final GoldPrice? price;
  final List<DailyGoldPrice>? history;
  final bool historyError;
  final bool historyLoading;
  final GoldChartRange range;
  final ValueChanged<GoldChartRange> onRangeChanged;
  final VoidCallback onRetry;
  final VoidCallback onOpenSource;

  @override
  Widget build(BuildContext context) {
    final grams = purchases.fold<int>(0, (sum, p) => sum + p.gramsUnits);
    final cost = purchases.fold<int>(0, (sum, p) => sum + p.costSatang);
    final value = price?.estimateSatang(grams);
    final delta = value == null ? null : value - cost;
    final positive = delta != null && delta >= 0;
    final statusColor = positive
        ? const Color(0xFF16745D)
        : const Color(0xFFB54738);

    return Column(
      children: [
        Card(
          color: const Color(0xFF103F42),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ทองที่ถือทั้งหมด',
                  style: TextStyle(color: Color(0xFFB9D4CF), fontSize: 15),
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 10,
                  children: [
                    Text(
                      formatGrams(grams),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 5),
                      child: Text(
                        'กรัม',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${NumberFormat('0.####').format(grams / gramUnitsPerBahtGold)} บาททองคำ',
                  style: const TextStyle(color: Color(0xFFB9D4CF)),
                ),
                const Divider(height: 30, color: Color(0xFF54777A)),
                Wrap(
                  spacing: 36,
                  runSpacing: 18,
                  children: [
                    _metric('ต้นทุนจริง', money(cost)),
                    _metric(
                      'มูลค่าขายคืนโดยประมาณ',
                      value == null ? 'รอราคาปัจจุบัน' : money(value),
                    ),
                    _metric('เงินออมสดคงเหลือ', money(cash)),
                  ],
                ),
                if (delta != null && cost > 0) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${positive ? '▲ เพิ่ม' : '▼ ลด'} ${money(delta.abs())}  (${positive ? '+' : '-'}${NumberFormat('0.00').format(delta.abs() * 100 / cost)}%)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (value == null && grams > 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'ยังประเมินมูลค่าและกำไร/ขาดทุนไม่ได้ เพราะไม่มีราคาปัจจุบัน',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GoldMarketChart(
          history: history,
          loading: historyLoading,
          error: historyError,
          range: range,
          onRangeChanged: onRangeChanged,
          onRetry: onRetry,
          onOpenSource: onOpenSource,
        ),
      ],
    );
  }

  Widget _metric(String label, String amount) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFFB9D4CF), fontSize: 13),
      ),
      const SizedBox(height: 4),
      Text(
        amount,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
