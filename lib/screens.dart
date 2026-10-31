import 'package:budgeto/budget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const _ink = Color(0xFF15263A);
const _muted = Color(0xFF607383);
const _teal = Color(0xFF087F77);

String _authError(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'email-already-in-use' => 'อีเมลนี้มีบัญชีแล้ว',
      'invalid-email' => 'รูปแบบอีเมลไม่ถูกต้อง',
      'weak-password' => 'รหัสผ่านสั้นเกินไป',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
      'popup-closed-by-user' => 'ปิดหน้าต่างเข้าสู่ระบบ Google ก่อนสำเร็จ',
      'unauthorized-domain' =>
        'localhost ยังไม่ได้รับอนุญาตใน Firebase Authentication',
      _ => 'เข้าสู่ระบบไม่สำเร็จ (${error.code})',
    };
  }
  return 'เกิดข้อผิดพลาด กรุณาลองอีกครั้ง';
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await signInWithGoogle();
    } catch (error) {
      if (mounted) setState(() => _error = _authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: _teal,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Budgeto',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'จัดเงินให้เห็นภาพในทุกเดือน',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 16),
              ),
              const SizedBox(height: 28),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _register ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'อีเมล'),
                          validator: (v) => v == null || !v.contains('@')
                              ? 'กรอกอีเมลให้ถูกต้อง'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'รหัสผ่าน',
                          ),
                          validator: (v) => v == null || v.length < 6
                              ? 'รหัสผ่านอย่างน้อย 6 ตัวอักษร'
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _register ? 'สร้างบัญชี' : 'เข้าสู่ระบบ',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _google,
                          icon: const Icon(Icons.g_mobiledata_rounded),
                          label: const Text('ดำเนินการต่อด้วย Google'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _register = !_register;
                                  _error = null;
                                }),
                          child: Text(
                            _register
                                ? 'มีบัญชีแล้ว? เข้าสู่ระบบ'
                                : 'ยังไม่มีบัญชี? สมัครสมาชิก',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.user, required this.store});
  final User user;
  final BudgetStore store;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _changeMonth(int offset) =>
      setState(() => _month = DateTime(_month.year, _month.month + offset));
  String get _monthName => DateFormat('MMMM yyyy', 'th_TH').format(_month);

  Future<void> _entry([BudgetEntry? existing]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => EntryDialog(
        month: _month,
        existing: existing,
        store: widget.store,
        uid: widget.user.uid,
      ),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกรายการแล้ว')));
    }
  }

  Future<void> _split(BudgetSplit split) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => SplitDialog(
        month: _month,
        initial: split,
        store: widget.store,
        uid: widget.user.uid,
      ),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกสัดส่วนแล้ว')));
    }
  }

  Future<void> _delete(BudgetEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบรายการ?'),
        content: Text(
          entry.note.isEmpty
              ? '${entry.kind.label} ${money(entry.amountSatang)}'
              : entry.note,
        ),
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
    if (confirmed != true) return;
    try {
      await widget.store.deleteEntry(widget.user.uid, _month, entry.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบรายการไม่สำเร็จ')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final brand = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: _teal,
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Budgeto',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  );
                  final signOut = OutlinedButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout, size: 17),
                    label: const Text('ออกจากระบบ'),
                  );
                  final email = Text(
                    widget.user.email ?? 'บัญชี Google',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted),
                  );
                  if (box.maxWidth < 700) {
                    return Column(
                      children: [
                        Row(children: [brand, const Spacer(), signOut]),
                        const SizedBox(height: 6),
                        Align(alignment: Alignment.centerLeft, child: email),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      brand,
                      const Spacer(),
                      Flexible(child: email),
                      const SizedBox(width: 12),
                      signOut,
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<BudgetSplit>(
                  key: ValueKey('split-${monthKey(_month)}'),
                  stream: widget.store.split(widget.user.uid, _month),
                  builder: (context, splitSnapshot) => StreamBuilder<List<BudgetEntry>>(
                    key: ValueKey('entries-${monthKey(_month)}'),
                    stream: widget.store.entries(widget.user.uid, _month),
                    builder: (context, entrySnapshot) {
                      if (splitSnapshot.hasError || entrySnapshot.hasError) {
                        return const Center(
                          child: Text(
                            'โหลดข้อมูลไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่อและสิทธิ์ Firebase',
                          ),
                        );
                      }
                      if (!splitSnapshot.hasData || !entrySnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final split = splitSnapshot.data!;
                      final entries = entrySnapshot.data!;
                      final totals = BudgetTotals.fromEntries(entries);
                      return ListView(
                        children: [
                          LayoutBuilder(
                            builder: (context, box) {
                              final heading = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ภาพรวมการเงิน',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'รายรับและการใช้เงินของเดือน $_monthName',
                                    style: const TextStyle(color: _muted),
                                  ),
                                ],
                              );
                              final controls = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _changeMonth(-1),
                                    tooltip: 'เดือนก่อน',
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  Text(
                                    _monthName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _changeMonth(1),
                                    tooltip: 'เดือนถัดไป',
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: () => _entry(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('เพิ่มรายการ'),
                                  ),
                                ],
                              );
                              if (box.maxWidth < 760) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    heading,
                                    const SizedBox(height: 12),
                                    controls,
                                  ],
                                );
                              }
                              return Row(
                                children: [heading, const Spacer(), controls],
                              );
                            },
                          ),
                          const SizedBox(height: 22),
                          _IncomeCard(total: totals.income),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Text(
                                'งบตามสัดส่วน',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _split(split),
                                icon: const Icon(Icons.tune, size: 18),
                                label: const Text('ปรับสัดส่วน'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final narrow = constraints.maxWidth < 760;
                              final cards = [
                                _BucketCard(
                                  kind: EntryKind.needs,
                                  percent: split.needs,
                                  allocated: totals.allocation(
                                    split,
                                    EntryKind.needs,
                                  ),
                                  actual: totals.needs,
                                ),
                                _BucketCard(
                                  kind: EntryKind.wants,
                                  percent: split.wants,
                                  allocated: totals.allocation(
                                    split,
                                    EntryKind.wants,
                                  ),
                                  actual: totals.wants,
                                ),
                                _BucketCard(
                                  kind: EntryKind.savings,
                                  percent: split.savings,
                                  allocated: totals.allocation(
                                    split,
                                    EntryKind.savings,
                                  ),
                                  actual: totals.savings,
                                ),
                              ];
                              return narrow
                                  ? Column(
                                      children: [
                                        for (final card in cards)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: card,
                                          ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        for (final card in cards)
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 12,
                                              ),
                                              child: card,
                                            ),
                                          ),
                                      ],
                                    );
                            },
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'รายการในเดือนนี้',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (entries.isEmpty)
                            Card(
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  children: [
                                    const Text(
                                      'ยังไม่มีรายการในเดือนนี้',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'เริ่มจากเพิ่มรายรับ แล้วบันทึกรายจ่ายหรือเงินออม',
                                      style: TextStyle(color: _muted),
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton.icon(
                                      onPressed: () => _entry(),
                                      icon: const Icon(Icons.add),
                                      label: const Text('เพิ่มรายการ'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Card(
                              elevation: 0,
                              child: Column(
                                children: [
                                  for (final entry in entries)
                                    ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            entry.kind == EntryKind.income
                                            ? const Color(0xFFE0F4EA)
                                            : const Color(0xFFE8F1F3),
                                        child: Icon(
                                          entry.kind == EntryKind.income
                                              ? Icons.south_west
                                              : Icons.north_east,
                                          color: _teal,
                                          size: 18,
                                        ),
                                      ),
                                      title: Text(
                                        entry.note.isEmpty
                                            ? entry.kind.label
                                            : entry.note,
                                      ),
                                      subtitle: Text(
                                        '${entry.kind.label} · ${DateFormat('d MMM yyyy', 'th_TH').format(entry.date)}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${entry.kind == EntryKind.income ? '+' : '-'}${money(entry.amountSatang)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _entry(entry),
                                            tooltip: 'แก้ไข',
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 19,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _delete(entry),
                                            tooltip: 'ลบ',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 19,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _IncomeCard extends StatelessWidget {
  const _IncomeCard({required this.total});
  final int total;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _ink,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Icon(Icons.trending_up, color: Color(0xFF7DE2C4), size: 34),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'รายรับรวมเดือนนี้',
              style: TextStyle(color: Color(0xFFBED1DC)),
            ),
            const SizedBox(height: 4),
            Text(
              money(total),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.kind,
    required this.percent,
    required this.allocated,
    required this.actual,
  });
  final EntryKind kind;
  final int percent;
  final int allocated;
  final int actual;
  @override
  Widget build(BuildContext context) {
    final remaining = allocated - actual;
    final progress = allocated == 0
        ? 0.0
        : (actual / allocated).clamp(0.0, 1.0);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  kind.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: _teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              money(allocated),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('งบที่จัดสรร', style: TextStyle(color: _muted)),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(10),
              backgroundColor: const Color(0xFFE7EEF1),
              color: remaining < 0 ? Colors.red : _teal,
            ),
            const SizedBox(height: 12),
            Text(
              'ใช้จริง ${money(actual)}',
              style: const TextStyle(color: _muted),
            ),
            Text(
              'คงเหลือ ${money(remaining)}',
              style: TextStyle(
                color: remaining < 0 ? Colors.red : _ink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EntryDialog extends StatefulWidget {
  const EntryDialog({
    super.key,
    required this.month,
    required this.existing,
    required this.store,
    required this.uid,
  });
  final DateTime month;
  final BudgetEntry? existing;
  final BudgetStore store;
  final String uid;
  @override
  State<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<EntryDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : (widget.existing!.amountSatang / 100).toStringAsFixed(2),
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.existing?.note ?? '',
  );
  late EntryKind _kind = widget.existing?.kind ?? EntryKind.income;
  late DateTime _date =
      widget.existing?.date ??
      (monthKey(DateTime.now()) == monthKey(widget.month)
          ? DateTime.now()
          : widget.month);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.saveEntry(
        widget.uid,
        widget.month,
        BudgetEntry(
          id: widget.existing?.id ?? '',
          kind: _kind,
          amountSatang: parseSatang(_amount.text)!,
          date: _date,
          note: _note.text,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'บันทึกไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่อ');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'เพิ่มรายการ' : 'แก้ไขรายการ'),
    content: SizedBox(
      width: 410,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<EntryKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'ประเภท'),
              items: [
                for (final kind in EntryKind.values)
                  DropdownMenuItem(value: kind, child: Text(kind.label)),
              ],
              onChanged: _busy ? null : (kind) => setState(() => _kind = kind!),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(labelText: 'จำนวนเงิน (บาท)'),
              validator: (v) => parseSatang(v ?? '') == null
                  ? 'กรอกจำนวนเงินมากกว่า 0 สูงสุด 2 ตำแหน่งทศนิยม'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _note,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'บันทึกย่อ (ไม่บังคับ)',
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(
                            widget.month.year,
                            widget.month.month,
                          ),
                          lastDate: DateTime(
                            widget.month.year,
                            widget.month.month + 1,
                            0,
                          ),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(DateFormat('d MMM yyyy', 'th_TH').format(_date)),
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: const Text('บันทึก'),
      ),
    ],
  );
}

class SplitDialog extends StatefulWidget {
  const SplitDialog({
    super.key,
    required this.month,
    required this.initial,
    required this.store,
    required this.uid,
  });
  final DateTime month;
  final BudgetSplit initial;
  final BudgetStore store;
  final String uid;
  @override
  State<SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends State<SplitDialog> {
  late final _needs = TextEditingController(text: '${widget.initial.needs}');
  late final _wants = TextEditingController(text: '${widget.initial.wants}');
  late final _savings = TextEditingController(
    text: '${widget.initial.savings}',
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _needs.dispose();
    _wants.dispose();
    _savings.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final split = BudgetSplit(
      int.tryParse(_needs.text) ?? -1,
      int.tryParse(_wants.text) ?? -1,
      int.tryParse(_savings.text) ?? -1,
    );
    if (!split.isValid) {
      setState(() => _error = 'สัดส่วนทั้ง 3 หมวดต้องรวมกันเป็น 100%');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.saveSplit(widget.uid, widget.month, split);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'บันทึกสัดส่วนไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ปรับสัดส่วนงบ'),
    content: SizedBox(
      width: 350,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final pair in [
            ('จำเป็น', _needs),
            ('ใช้จ่าย', _wants),
            ('ออม', _savings),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: pair.$2,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: '${pair.$1} (%)'),
              ),
            ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: const Text('บันทึก'),
      ),
    ],
  );
}
