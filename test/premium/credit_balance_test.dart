import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/widgets/home/new_currency_card.dart';

void main() {
  testWidgets('Negative approved net is labelled as credit to customer', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 340, height: 230,
        child: NewCurrencyCard(data: CurrencyCardData(
          currency: CurrencyCode.yer,
          debts: '100',
          payments: '200',
          pending: '50',
          balance: '-100',
          isCredit: true,
          collectionRate: 1,
        )),
      )),
    ));
    expect(find.text('رصيد دائن لصالح العميل'), findsOneWidget);
    expect(find.text('-100'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
  });
}
