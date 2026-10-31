import 'package:budgeto/budget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('split must total 100 percent', () {
    expect(BudgetSplit.initial.isValid, isTrue);
    expect(const BudgetSplit(50, 40, 20).isValid, isFalse);
  });

  test('amount parsing keeps satang exact', () {
    expect(parseSatang('1,234.50'), 123450);
    expect(parseSatang('0.01'), 1);
    expect(parseSatang('0'), isNull);
    expect(parseSatang('2.999'), isNull);
  });

  test('allocation keeps rounding remainder in savings', () {
    final totals = BudgetTotals.fromEntries([
      BudgetEntry(
        id: '1',
        kind: EntryKind.income,
        amountSatang: 101,
        date: DateTime(2026, 10, 1),
        note: '',
      ),
    ]);
    expect(totals.allocation(BudgetSplit.initial, EntryKind.needs), 50);
    expect(totals.allocation(BudgetSplit.initial, EntryKind.wants), 30);
    expect(totals.allocation(BudgetSplit.initial, EntryKind.savings), 21);
  });
}
