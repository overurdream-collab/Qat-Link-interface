import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/screens/identity_account_screen.dart';
import 'package:qat_link/screens/verified_fin08_overview_screen.dart';
import 'package:qat_link/services/identity_session_client.dart';

void main() {
  for (final role in ['merchant', 'customer']) {
    testWidgets('Verified $role may open only server-backed FIN08 overview',
        (tester) async {
      final session = IdentitySession(
        accessToken: 'test-session-token-not-for-production',
        id: 'test-identity-id',
        role: role,
      );
      await tester.pumpWidget(MaterialApp(
        home: IdentityAccountScreen(session: session),
      ));
      final link = find.byKey(const Key('open_verified_fin08_overview'));
      await tester.scrollUntilVisible(link, 170,
        scrollable: find.byType(Scrollable).first,
      );
      expect(link, findsOneWidget);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(VerifiedFin08OverviewScreen), findsOneWidget);
      expect(find.textContaining('أرصدة تجريبية'), findsNothing);
      // No local demo shell, ledger writes or pre-approved balance navigation.
      expect(find.byKey(const Key('fin08_save_claim')), findsNothing);
      expect(find.byKey(const Key('fin08_save_contact')), findsNothing);
    });
  }
}
