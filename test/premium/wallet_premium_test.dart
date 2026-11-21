import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/widgets/home/new_currency_card.dart';

void main() {
  testWidgets('YER premium wallet keeps approved and pending separated', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 340,
            height: 230,
            child: NewCurrencyCard(
              data: CurrencyCardData(
                currency: CurrencyCode.yer,
                debts: '1,000',
                balance: '700',
                payments: '300',
                pending: '200',
                collectionRate: .3,
              ),
            ),
          ),
        ),
      ),
    ));

    expect(find.text('صافي الرصيد المعتمد'), findsOneWidget);
    expect(find.text('700'), findsOneWidget);
    expect(find.text('1,000'), findsNothing);
    expect(find.text('300'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
    expect(find.text('المسدد المعتمد'), findsOneWidget);
    expect(find.text('المعلق'), findsOneWidget);
    expect(find.text('USD'), findsNothing);
    expect(find.text('SAR'), findsNothing);
  });
}
