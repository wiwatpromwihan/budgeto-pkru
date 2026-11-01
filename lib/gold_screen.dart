import 'package:budgeto/budget.dart';
import 'package:budgeto/gold_price.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class GoldScreen extends StatefulWidget {
  const GoldScreen({super.key, required this.uid, required this.store});
  final String uid;
  final BudgetStore store;
  @override
  State<GoldScreen> createState() => _GoldScreenState();
}

class _GoldScreenState extends State<GoldScreen> {
  static final GoldPriceApi _sharedApi = GoldPriceApi();
  final api = _sharedApi;
  GoldPrice? price;
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
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
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _GoldDialog(uid: widget.uid, store: widget.store, existing: purchase),
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
    stream: widget.store.cash(widget.uid),
    builder: (context, cashSnapshot) => StreamBuilder<List<GoldPurchase>>(
      stream: widget.store.goldPurchases(widget.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError || cashSnapshot.hasError) {
          return const Center(child: Text('โหลดข้อมูลออมทองไม่สำเร็จ'));
        }
        if (!snapshot.hasData || !cashSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final purchases = snapshot.data!;
        final weight = purchases.fold<int>(0, (sum, e) => sum + e.weightUnits);
        final cost = purchases.fold<int>(0, (sum, e) => sum + e.costSatang);
        final estimate = price?.estimateSatang(weight);
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
                  label: const Text('บันทึกซื้อทอง'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'บันทึกทองคำแท่ง 96.5% ที่ซื้อจากภายนอก แอปไม่มีการซื้อขายหรือชำระเงินจริง',
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เงินออมสดคงเหลือ  ${money(cashSnapshot.data!)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'น้ำหนักทองที่ถือ  ${NumberFormat('0.####').format(weight / 10000)} บาททองคำ',
                    ),
                    Text('ต้นทุนจริง  ${money(cost)}'),
                    if (estimate != null) ...[
                      Text('มูลค่าขายคืนโดยประมาณ  ${money(estimate)}'),
                      Text(
                        'กำไร/ขาดทุนที่ยังไม่เกิดขึ้นจริง  ${money(estimate - cost)}',
                      ),
                    ],
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
                          onPressed: () => launchUrl(
                            Uri.parse(
                              'https://github.com/max180643/thai-gold-api',
                            ),
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
                    '${NumberFormat('0.####').format(item.weightUnits / 10000)} บาททองคำ · ${money(item.costSatang)}',
                  ),
                  subtitle: Text(
                    '${item.date}${item.note.isEmpty ? '' : ' · ${item.note}'}',
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
  const _GoldDialog({required this.uid, required this.store, this.existing});
  final String uid;
  final BudgetStore store;
  final GoldPurchase? existing;
  @override
  State<_GoldDialog> createState() => _GoldDialogState();
}

class _GoldDialogState extends State<_GoldDialog> {
  late final weight = TextEditingController(
    text: widget.existing == null
        ? ''
        : (widget.existing!.weightUnits / 10000).toString(),
  );
  late final cost = TextEditingController(
    text: widget.existing == null
        ? ''
        : (widget.existing!.costSatang / 100).toStringAsFixed(2),
  );
  late final note = TextEditingController(text: widget.existing?.note ?? '');
  String? error;
  bool busy = false;
  @override
  void dispose() {
    weight.dispose();
    cost.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final units = parseWeightUnits(weight.text);
    final satang = parseSatang(cost.text);
    if (units == null || satang == null || note.text.length > 120) {
      setState(() => error = 'ตรวจสอบน้ำหนัก ราคา และหมายเหตุ');
      return;
    }
    final available = await widget.store.cash(widget.uid).first;
    if (satang > available + (widget.existing?.costSatang ?? 0)) {
      setState(() => error = 'ยอดออมสดไม่พอ');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.saveGold(
        widget.uid,
        GoldPurchase(
          id: widget.existing?.id ?? '',
          weightUnits: units,
          costSatang: satang,
          date:
              widget.existing?.date ??
              DateFormat('yyyy-MM-dd').format(DateTime.now()),
          note: note.text,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is StateError ? e.message : 'บันทึกไม่สำเร็จ');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null ? 'บันทึกซื้อทอง' : 'แก้ไขรายการซื้อทอง',
    ),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'น้ำหนัก (บาททองคำ สูงสุด 4 ตำแหน่ง)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'ราคาที่จ่ายจริง (บาท)',
            ),
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
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(onPressed: busy ? null : _save, child: const Text('บันทึก')),
    ],
  );
}
