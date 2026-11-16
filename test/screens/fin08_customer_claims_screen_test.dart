import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/screens/fin08_customer_claims_screen.dart';
import 'package:qat_link/services/fin08_api_client.dart';

class FakeFin08Gateway implements Fin08ClaimsGateway {
  @override
  Future<Fin08BatchReceipt> decidePreviousClaimsBatch(List<String> claimIds,{required bool accept}) async =>
    throw UnimplementedError('Only customer-batch fake implements the new operation');

  final first=Fin08PreviousClaim(
    id:'claim-one',merchantId:'merchant-one',merchantName:'متجر الأصالة',
    amount:Decimal.parse('1250'),currency:CurrencyCode.yer,
    createdAt:DateTime.utc(2026,11,15),stage:Fin08Stage.awaitingReview,
  );
  final second=Fin08PreviousClaim(
    id:'claim-two',merchantId:'merchant-two',merchantName:'متجر آخر',
    amount:Decimal.parse('55'),currency:CurrencyCode.usd,
    createdAt:DateTime.utc(2026,11,14),stage:Fin08Stage.rejected,
  );
  bool fail=false;
  int submitted=0;
  String? lastClaim;
  bool? lastAccepted;

  @override
  Future<Fin08Page<Fin08PreviousClaim>> customerPreviousClaims({String? cursor,int limit=50}) async =>
      Fin08Page(cursor==null?[first]:[second],cursor==null?'cursor-2':null);

  @override
  Future<Fin08ClaimDecisionReceipt> decidePreviousClaim(String claimId,{required bool accept}) async {
    submitted++;
    lastClaim=claimId;
    lastAccepted=accept;
    if(fail) throw const Fin08ApiError('رفض الخادم الحفظ');
    return Fin08ClaimDecisionReceipt(claimId:claimId,decision:accept?'accept':'reject',
      recorded:true,ledgerPosted:false);
  }

  @override
  Future<String> requestMerchantRelationship(String contactId) async => throw UnimplementedError();
  @override
  Future<Fin08Page<Fin08CustomerRelationship>> customerRelationships({String? cursor,int limit=50}) async =>
    const Fin08Page<Fin08CustomerRelationship>([],null);
  @override
  Future<Fin08RelationshipReceipt> decideRelationship(String relationshipId,{required bool accept}) async =>
    throw UnimplementedError();
  @override
  Future<Fin08Page<Fin08MerchantContact>> merchantContacts({String? cursor,int limit=50}) async =>
      throw UnimplementedError();
  @override
  Future<Fin08Page<Fin08MerchantClaim>> merchantClaims(String contactId,{String? cursor,int limit=50}) async =>
      throw UnimplementedError();
  @override
  Future<Fin08MerchantContact> createMerchantContact({required String name,required String phone}) async =>
      throw UnimplementedError();
  @override
  Future<Fin08ClaimReceipt> createMerchantClaim({required String contactId,required Decimal amount,
    required CurrencyCode currency,required String idempotencyKey,String? description,MovementType type=MovementType.debt}) async =>
      throw UnimplementedError();
  @override
  Future<List<Fin08CurrencyBuckets>> merchantClaimSummary() async =>
      throw UnimplementedError();
}

class BatchGatewayFake extends FakeFin08Gateway {
  int batchCalls=0;
  bool batchFailure=false;
  List<String>? chosenIds;
  bool? chosenAccept;
  final pendingPayment=Fin08PreviousClaim(
    id:'payment-pending',merchantId:'merchant-one',merchantName:'متجر الأصالة',
    amount:Decimal.parse('10.50'),currency:CurrencyCode.usd,
    createdAt:DateTime.utc(2026,11,16),stage:Fin08Stage.awaitingReview,
    type:MovementType.payment,
  );
  @override
  Future<Fin08Page<Fin08PreviousClaim>> customerPreviousClaims({
      String? cursor,int limit=50}) async =>
    Fin08Page([first,pendingPayment],null);
  @override
  Future<Fin08BatchReceipt> decidePreviousClaimsBatch(
      List<String> claimIds,{required bool accept}) async {
    batchCalls++;
    chosenIds=claimIds;
    chosenAccept=accept;
    if(batchFailure)throw const Fin08ApiError('فشل ذري من الخادم',statusCode:409);
    return Fin08BatchReceipt(accept?'accept':'reject',claimIds.length,
      claimIds.length,0,[
        Fin08BatchCurrencyTotal(CurrencyCode.yer,MovementType.debt,
          Decimal.parse('1250'),1),
        Fin08BatchCurrencyTotal(CurrencyCode.usd,MovementType.payment,
          Decimal.parse('10.50'),1),
      ]);
  }
}

void main() {
  Future<void> launch(WidgetTester tester,FakeFin08Gateway api) async {
    await tester.pumpWidget(MaterialApp(home:Fin08CustomerClaimsScreen(gateway:api)));
    await tester.pumpAndSettle();
  }

  testWidgets('renders pending verified claim, but no automatic accept', (tester) async {
    final api=FakeFin08Gateway();
    await launch(tester,api);
    expect(find.byKey(const Key('fin08_claim_claim-one')),findsOneWidget);
    expect(find.text('متجر الأصالة'),findsOneWidget);
    expect(find.byKey(const Key('fin08_accept_claim-one')),findsOneWidget);
    expect(api.submitted,0);
    await tester.tap(find.byKey(const Key('fin08_accept_claim-one')));
    await tester.pumpAndSettle();
    expect(find.text('الموافقة على هذا الدين؟'),findsOneWidget);
    expect(api.submitted,0);
    await tester.tap(find.byKey(const Key('fin08_confirm_claim_decision')));
    await tester.pumpAndSettle();
    expect(api.submitted,1);
    expect(api.lastClaim,'claim-one');
    expect(api.lastAccepted,true);
  });

  testWidgets('backend failure does not claim success; older requests paginated', (tester) async {
    final api=FakeFin08Gateway()..fail=true;
    await launch(tester,api);
    await tester.tap(find.byKey(const Key('fin08_load_more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin08_claim_claim-two')),findsOneWidget);
    expect(find.byKey(const Key('fin08_accept_claim-two')),findsNothing);
    await tester.tap(find.byKey(const Key('fin08_reject_claim-one')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin08_confirm_claim_decision')));
    await tester.pumpAndSettle();
    expect(api.lastAccepted,false);
    expect(find.textContaining('رفض الخادم الحفظ'),findsWidgets);
    expect(find.byKey(const Key('fin08_accept_claim-one')),findsOneWidget);
  });
  testWidgets('batch requires explicit item selection, previews each currency and never approves relation', (tester) async {
    final api=BatchGatewayFake();
    await launch(tester,api);
    await tester.tap(find.byKey(const Key('fin14_batch_toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin14_select_claim-one')),findsOneWidget);
    expect(find.byKey(const Key('fin14_select_payment-pending')),findsOneWidget);
    expect(api.batchCalls,0);
    await tester.tap(find.byKey(const Key('fin14_select_claim-one')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin14_select_payment-pending')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin14_batch_accept')));
    await tester.pumpAndSettle();
    expect(api.batchCalls,0);
    expect(find.textContaining('ديون YER'),findsWidgets);
    expect(find.textContaining('دفعات USD'),findsWidgets);
    expect(find.textContaining('متجر الأصالة'),findsWidgets);
    await tester.tap(find.byKey(const Key('fin14_confirm_batch_decision')));
    await tester.pumpAndSettle();
    expect(api.batchCalls,1);
    expect(api.chosenAccept,true);
    expect(api.chosenIds!.toSet(),{'claim-one','payment-pending'});
    expect(find.byKey(const Key('fin14_batch_accept')),findsNothing);
  });

  testWidgets('failed batch does not clear selection or show local approval', (tester) async {
    final api=BatchGatewayFake()..batchFailure=true;
    await launch(tester,api);
    await tester.tap(find.byKey(const Key('fin14_batch_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin14_select_claim-one')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin14_batch_reject')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin14_confirm_batch_decision')));
    await tester.pumpAndSettle();
    expect(api.batchCalls,1);
    expect(find.textContaining('فشل ذري من الخادم'),findsWidgets);
    expect(find.byKey(const Key('fin14_batch_reject')),findsOneWidget);
    expect(find.byKey(const Key('fin14_select_claim-one')),findsOneWidget);
  });

}