import 'package:budgeto/budget.dart';
import 'package:budgeto/gold_price.dart';
import 'package:budgeto/gold_history.dart';
import 'package:budgeto/gold_portfolio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

class GoldScreen extends StatefulWidget {
  const GoldScreen({super.key, required this.uid, required this.store});
  final String uid;
  final BudgetStore store;
  @override
  State<GoldScreen> createState() => _GoldScreenState();
}

class _GoldScreenState extends State<GoldScreen> {
  static final GoldPriceApi _sharedApi = GoldPriceApi();
  static final GoldHistoryApi _sharedHistoryApi = GoldHistoryApi();
  final api = _sharedApi;
  final historyApi = _sharedHistoryApi;
  late Stream<int> _cashStream;
  late Stream<List<GoldPurchase>> _goldStream;
  GoldPrice? price;
  List<DailyGoldPrice>? history;
  bool historyLoading = false;
  bool historyError = false;
  GoldChartRange range = GoldChartRange.year;
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _bindStreams();
    _load();
    _loadHistory();
  }

  @override
  void didUpdateWidget(covariant GoldScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store || oldWidget.uid != widget.uid) {
      _bindStreams();
    }
  }

  void _bindStreams() {
    _cashStream = widget.store.cash(widget.uid);
    _goldStream = widget.store.goldPurchases(widget.uid);
  }

  Future<void> _loadHistory() async {
    final requestedRange = range;
    setState(() {
      historyLoading = true;
      historyError = false;
      history = null;
    });
    try {
      final value = await historyApi.history(requestedRange);
      if (mounted && range == requestedRange) setState(() => history = value);
    } catch (_) {
      if (mounted && range == requestedRange) {
        setState(() {
          historyError = true;
          history = null;
        });
      }
    } finally {
      if (mounted && range == requestedRange) {
        setState(() => historyLoading = false);
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await api.latest();
      if (mounted) setState(() => price = value);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'โหลดราคาทองไม่ได้ กรุณาลองใหม่';
          price = null;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _edit([GoldPurchase? purchase]) async {
    if (purchase == null && !api.isFresh) await _load();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _GoldDialog(
        uid: widget.uid,
        store: widget.store,
        existing: purchase,
        currentPrice: price,
      ),
    );
  }

  Future<void> _delete(GoldPurchase purchase) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบรายการซื้อทอง?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await widget.store.deleteGold(widget.uid, purchase.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบรายการไม่สำเร็จ')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<int>(
    stream: _cashStream,
    builder: (context, cashSnapshot) => StreamBuilder<List<GoldPurchase>>(
      stream: _goldStream,
      builder: (context, snapshot) {
        if (snapshot.hasError || cashSnapshot.hasError) {
          return const Center(child: Text('โหลดข้อมูลออมทองไม่สำเร็จ'));
        }
        if (!snapshot.hasData || !cashSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final purchases = snapshot.data!;
        return ListView(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ออมทอง',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('จดทองที่ซื้อ'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'บันทึกทองคำแท่ง 96.5% ที่ซื้อจากภายนอก แอปไม่มีการซื้อขายหรือชำระเงินจริง',
            ),
            const SizedBox(height: 18),
            GoldPortfolio(
              purchases: purchases,
              cash: cashSnapshot.data!,
              price: price,
              history: history,
              historyError: historyError,
              historyLoading: historyLoading,
              range: range,
              onRangeChanged: (value) {
                if (range == value) return;
                setState(() => range = value);
                _loadHistory();
              },
              onRetry: _loadHistory,
              onOpenSource: () => web.window.location.assign(
                'https://xn--42cg1c5bwc1ab.live/chart',
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ราคาทองคำแท่ง 96.5%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (loading) const LinearProgressIndicator(),
                    if (error != null) Text(error!),
                    if (price != null) ...[
                      Text(
                        'ราคาขายออก (อ้างอิงตอนซื้อ)  ${money(price!.sellSatang)}',
                      ),
                      Text(
                        'ราคารับซื้อ (ประเมินขายคืน)  ${money(price!.buySatang)}',
                      ),
                      Text('อัปเดต ${price!.updateDate} ${price!.updateTime}'),
                    ],
                    Row(
                      children: [
                        TextButton(
                          onPressed: loading ? null : _load,
                          child: Text(error == null ? 'รีเฟรชราคา' : 'ลองใหม่'),
                        ),
                        TextButton(
                          onPressed: () => web.window.location.assign(
                            'https://github.com/max180643/thai-gold-api',
                          ),
                          child: const Text('แหล่งข้อมูล Thai Gold API'),
                        ),
                      ],
                    ),
                    const Text(
                      'ราคาเป็นข้อมูลอ้างอิง กำไร/ขาดทุนเป็นเพียงประมาณการ ไม่รับประกันผลตอบแทน',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'รายการซื้อทอง',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (purchases.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('ยังไม่มีรายการซื้อทอง'),
              ),
            for (final item in purchases)
              Card(
                child: ListTile(
                  title: Text(
                    '${formatGrams(item.gramsUnits)} กรัม · ${money(item.costSatang)}',
                  ),
                  subtitle: Text(
                    '${item.date}${item.referenceSellSatang == null ? '' : ' · ราคาอ้างอิง ${money(item.referenceSellSatang!)}'}${item.note.isEmpty ? '' : ' · ${item.note}'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _edit(item),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'แก้ไข',
                      ),
                      IconButton(
                        onPressed: () => _delete(item),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'ลบ',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _GoldDialog extends StatefulWidget {
  const _GoldDialog({
    required this.uid,
    required this.store,
    required this.currentPrice,
    this.existing,
  });
  final String uid;
  final BudgetStore store;
  final GoldPurchase? existing;
  final GoldPrice? currentPrice;

  @override
  State<_GoldDialog> createState() => _GoldDialogState();
}

class _GoldDialogState extends State<_GoldDialog> {
  late final cost = TextEditingController(
    text: widget.existing == null
        ? ''
        : (widget.existing!.costSatang / 100).toStringAsFixed(2),
  );
  late final grams = TextEditingController(
    text: widget.existing == null
        ? ''
        : formatGrams(widget.existing!.gramsUnits),
  );
  late final note = TextEditingController(text: widget.existing?.note ?? '');
  late bool manualGrams = widget.existing != null;
  String? error;
  bool busy = false;

  int? get referenceSellSatang => widget.existing == null
      ? widget.currentPrice?.sellSatang
      : widget.existing!.referenceSellSatang;
  String get referenceDate => widget.existing == null
      ? widget.currentPrice?.updateDate ?? ''
      : widget.existing!.referenceDate;
  String get referenceTime => widget.existing == null
      ? widget.currentPrice?.updateTime ?? ''
      : widget.existing!.referenceTime;

  @override
  void dispose() {
    cost.dispose();
    grams.dispose();
    note.dispose();
    super.dispose();
  }

  void _recalculate() {
    final amount = parseSatang(cost.text);
    final reference = referenceSellSatang;
    setState(() {
      manualGrams = false;
      error = null;
      grams.text = amount == null || reference == null
          ? ''
          : formatGrams(gramsForAmount(amount, reference));
    });
  }

  void _costChanged(String _) {
    if (!manualGrams && referenceSellSatang != null) {
      _recalculate();
    } else {
      setState(() => error = null);
    }
  }

  Future<void> _save() async {
    final amount = parseSatang(cost.text);
    final weight = parseGramUnits(grams.text);
    if (amount == null || weight == null || note.text.length > 120) {
      setState(() => error = 'กรอกยอดจ่ายและน้ำหนักทองให้ถูกต้อง');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final available = await widget.store.cash(widget.uid).first;
      if (amount > available + (widget.existing?.costSatang ?? 0)) {
        throw StateError('ยอดออมสดไม่พอ กรุณาโอนเข้าออมก่อน');
      }
      await widget.store.saveGold(
        widget.uid,
        GoldPurchase(
          id: widget.existing?.id ?? '',
          gramsUnits: weight,
          costSatang: amount,
          date:
              widget.existing?.date ??
              DateFormat('yyyy-MM-dd').format(DateTime.now()),
          note: note.text,
          referenceSellSatang: referenceSellSatang,
          referenceDate: referenceDate,
          referenceTime: referenceTime,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message
              : 'บันทึกไม่สำเร็จ กรุณาลองอีกครั้ง',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reference = referenceSellSatang;
    final weight = parseGramUnits(grams.text);
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'จดทองที่ซื้อ' : 'แก้ไขรายการซื้อทอง',
      ),
      content: SizedBox(
        width: 470,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('กรอกยอดที่จ่ายจริง แล้วตรวจน้ำหนักทองก่อนบันทึก'),
              const SizedBox(height: 16),
              StreamBuilder<int>(
                stream: widget.store.cash(widget.uid),
                builder: (context, snapshot) => Text(
                  'เงินออมสดคงเหลือ ${money(snapshot.data ?? 0)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cost,
                autofocus: true,
                onChanged: _costChanged,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'ยอดจ่ายจริงทั้งหมด (บาท)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final amount in [100, 500, 1000, 2000])
                    ActionChip(
                      label: Text(NumberFormat('#,##0').format(amount)),
                      onPressed: busy
                          ? null
                          : () {
                              cost.text = amount.toString();
                              _costChanged(cost.text);
                            },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE7CD8D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reference == null
                          ? 'ไม่มีราคาอ้างอิง'
                          : 'ราคาขายออกที่ใช้อ้างอิง ${money(reference)} / บาททองคำ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (reference != null)
                      Text('อัปเดต $referenceDate $referenceTime'),
                    Text(
                      reference == null
                          ? 'API ใช้ไม่ได้ กรอกน้ำหนักจริงจากใบเสร็จได้'
                          : 'คำนวณเบื้องต้นจาก 1 บาททองคำ = 15.244 กรัม',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: grams,
                onChanged: (_) => setState(() {
                  manualGrams = true;
                  error = null;
                }),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'น้ำหนักทองจริง (กรัม สูงสุด 4 ตำแหน่ง)',
                  helperText: 'แก้ตามน้ำหนักบนใบเสร็จได้',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
              ),
              if (weight != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'ประมาณ ${NumberFormat('0.####').format(weight / gramUnitsPerBahtGold)} บาททองคำ'
                    '${manualGrams ? ' · น้ำหนักที่ยืนยันเอง' : ' · คำนวณจากราคาอ้างอิง'}',
                  ),
                ),
              if (widget.existing != null && reference != null)
                TextButton.icon(
                  onPressed: busy ? null : _recalculate,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('คำนวณน้ำหนักใหม่จากราคาอ้างอิงเดิม'),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุ (ไม่บังคับ)',
                ),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: busy ? null : _save,
          child: const Text('บันทึกทอง'),
        ),
      ],
    );
  }
}
