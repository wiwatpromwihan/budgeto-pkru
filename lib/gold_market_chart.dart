import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:budgeto/gold_history.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GoldMarketChart extends StatefulWidget {
  const GoldMarketChart({
    super.key,
    required this.history,
    required this.loading,
    required this.error,
    required this.range,
    required this.onRangeChanged,
    required this.onRetry,
    required this.onOpenSource,
  });

  final List<DailyGoldPrice>? history;
  final bool loading;
  final bool error;
  final GoldChartRange range;
  final ValueChanged<GoldChartRange> onRangeChanged;
  final VoidCallback onRetry;
  final VoidCallback onOpenSource;

  @override
  State<GoldMarketChart> createState() => _GoldMarketChartState();
}

class _GoldMarketChartState extends State<GoldMarketChart> {
  int? selectedIndex;

  @override
  void didUpdateWidget(covariant GoldMarketChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.history != widget.history) selectedIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.history ?? const <DailyGoldPrice>[];
    final index = selectedIndex != null && selectedIndex! < rows.length
        ? selectedIndex!
        : rows.isEmpty
        ? null
        : rows.length - 1;
    final selected = index == null ? null : rows[index];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'กราฟราคาทองไทย',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'ทองคำแท่ง 96.5% ราคาขายออก ปิดรายวัน · หน่วยบาทต่อทองหนัก 1 บาท',
              style: TextStyle(color: Color(0xFF52626D)),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final option in GoldChartRange.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(option.label),
                        selected: widget.range == option,
                        onSelected: (_) => widget.onRangeChanged(option),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (widget.loading) const LinearProgressIndicator(),
            if (selected != null)
              Text(
                '${_dateLabel(selected.date)}  ราคาปิด ${NumberFormat('#,##0.##').format(selected.sellSatang / 100)} บาท',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 8),
            if (widget.error || widget.history == null) ...[
              const SizedBox(
                height: 90,
                child: Center(child: Text('โหลดกราฟราคาทองไม่ได้')),
              ),
              TextButton(
                onPressed: widget.onRetry,
                child: const Text('ลองใหม่'),
              ),
            ] else if (rows.isEmpty)
              const SizedBox(
                height: 90,
                child: Center(child: Text('ไม่มีข้อมูลราคาในช่วงนี้')),
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  width: constraints.maxWidth,
                  height: 260,
                  child: MouseRegion(
                    onHover: (event) => _select(
                      event.localPosition.dx,
                      constraints.maxWidth,
                      rows.length,
                    ),
                    onExit: (_) => setState(() => selectedIndex = null),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => _select(
                        details.localPosition.dx,
                        constraints.maxWidth,
                        rows.length,
                      ),
                      onHorizontalDragUpdate: (details) => _select(
                        details.localPosition.dx,
                        constraints.maxWidth,
                        rows.length,
                      ),
                      child: CustomPaint(
                        painter: _MarketPainter(rows, selectedIndex),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 58, right: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_shortDate(rows.first.date)),
                    Text(_shortDate(rows.last.date)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              widget.range.monthly
                  ? 'ช่วง 5 ปีขึ้นไปใช้ราคาปิดรายเดือน · แตะหรือชี้กราฟเพื่อดูราคา'
                  : 'แสดงเฉพาะวันที่มีข้อมูลราคาปิด · แตะหรือชี้กราฟเพื่อดูราคา',
              style: const TextStyle(fontSize: 12, color: Color(0xFF52626D)),
            ),
            TextButton(
              onPressed: widget.onOpenSource,
              child: const Text('แหล่งข้อมูล: ราคาทอง.live / สมาคมค้าทองคำ'),
            ),
          ],
        ),
      ),
    );
  }

  void _select(double dx, double width, int count) {
    if (count == 0) return;
    final usable = math.max(1.0, width - 66);
    final i = (((dx - 58) / usable) * (count - 1)).round().clamp(0, count - 1);
    if (i != selectedIndex) setState(() => selectedIndex = i);
  }
}

String _shortDate(String date) =>
    DateFormat('d MMM yy', 'th').format(DateTime.parse(date));
String _dateLabel(String date) =>
    DateFormat('d MMMM y', 'th').format(DateTime.parse(date));

class _MarketPainter extends CustomPainter {
  const _MarketPainter(this.rows, this.selectedIndex);
  final List<DailyGoldPrice> rows;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 58.0, right = 8.0, top = 12.0, bottom = 12.0;
    final minPrice = rows.map((e) => e.sellSatang).reduce(math.min) / 100;
    final maxPrice = rows.map((e) => e.sellSatang).reduce(math.max) / 100;
    final step = math.max(100.0, (maxPrice - minPrice) / 3);
    final low = (minPrice / step).floor() * step;
    final high = (maxPrice / step).ceil() * step == low
        ? low + step
        : (maxPrice / step).ceil() * step;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    Offset point(int i) => Offset(
      left + (rows.length == 1 ? .5 : i / (rows.length - 1)) * chartWidth,
      top +
          (1 - ((rows[i].sellSatang / 100 - low) / (high - low))) * chartHeight,
    );
    final grid = Paint()
      ..color = const Color(0xFFE2E9E8)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
      final label = NumberFormat('#,##0').format(high - (high - low) * i / 3);
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF60717A)),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(left - painter.width - 8, y - painter.height / 2),
      );
    }
    final line = Path();
    for (var i = 0; i < rows.length; i++) {
      final p = point(i);
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = const Color(0xFFAD7C12)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final i = selectedIndex;
    if (i != null && i < rows.length) {
      final p = point(i);
      canvas.drawLine(
        Offset(p.dx, top),
        Offset(p.dx, size.height - bottom),
        Paint()
          ..color = const Color(0xFFB4C5C1)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(p, 5, Paint()..color = const Color(0xFFAD7C12));
      canvas.drawCircle(p, 2.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _MarketPainter oldDelegate) =>
      oldDelegate.rows != rows || oldDelegate.selectedIndex != selectedIndex;
}
