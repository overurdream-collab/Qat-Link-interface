import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/screens/merchant_approval_center_screen.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  testWidgets('approval inbox separates directions and never fakes a decision',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: MerchantApprovalCenterScreen(state: state),
    ));

    expect(find.text('تحتاج موافقتي'), findsOneWidget);
    expect(find.text('لا توجد عمليات تنتظر قرارك'), findsOneWidget);
    expect(find.text('اعتماد'), findsNothing);
    expect(find.text('رفض'), findsNothing);
    await tester.tap(find.text('بانتظار العميل'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد عمليات بانتظار العميل'), findsOneWidget);
    expect(find.textContaining('لا يمكن اعتماد أو رفض عملية'), findsOneWidget);
  });
}
