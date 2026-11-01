import 'dart:math' as math;

import 'package:budgeto/budget.dart';
import 'package:budgeto/gold_history.dart';
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
    required this.days,
    required this.onDaysChanged,
    required this.onRetry,
    required this.onOpenSource,
  });

  final List<GoldPurchase> purchases;
  final int cash;
  final GoldPrice? price;
  final List<DailyGoldPrice>? history;
  final bool historyError;
  final bool historyLoading;
  final int days;
  final ValueChanged<int> onDaysChanged;
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
    final points = history == null
        ? <GoldPortfolioPoint>[]
        : portfolioHistory(
            history: history!,
            purchases: purchases,
            days: days,
            now: DateTime.now(),
            latest: price,
          );

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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  spacing: 20,
                  children: [
                    const Text(
                      'มูลค่าทองเทียบต้นทุน',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 7, label: Text('7 วัน')),
                        ButtonSegment(value: 30, label: Text('30 วัน')),
                        ButtonSegment(value: 90, label: Text('90 วัน')),
                      ],
                      selected: {days},
                      onSelectionChanged: (selected) =>
                          onDaysChanged(selected.first),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 20,
                  children: [
                    _Legend(color: Color(0xFF087F77), label: 'มูลค่าขายคืน'),
                    _Legend(color: Color(0xFFD29A35), label: 'ต้นทุนสะสม'),
                  ],
                ),
                const SizedBox(height: 16),
                if (historyLoading && history == null)
                  const LinearProgressIndicator()
                else if (historyError || history == null) ...[
                  const Text('โหลดราคาย้อนหลังไม่ได้'),
                  TextButton(onPressed: onRetry, child: const Text('ลองใหม่')),
                ] else if (points.isEmpty)
                  const SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        'ยังไม่มีข้อมูลราคาหลังวันที่เริ่มถือทองในช่วงนี้',
                      ),
                    ),
                  )
                else if (points.length == 1)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ยังไม่มีแนวโน้มให้ดู',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'มีข้อมูลพอร์ตเพียงวันเดียว (${points.single.isLatest ? 'ล่าสุด' : _shortDate(points.single.date)}) เมื่อมีราคาในวันถัดไปจึงจะแสดงกราฟเปรียบเทียบได้',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'มูลค่าขายคืน ${money(points.single.valueSatang)} · ต้นทุน ${money(points.single.costSatang)}',
                        ),
                      ],
                    ),
                  )
                else ...[
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _PortfolioPainter(points: points),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_shortDate(points.first.date)),
                      Text(
                        points.last.isLatest
                            ? 'ล่าสุด'
                            : _shortDate(points.last.date),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'แสดงเฉพาะวันที่มีข้อมูลราคา · มูลค่าขายคืนและกำไร/ขาดทุนเป็นประมาณการ',
                  style: TextStyle(fontSize: 12),
                ),
                TextButton(
                  onPressed: onOpenSource,
                  child: const Text('แหล่งข้อมูลราคาย้อนหลัง: ราคาทอง.live'),
                ),
              ],
            ),
          ),
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

String _shortDate(String date) {
  final value = DateTime.parse(date);
  return DateFormat('d MMM', 'th').format(value);
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 3, color: color),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(fontSize: 13)),
    ],
  );
}

class _PortfolioPainter extends CustomPainter {
  const _PortfolioPainter({required this.points});
  final List<GoldPortfolioPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 5.0;
    const right = 5.0;
    const top = 10.0;
    const bottom = 10.0;
    final values = [
      for (final p in points) ...[p.valueSatang, p.costSatang],
    ];
    final minValue = values.reduce(math.min).toDouble();
    final maxValue = values.reduce(math.max).toDouble();
    final padding = math.max((maxValue - minValue) * .12, 100.0);
    final low = math.max(0.0, minValue - padding);
    final high = maxValue + padding;
    final start = DateTime.parse(
      points.first.date,
    ).millisecondsSinceEpoch.toDouble();
    final end = DateTime.parse(
      points.last.date,
    ).millisecondsSinceEpoch.toDouble();
    Offset offset(GoldPortfolioPoint p, int satang) {
      final time = DateTime.parse(p.date).millisecondsSinceEpoch.toDouble();
      final x =
          left +
          (end == start ? .5 : (time - start) / (end - start)) *
              (size.width - left - right);
      final y =
          top +
          (1 - (satang - low) / (high - low)) * (size.height - top - bottom);
      return Offset(x, y);
    }

    final gridPaint = Paint()
      ..color = const Color(0xFFE8EDEF)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = top + i * (size.height - top - bottom) / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    void drawLine(int Function(GoldPortfolioPoint) value, Color color) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final o = offset(points[i], value(points[i]));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
      final last = offset(points.last, value(points.last));
      canvas.drawCircle(last, 4, Paint()..color = color);
    }

    drawLine((p) => p.costSatang, const Color(0xFFD29A35));
    drawLine((p) => p.valueSatang, const Color(0xFF087F77));
  }

  @override
  bool shouldRepaint(covariant _PortfolioPainter oldDelegate) =>
      oldDelegate.points != points;
}
