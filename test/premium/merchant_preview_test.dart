import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/features/auth/registration_role.dart';
import 'package:qat_link/screens/login_screen.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  testWidgets('Merchant design preview is explicitly distinct from login', (tester) async {
    var previewCount = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(dark: false),
      home: LoginScreen(
        isDark: false,
        onToggleTheme: () {},
        onGenderChanged: (ProfileGender _) {},
        onOpenCustomerPreview: () {},
        onOpenMerchantPreview: () => previewCount++,
      ),
    ));

    final preview = find.byKey(const Key('open_merchant_preview'));
    expect(preview, findsOneWidget);
    expect(find.textContaining('المعاينة تجريبية فقط'), findsOneWidget);
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pump();
    expect(previewCount, 1);
  });
}
