import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/main.dart';
import 'package:qat_link/services/maqwati_api_config.dart';
import 'package:qat_link/screens/fin25_otp_screen.dart';

/// Run ONLY with --dart-define=MAQWATI_API_BASE_URL=https://api.example.test
void main() {
  test('one approved HTTPS origin is shared across FIN25 and Identity', () {
    expect(MaqwatiApiConfig.origin, Uri.parse('https://api.example.test/'));
  });

  testWidgets('login opens the real OTP->Identity flow without pilot setup',
      (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    await tester.enterText(find.byKey(const Key('login_phone')), '771234567');
    await tester.ensureVisible(find.byKey(const Key('login_with_otp')));
    await tester.tap(find.byKey(const Key('login_with_otp')));
    await tester.pumpAndSettle();
    final otp = tester.widget<Fin25OtpScreen>(find.byType(Fin25OtpScreen));
    expect(otp.baseUri, MaqwatiApiConfig.origin);
    expect(otp.identityBaseUri, MaqwatiApiConfig.origin);
    expect(otp.manualRequestIdOnly, isFalse);
    expect(find.byKey(const Key('otp_request')), findsOneWidget);
    expect(find.byKey(const Key('pilot_url')), findsNothing);
    expect(find.byKey(const Key('pilot_access_key')), findsNothing);
    expect(find.byKey(const Key('otp_manual_request_id')), findsNothing);
    // Neither a financial dashboard nor an SMS request is created by navigation.
    expect(find.text('الحركة'), findsNothing);
  });

  testWidgets('registration uses same origin and explicitly requested role',
      (tester) async {
    await tester.pumpWidget(const QatLinkApp());
    await tester.ensureVisible(find.byKey(const Key('open_registration')));
    await tester.tap(find.byKey(const Key('open_registration')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('register_name')), 'متجر تجريبي');
    await tester.enterText(find.byKey(const Key('register_phone')), '771234567');
    await tester.enterText(find.byKey(const Key('register_pin')), '1234');
    await tester.enterText(find.byKey(const Key('register_confirm_pin')), '1234');
    await tester.ensureVisible(find.byKey(const Key('register_submit')));
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();
    final otp = tester.widget<Fin25OtpScreen>(find.byType(Fin25OtpScreen));
    expect(otp.baseUri, MaqwatiApiConfig.origin);
    expect(otp.identityBaseUri, MaqwatiApiConfig.origin);
    expect(otp.requestedRole, 'merchant');
    expect(otp.displayName, 'متجر تجريبي');
  });
}
