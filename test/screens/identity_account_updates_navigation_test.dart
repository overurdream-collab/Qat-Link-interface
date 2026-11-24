import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/screens/identity_account_screen.dart';
import 'package:qat_link/services/identity_session_client.dart';

void main() {
  testWidgets('verified customer can open empty updates without fake financial data',
      (tester) async {
    const session = IdentitySession(
      accessToken: 'test-token-not-a-real-jwt',
      id: 'synthetic-customer',
      role: 'customer',
    );
    await tester.pumpWidget(const MaterialApp(
      home: IdentityAccountScreen(session: session),
    ));
    expect(find.byKey(const Key('customer_open_updates')), findsOneWidget);
    await tester.tap(find.byKey(const Key('customer_open_updates')));
    await tester.pumpAndSettle();
    expect(find.text('تنبيهاتي وحجوزاتي'), findsWidgets);
    expect(find.text('لا توجد تنبيهات جديدة مرتبطة بحسابك.'), findsOneWidget);
    expect(find.text('تم اعتماد الدين'), findsNothing);
  });
}
