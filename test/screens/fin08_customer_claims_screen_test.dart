import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/screens/fin08_customer_claims_screen.dart';
import 'package:qat_link/services/fin08_api_client.dart';

class FakeFin08Gateway implements Fin08ClaimsGateway {
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
    required CurrencyCode currency,required String idempotencyKey,String? description}) async =>
      throw UnimplementedError();
  @override
  Future<List<Fin08CurrencyBuckets>> merchantClaimSummary() async =>
      throw UnimplementedError();
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
}