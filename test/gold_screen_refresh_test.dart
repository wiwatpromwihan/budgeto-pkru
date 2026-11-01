import 'package:budgeto/budget.dart';
import 'package:budgeto/gold_history.dart';
import 'package:budgeto/gold_price.dart';
import 'package:budgeto/gold_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FakeGoldStore implements GoldRepository {
  int cashSatang = 100000;
  final purchases = <GoldPurchase>[];
  int reads = 0;

  @override
  Stream<int> cash(String uid) => Stream.value(cashSatang);

  @override
  Future<GoldView> loadGoldView(String uid) async {
    reads++;
    return GoldView(cashSatang: cashSatang, purchases: List.of(purchases));
  }

  @override
  Future<void> saveGold(String uid, GoldPurchase purchase) async {
    cashSatang -= purchase.costSatang;
    purchases.add(
      GoldPurchase(
        id: 'new',
        gramsUnits: purchase.gramsUnits,
        costSatang: purchase.costSatang,
        date: purchase.date,
        note: purchase.note,
      ),
    );
  }

  @override
  Future<void> deleteGold(String uid, String id) async {
    final old = purchases.singleWhere((p) => p.id == id);
    cashSatang += old.costSatang;
    purchases.remove(old);
  }
}

void main() {
  testWidgets('new gold purchase appears without refreshing the browser', (
    tester,
  ) async {
    await initializeDateFormatting('th_TH');
    final store = _FakeGoldStore();
    final priceApi = GoldPriceApi(
      client: MockClient(
        (_) async => http.Response(
          '{"status":"success","response":{"update_date":"1/11/2569","update_time":"10:00","price":{"gold_bar":{"buy":"62,000.00","sell":"62,200.00"}}}}',
          200,
        ),
      ),
    );
    final historyApi = GoldHistoryApi(
      client: MockClient(
        (_) async => http.Response(
          '{"data":[{"date":"2026-11-01","buy":62000,"close":62200}]}',
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 1000,
            child: GoldScreen(
              uid: 'test',
              store: store,
              priceApi: priceApi,
              historyApi: historyApi,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('จดทองที่ซื้อ').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'ยอดจ่ายจริงทั้งหมด (บาท)'),
      '100',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('บันทึกทอง'));
    await tester.tap(find.text('บันทึกทอง'));
    await tester.pumpAndSettle();
    expect(store.reads, greaterThanOrEqualTo(2));
    expect(find.textContaining('0.0245'), findsWidgets);
    expect(store.purchases, hasLength(1));
    priceApi.close();
    historyApi.close();
  });
}
