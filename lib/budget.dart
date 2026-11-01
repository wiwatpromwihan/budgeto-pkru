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

int nextCashBalance(
  int current, {
  int oldSavings = 0,
  int newSavings = 0,
  int oldGoldCost = 0,
  int newGoldCost = 0,
}) {
  final balance = current - oldSavings + newSavings + oldGoldCost - newGoldCost;
  if (balance < 0) throw StateError('ยอดออมสดไม่พอ');
  return balance;
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

  DocumentReference<Map<String, dynamic>> _cash(String uid) =>
      _db.collection('users').doc(uid).collection('finance').doc('savings');

  CollectionReference<Map<String, dynamic>> _gold(String uid) =>
      _db.collection('users').doc(uid).collection('goldPurchases');

  Stream<int> cash(String uid) => _cash(
    uid,
  ).snapshots().map((doc) => (doc.data()?['cashSatang'] as int?) ?? 0);

  Stream<List<GoldPurchase>> goldPurchases(String uid) =>
      _gold(uid).snapshots().map((snapshot) {
        final result = snapshot.docs.map(GoldPurchase.fromDoc).toList();
        result.sort((a, b) => b.date.compareTo(a.date));
        return result;
      });

  Future<void> ensureCash(String uid) async {
    if ((await _cash(uid).get()).exists) return;
    // Existing month documents are read before initializing older accounts.
    final months = await _db
        .collection('users')
        .doc(uid)
        .collection('months')
        .get();
    var total = 0;
    for (final month in months.docs) {
      final entries = await month.reference.collection('entries').get();
      for (final entry in entries.docs) {
        if (entry.data()['kind'] == 'savings') {
          total += entry.data()['amountSatang'] as int;
        }
      }
    }
    await _db.runTransaction((tx) async {
      final current = await tx.get(_cash(uid));
      if (!current.exists) tx.set(_cash(uid), {'cashSatang': total});
    });
  }

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
    await ensureCash(uid);
    final monthRef = _month(uid, month);
    final ref = entry.id.isEmpty
        ? monthRef.collection('entries').doc()
        : monthRef.collection('entries').doc(entry.id);
    await _db.runTransaction((tx) async {
      final monthDoc = await tx.get(monthRef);
      final old = await tx.get(ref);
      final cashDoc = await tx.get(_cash(uid));
      final oldSavings = old.exists && old.data()?['kind'] == 'savings'
          ? old.data()!['amountSatang'] as int
          : 0;
      final newSavings = entry.kind == EntryKind.savings
          ? entry.amountSatang
          : 0;
      final balance = nextCashBalance(
        cashDoc.data()?['cashSatang'] as int? ?? 0,
        oldSavings: oldSavings,
        newSavings: newSavings,
      );
      if (!monthDoc.exists) tx.set(monthRef, BudgetSplit.initial.toMap());
      tx.set(ref, entry.toMap());
      if (oldSavings != newSavings) tx.set(_cash(uid), {'cashSatang': balance});
    });
  }

  Future<void> deleteEntry(String uid, DateTime month, String id) async {
    await ensureCash(uid);
    final ref = _month(uid, month).collection('entries').doc(id);
    await _db.runTransaction((tx) async {
      final old = await tx.get(ref);
      final cashDoc = await tx.get(_cash(uid));
      if (!old.exists) return;
      final savings = old.data()?['kind'] == 'savings'
          ? old.data()!['amountSatang'] as int
          : 0;
      final balance = nextCashBalance(
        cashDoc.data()?['cashSatang'] as int? ?? 0,
        oldSavings: savings,
      );
      tx.delete(ref);
      if (savings > 0) tx.set(_cash(uid), {'cashSatang': balance});
    });
  }

  Future<void> saveGold(String uid, GoldPurchase purchase) async {
    if (purchase.gramsUnits <= 0 ||
        purchase.costSatang <= 0 ||
        purchase.note.length > 120) {
      throw ArgumentError('ข้อมูลทองไม่ถูกต้อง');
    }
    await ensureCash(uid);
    final ref = purchase.id.isEmpty
        ? _gold(uid).doc()
        : _gold(uid).doc(purchase.id);
    await _db.runTransaction((tx) async {
      final old = await tx.get(ref);
      final cashDoc = await tx.get(_cash(uid));
      final oldCost = old.data()?['costSatang'] as int? ?? 0;
      final balance = nextCashBalance(
        cashDoc.data()?['cashSatang'] as int? ?? 0,
        oldGoldCost: oldCost,
        newGoldCost: purchase.costSatang,
      );
      if (old.exists && old.data()?['date'] != purchase.date) {
        throw ArgumentError('แก้ไขวันที่ซื้อไม่ได้');
      }
      tx.set(ref, purchase.toMap());
      tx.set(_cash(uid), {'cashSatang': balance});
    });
  }

  Future<void> deleteGold(String uid, String id) async {
    final ref = _gold(uid).doc(id);
    await _db.runTransaction((tx) async {
      final old = await tx.get(ref);
      final cashDoc = await tx.get(_cash(uid));
      if (!old.exists) return;
      tx.delete(ref);
      tx.set(_cash(uid), {
        'cashSatang': nextCashBalance(
          cashDoc.data()?['cashSatang'] as int? ?? 0,
          oldGoldCost: old.data()!['costSatang'] as int,
        ),
      });
    });
  }
}

class GoldPurchase {
  const GoldPurchase({
    required this.id,
    required this.gramsUnits,
    required this.costSatang,
    required this.date,
    required this.note,
    this.referenceSellSatang,
    this.referenceDate = '',
    this.referenceTime = '',
  });
  final String id;
  final int gramsUnits;
  final int costSatang;
  final String date;
  final String note;
  final int? referenceSellSatang;
  final String referenceDate;
  final String referenceTime;

  factory GoldPurchase.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final legacyWeightUnits = data['weightUnits'] as int?;
    return GoldPurchase(
      id: doc.id,
      gramsUnits:
          data['gramsUnits'] as int? ??
          legacyWeightToGramUnits(legacyWeightUnits!),
      costSatang: data['costSatang'] as int,
      date: data['date'] as String,
      note: data['note'] as String,
      referenceSellSatang: data['referenceSellSatang'] as int?,
      referenceDate: data['referenceDate'] as String? ?? '',
      referenceTime: data['referenceTime'] as String? ?? '',
    );
  }
  Map<String, dynamic> toMap() => {
    'gramsUnits': gramsUnits,
    'costSatang': costSatang,
    'date': date,
    'note': note.trim(),
    'referenceSellSatang': referenceSellSatang,
    'referenceDate': referenceDate,
    'referenceTime': referenceTime,
  };
}

int legacyWeightToGramUnits(int weightUnits) =>
    (weightUnits * 15244 + 500) ~/ 1000;

int? parseGramUnits(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d+(\.\d{1,4})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > 1000000) return null;
  final units =
      whole * 10000 +
      (parts.length == 2 ? int.parse(parts[1].padRight(4, '0')) : 0);
  return units > 0 ? units : null;
}

Future<void> signInWithGoogle() async {
  await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
}
