import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/screens/fin08_customer_relationships_screen.dart';
import 'package:qat_link/services/fin08_api_client.dart';

class RelationshipGatewayFake implements Fin08ClaimsGateway {
  RelationshipGatewayFake({this.status='pending'});
  final String status;
  int decisions=0;
  bool failure=false;
  bool? accepted;
  late final relation=Fin08CustomerRelationship(id:'relationship-one',
    merchantId:'merchant-one',merchantName:'متجر الأمانة',status:status,
    createdAt:DateTime.utc(2026,11,16));
  @override
  Future<Fin08Page<Fin08CustomerRelationship>> customerRelationships({String? cursor,int limit=50}) async =>
    Fin08Page([relation],null);
  @override
  Future<Fin08RelationshipReceipt> decideRelationship(String relationshipId,{required bool accept}) async {
    decisions++;accepted=accept;
    if(failure)throw const Fin08ApiError('لم يتم الحفظ');
    return Fin08RelationshipReceipt(relationshipId:relationshipId,
      status:accept?'approved':'rejected',newlyPostedDebts:0);
  }
  @override
  Future<String> requestMerchantRelationship(String contactId) async=>throw UnimplementedError();
  @override
  Future<Fin08Page<Fin08MerchantContact>> merchantContacts({String? cursor,int limit=50,String? search,MovementType? type,CurrencyCode? currency,String? from,String? to,String sort='newest'}) async=>throw UnimplementedError();
  @override
  Future<Fin08Page<Fin08MerchantClaim>> merchantClaims(String contactId,{String? cursor,int limit=50,String? search,MovementType? type,CurrencyCode? currency,String? from,String? to,String sort='newest'}) async=>throw UnimplementedError();
  @override
  Future<Fin08MerchantContact> createMerchantContact({required String name,required String phone}) async=>throw UnimplementedError();
  @override
  Future<Fin08ClaimReceipt> createMerchantClaim({required String contactId,required Decimal amount,
    required CurrencyCode currency,required String idempotencyKey,String? description,MovementType type=MovementType.debt}) async=>throw UnimplementedError();
  @override
  Future<List<Fin08CurrencyBuckets>> merchantClaimSummary() async=>throw UnimplementedError();
  @override
  Future<Fin08Page<Fin08PreviousClaim>> customerPreviousClaims({String? cursor,int limit=50}) async=>throw UnimplementedError();
  @override
  Future<Fin08ClaimDecisionReceipt> decidePreviousClaim(String claimId,{required bool accept}) async=>throw UnimplementedError();
}

void main(){
  testWidgets('relationship consent requires distinct confirmation and never silently approves debts', (tester) async {
    final api=RelationshipGatewayFake();
    await tester.pumpWidget(MaterialApp(home:Fin08CustomerRelationshipsScreen(gateway:api)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin10_relationship_relationship-one')),findsOneWidget);
    expect(find.text('متجر الأمانة'),findsOneWidget);
    expect(api.decisions,0);
    await tester.tap(find.byKey(const Key('fin10_accept_relationship-one')));
    await tester.pumpAndSettle();
    expect(api.decisions,0);
    await tester.tap(find.byKey(const Key('fin10_confirm_relationship')));
    await tester.pumpAndSettle();
    expect(api.decisions,1);
    expect(api.accepted,true);
    expect(find.textContaining('لم تتم موافقة تلقائية'),findsWidgets);
  });
  testWidgets('approved relationship opens the ledger through the callback', (tester) async {
    final api=RelationshipGatewayFake(status:'approved');
    String? opened;
    await tester.pumpWidget(MaterialApp(home:Fin08CustomerRelationshipsScreen(
      gateway:api,
      onOpenLedger:(relationship)=>opened=relationship.id,
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin10_accept_relationship-one')),findsNothing);
    final button=find.byKey(const Key('fin13_open_ledger_relationship-one'));
    expect(button,findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(opened,'relationship-one');
  });
  testWidgets('pending relationship does not expose the ledger button', (tester) async {
    final api=RelationshipGatewayFake();
    await tester.pumpWidget(MaterialApp(home:Fin08CustomerRelationshipsScreen(
      gateway:api,
      onOpenLedger:(_)=>fail('must not open before approval'),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin13_open_ledger_relationship-one')),findsNothing);
  });
  testWidgets('failed relationship rejection stays pending in displayed state', (tester) async {
    final api=RelationshipGatewayFake()..failure=true;
    await tester.pumpWidget(MaterialApp(home:Fin08CustomerRelationshipsScreen(gateway:api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin10_reject_relationship-one')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin10_confirm_relationship')));
    await tester.pumpAndSettle();
    expect(api.accepted,false);
    expect(find.textContaining('لم يتم الحفظ'),findsWidgets);
    expect(find.byKey(const Key('fin10_accept_relationship-one')),findsOneWidget);
  });
}