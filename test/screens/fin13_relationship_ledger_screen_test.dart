import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/screens/fin13_relationship_ledger_screen.dart';
import 'package:qat_link/services/fin13_ledger_gateway.dart';
import 'package:qat_link/services/fin14_batch_gateway.dart';

class FakeLedger implements Fin13LedgerGateway {
  int decisions=0,creations=0,policies=0;
  MovementType? createdType;
  Decimal? amount;
  bool enabled=false;
  @override
  Future<Fin13Balances> balances(String id) async=>Fin13Balances(id,[
    Fin13CurrencyBalance(CurrencyCode.yer,Decimal.parse('20000'),
      Decimal.parse('30000'),Decimal.parse('-10000')),
    Fin13CurrencyBalance(CurrencyCode.sar,Decimal.zero,Decimal.zero,Decimal.zero),
    Fin13CurrencyBalance(CurrencyCode.usd,Decimal.zero,Decimal.zero,Decimal.zero)
  ]);
  @override
  Future<Fin13Page> operations(String id,{String? cursor,int limit=50}) async=>Fin13Page([
    Fin13Operation('op-1',MovementType.debt,Decimal.parse('15000'),
      CurrencyCode.yer,'pending','merchant-1','merchant',
      DateTime.utc(2026,11,17),'manual',null,null),
  ],null);
  @override
  Future<Fin13Policy> policy(String id) async=>Fin13Policy(enabled,policies,null);
  @override
  Future<Fin13Policy> setPolicy(String id,{required bool enabled}) async{
    this.enabled=enabled;policies++;return policy(id);
  }
  @override
  Future<Fin13Receipt> decide(String id,String op,{required bool accept}) async {
    decisions++;return Fin13Receipt(op,accept?'approved':'rejected',false,accept,null);
  }
  @override
  Future<Fin13Receipt> create(String id,{required MovementType type,
      required Decimal amount,required CurrencyCode currency,
      required String idempotencyKey,String? description}) async {
    creations++;createdType=type;this.amount=amount;
    return const Fin13Receipt('new-op','pending',false,false,'manual');
  }
  @override
  Future<Fin13Receipt> reverse(String id,String movement,{
      required String reason,required String idempotencyKey}) async=>
      const Fin13Receipt('rev','pending',false,false,null);
  @override
  Future<Fin13Statement> statement(String id,CurrencyCode unit,String from,String to) async=>
    Fin13Statement(unit,from,to,Decimal.zero,Decimal.zero,
      Decimal.zero,Decimal.zero,const []);
}
class FakeOperationBatch implements Fin14BatchGateway {
  int submitted=0;
  bool failure=false;
  String? relationship;
  Map<String,bool>? decisions;
  @override
  Future<Fin14BatchResult> decideHistorical(Map<String,bool> selected) async =>
      throw UnimplementedError();
  @override
  Future<Fin14BatchResult> decideRelationship(String id,Map<String,bool> selected) async {
    submitted++;
    relationship=id;
    decisions=selected;
    if(failure)throw const FormatException('Server declined batch');
    return Fin14BatchResult(1,'selected_relationship_operations_only',[
      for(final entry in selected.entries) {
        'id':entry.key,'status':entry.value?'approved':'rejected'
      }
    ],[Fin14ReviewTotal(CurrencyCode.yer,Decimal.parse('15000'),Decimal.zero,
      Decimal.parse('15000'))]);
  }
}

void main(){
  testWidgets('customer ledger displays server credit, approves only other party and controls future policy',(tester) async{
    final fake=FakeLedger();
    await tester.pumpWidget(MaterialApp(home:Fin13RelationshipLedgerScreen(
      gateway:fake,relationshipId:'rel-1',actorId:'customer-1',
      role:ParticipantRole.customer)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin13_approved_net')),findsOneWidget);
    expect(find.textContaining('-10000'),findsWidgets);
    expect(find.text('رصيد دائن لصالح العميل'),findsOneWidget);
    expect(find.byKey(const Key('fin13_auto_policy')),findsOneWidget);
    expect(find.byKey(const Key('fin13_new_debt')),findsNothing);
    expect(find.byKey(const Key('fin13_new_payment')),findsOneWidget);
    expect(find.text('موافقة'),findsOneWidget);
    await tester.tap(find.text('موافقة'));
    await tester.pumpAndSettle();
    expect(fake.decisions,0); // Requires explicit confirmation.
    await tester.tap(find.byKey(const Key('fin13_confirm_decision')));
    await tester.pumpAndSettle();
    expect(fake.decisions,1);
    await tester.tap(find.byKey(const Key('fin13_auto_policy')));
    await tester.pumpAndSettle();
    expect(fake.policies,0);
    await tester.tap(find.byKey(const Key('fin13_confirm_policy')));
    await tester.pumpAndSettle();
    expect(fake.enabled,true);
    expect(fake.policies,1);
  });
  testWidgets('merchant new debt posts only a server request and never changes displayed balances',(tester) async{
    final fake=FakeLedger();
    await tester.pumpWidget(MaterialApp(home:Fin13RelationshipLedgerScreen(
      gateway:fake,relationshipId:'rel-1',actorId:'merchant-1',
      role:ParticipantRole.merchant)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin13_auto_policy')),findsNothing);
    expect(find.byKey(const Key('fin13_new_debt')),findsOneWidget);
    await tester.tap(find.byKey(const Key('fin13_new_debt')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('fin13_amount')),'12.3456');
    await tester.tap(find.byKey(const Key('fin13_submit_operation')));
    await tester.pumpAndSettle();
    expect(fake.creations,1);
    expect(fake.createdType,MovementType.debt);
    expect(fake.amount,Decimal.parse('12.3456'));
    expect(find.textContaining('-10000'),findsWidgets);
    // Merchant must not decide the debt he just created.
    expect(find.text('موافقة'),findsNothing);
  });
  testWidgets('FIN-14 selects registered operation and requires explicit confirmation',(tester) async {
    final ledger=FakeLedger();
    final batch=FakeOperationBatch();
    await tester.pumpWidget(MaterialApp(home:Fin13RelationshipLedgerScreen(
      gateway:ledger,batchGateway:batch,relationshipId:'rel-1',
      actorId:'customer-1',role:ParticipantRole.customer)));
    await tester.pumpAndSettle();
    final select=find.byKey(const Key('fin14_select_operation_op-1'));
    await tester.ensureVisible(select);
    await tester.tap(select);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('fin14_operation_batch_accept')));
    await tester.tap(find.byKey(const Key('fin14_operation_batch_accept')));
    await tester.pumpAndSettle();
    expect(batch.submitted,0);
    expect(find.textContaining('صافي تقديري غير معتمد'),findsWidgets);
    await tester.tap(find.byKey(const Key('fin14_confirm_operation_batch')));
    await tester.pumpAndSettle();
    expect(batch.submitted,1);
    expect(batch.relationship,'rel-1');
    expect(batch.decisions,{'op-1':true});
    expect(find.byKey(const Key('fin14_operation_batch_accept')),findsNothing);
    expect(ledger.decisions,0);
  });

  testWidgets('FIN-14 creator cannot check/select own pending operation',(tester) async {
    final ledger=FakeLedger();
    final batch=FakeOperationBatch();
    await tester.pumpWidget(MaterialApp(home:Fin13RelationshipLedgerScreen(
      gateway:ledger,batchGateway:batch,relationshipId:'rel-1',
      actorId:'merchant-1',role:ParticipantRole.merchant)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin14_select_operation_op-1')),findsNothing);
    expect(find.byKey(const Key('fin14_operation_batch_accept')),findsNothing);
    expect(batch.submitted,0);
  });

}
