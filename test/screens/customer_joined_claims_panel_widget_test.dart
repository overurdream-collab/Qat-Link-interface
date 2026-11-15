import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/models/merchant_pending_models.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/customers/customer_joined_claims_panel.dart';

void main() {
  final now = DateTime.utc(2026, 11, 15);
  final account = CustomerModel(
    id:'c1',name:'عميل جديد',phone:'771123456',
    primaryCurrency:CurrencyCode.yer,
    createdAt:now,updatedAt:now,
  );
  final contact = MerchantPendingContact(
    id:'contact',merchantId:'merchant1',
    name:'عميل التاجر',phone:'771123456',createdAt:now,
  );
  final claims = [
    for (var i=0;i<3;i++)
      MerchantPendingDebt(
        id:'old$i',merchantId:'merchant1',contactId:'contact',
        amount:Decimal.parse('${i+1}000'),
        currency:CurrencyCode.yer,createdAt:now,
      ),
  ];
  final match = VerifiedCustomerContactMatch(
    merchantId:'merchant1',contactId:'contact',
    customerId:'c1',verifiedAt:now,
  );

  Future<void> launch(WidgetTester tester,{
    List<VerifiedCustomerContactMatch>? matches,
    Future<bool> Function(CustomerClaimReviewRequest)? onReview,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme:AppTheme.light,
      home:Scaffold(body:SingleChildScrollView(
        child:CustomerJoinedClaimsPanel(
          authenticatedCustomerId:'c1',
          customers:[account],contacts:[contact],
          claims:claims,verifiedMatches:matches ?? [match],
          relationships:const [],verifiedDecisions:const [],
          verifiedMerchantNames:const {'merchant1':'متجر الحاشدي'},
          onReview:onReview,
        ),
      )),
    ));
  }

  testWidgets('all old requests appear after joining without being approved',
      (tester) async {
    await launch(tester);
    expect(find.text('طلبات ديون سابقة بانتظار مراجعتك'),findsOneWidget);
    for (var i=0;i<3;i++) {
      expect(find.byKey(Key('joined_claim_old$i')),findsOneWidget);
    }
    expect(find.text('متجر الحاشدي'),findsNWidgets(3));
    expect(find.byKey(const Key('joined_claim_accept_old0')),findsOneWidget);
    final button=tester.widget<FilledButton>(
      find.byKey(const Key('joined_claim_accept_old0')));
    expect(button.onPressed,isNull);
    expect(find.textContaining('تسجيل القرارات غير متصل'),findsNWidgets(3));
  });

  testWidgets('unverified identity sees zero previous claims',
      (tester) async {
    await launch(tester,matches:const []);
    expect(find.text('لا توجد طلبات سابقة مرتبطة بحسابك المتحقق منه.'),
      findsOneWidget);
    expect(find.byKey(const Key('joined_claim_old0')),findsNothing);
  });

  testWidgets('each accept action requires explicit customer confirmation',
      (tester) async {
    CustomerClaimReviewRequest? submitted;
    var calls=0;
    await launch(tester,onReview:(request) async {
      calls++;
      submitted=request;
      return false; // Backend refused: no confirmation or ledger writes.
    });
    await tester.tap(find.byKey(const Key('joined_claim_accept_old0')));
    await tester.pumpAndSettle();
    expect(find.text('الموافقة على طلب الدين؟'),findsOneWidget);
    expect(calls,0);
    await tester.tap(find.byKey(const Key('claim_confirm_decision')));
    await tester.pumpAndSettle();
    expect(calls,1);
    expect(submitted!.customerId,'c1');
    expect(submitted!.merchantId,'merchant1');
    expect(submitted!.claimId,'old0');
    expect(submitted!.decision,PreRegistrationClaimDecision.accept);
    expect(find.textContaining('ظل الطلب معلقاً'),findsOneWidget);
  });

  testWidgets('customer may reject individual claim without approving others',
      (tester) async {
    CustomerClaimReviewRequest? submitted;
    await launch(tester,onReview:(request) async {
      submitted=request; return false;
    });
    await tester.tap(find.byKey(const Key('joined_claim_reject_old0')));
    await tester.pumpAndSettle();
    expect(find.text('رفض طلب الدين؟'),findsOneWidget);
    await tester.tap(find.byKey(const Key('claim_confirm_decision')));
    await tester.pumpAndSettle();
    expect(submitted!.claimId,'old0');
    expect(submitted!.decision,PreRegistrationClaimDecision.reject);
    expect(find.byKey(const Key('joined_claim_old1')),findsOneWidget);
  });
}
