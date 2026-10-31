import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

enum EntryKind { income, needs, wants, savings }

extension EntryKindInfo on EntryKind {
  String get label => switch (this) {
    EntryKind.income => 'รายรับ',
    EntryKind.needs => 'จำเป็น',
    EntryKind.wants => 'ใช้จ่าย',
    EntryKind.savings => 'โอนเข้าออม',
  };
}

class BudgetSplit {
  const BudgetSplit(this.needs, this.wants, this.savings);
  final int needs;
  final int wants;
  final int savings;
  static const initial = BudgetSplit(50, 30, 20);

  bool get isValid =>
      needs >= 0 &&
      wants >= 0 &&
      savings >= 0 &&
      needs <= 100 &&
      wants <= 100 &&
      savings <= 100 &&
      needs + wants + savings == 100;

  factory BudgetSplit.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return initial;
    final split = BudgetSplit(
      data['needs'] as int? ?? 50,
      data['wants'] as int? ?? 30,
      data['savings'] as int? ?? 20,
    );
    return split.isValid ? split : initial;
  }

  Map<String, int> toMap() => {
    'needs': needs,
    'wants': wants,
    'savings': savings,
  };
}

class BudgetEntry {
  const BudgetEntry({
    required this.id,
    required this.kind,
    required this.amountSatang,
    required this.date,
    required this.note,
  });
  final String id;
  final EntryKind kind;
  final int amountSatang;
  final DateTime date;
  final String note;

  factory BudgetEntry.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return BudgetEntry(
      id: doc.id,
      kind: EntryKind.values.byName(data['kind'] as String),
      amountSatang: data['amountSatang'] as int,
      date: DateTime.parse(data['date'] as String),
      note: data['note'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'kind': kind.name,
    'amountSatang': amountSatang,
    'date': DateFormat('yyyy-MM-dd').format(date),
    'note': note.trim(),
  };
}

class BudgetTotals {
  const BudgetTotals({
    required this.income,
    required this.needs,
    required this.wants,
    required this.savings,
  });
  final int income;
  final int needs;
  final int wants;
  final int savings;

  factory BudgetTotals.fromEntries(List<BudgetEntry> entries) {
    int income = 0, needs = 0, wants = 0, savings = 0;
    for (final entry in entries) {
      switch (entry.kind) {
        case EntryKind.income:
          income += entry.amountSatang;
        case EntryKind.needs:
          needs += entry.amountSatang;
        case EntryKind.wants:
          wants += entry.amountSatang;
        case EntryKind.savings:
          savings += entry.amountSatang;
      }
    }
    return BudgetTotals(
      income: income,
      needs: needs,
      wants: wants,
      savings: savings,
    );
  }

  int allocation(BudgetSplit split, EntryKind kind) {
    final needsBudget = income * split.needs ~/ 100;
    final wantsBudget = income * split.wants ~/ 100;
    return switch (kind) {
      EntryKind.needs => needsBudget,
      EntryKind.wants => wantsBudget,
      EntryKind.savings => income - needsBudget - wantsBudget,
      EntryKind.income => income,
    };
  }

  int spent(EntryKind kind) => switch (kind) {
    EntryKind.income => income,
    EntryKind.needs => needs,
    EntryKind.wants => wants,
    EntryKind.savings => savings,
  };
}

String monthKey(DateTime month) => DateFormat('yyyy-MM').format(month);
String money(int satang) =>
    '${NumberFormat('#,##0.00', 'en_US').format(satang / 100)} ฿';

int? parseSatang(String value) {
  final input = value.replaceAll(',', '').trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(input)) return null;
  final parts = input.split('.');
  final baht = int.tryParse(parts[0]);
  if (baht == null || baht > 1000000000) return null;
  final satang = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
  final result = baht * 100 + satang;
  return result > 0 ? result : null;
}

class BudgetStore {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'budgeto',
  );

  DocumentReference<Map<String, dynamic>> _month(String uid, DateTime month) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('months')
          .doc(monthKey(month));

  Stream<BudgetSplit> split(String uid, DateTime month) =>
      _month(uid, month).snapshots().map(BudgetSplit.fromDoc);

  Stream<List<BudgetEntry>> entries(String uid, DateTime month) =>
      _month(uid, month).collection('entries').snapshots().map((snapshot) {
        final result = snapshot.docs.map(BudgetEntry.fromDoc).toList();
        result.sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          return byDate != 0 ? byDate : b.id.compareTo(a.id);
        });
        return result;
      });

  Future<void> saveSplit(String uid, DateTime month, BudgetSplit split) async {
    if (!split.isValid) throw ArgumentError('สัดส่วนต้องรวมกันเป็น 100%');
    await _month(uid, month).set(split.toMap());
  }

  Future<void> saveEntry(String uid, DateTime month, BudgetEntry entry) async {
    if (entry.amountSatang <= 0 || monthKey(entry.date) != monthKey(month)) {
      throw ArgumentError('ข้อมูลรายการไม่ถูกต้อง');
    }
    final collection = _month(uid, month).collection('entries');
    if (entry.id.isEmpty) {
      await collection.add(entry.toMap());
    } else {
      await collection.doc(entry.id).set(entry.toMap());
    }
  }

  Future<void> deleteEntry(String uid, DateTime month, String id) =>
      _month(uid, month).collection('entries').doc(id).delete();
}

Future<void> signInWithGoogle() async {
  await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
}
