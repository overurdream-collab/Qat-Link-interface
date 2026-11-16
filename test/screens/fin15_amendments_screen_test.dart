import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/screens/fin15_amendments_screen.dart';
import 'package:qat_link/services/fin15_amendment_gateway.dart';

class FakeAmendmentGateway implements Fin15AmendmentGateway {
  int customerRequests=0,merchantDecisions=0;
  Decimal? lastProposed;
  String? lastReason;
  bool? lastAccepted;
  final item=Fin15Amendment(id:'amend-1',status:'pending',
    oldAmount:Decimal.parse('20000'),proposedAmount:Decimal.parse('18000.5'),
    currency:CurrencyCode.yer,reason:'Correct quantity',
    createdAt:DateTime.utc(2026,11,17),originalClaimId:'claim-old',
    customerName:'عميل معروف للتاجر');
  @override
  Future<Fin15Page> list({required bool forMerchant,String? cursor,int limit=50}) async=>
    Fin15Page([item],null);
  @override
  Future<Fin15Amendment> proposeHistorical(String id,{required Decimal amount,
    required String reason,required String idempotencyKey}) async{
    customerRequests++;
    lastProposed=amount;
    lastReason=reason;
    return item;
  }
  @override
  Future<Fin15Amendment> proposeOperation(String r,String o,{required Decimal amount,
    required String reason,required String idempotencyKey}) async=>
    proposeHistorical(o,amount:amount,reason:reason,idempotencyKey:idempotencyKey);
  @override
  Future<Fin15Amendment> merchantDecision(String id,{required bool accept}) async{
    merchantDecisions++;lastAccepted=accept;
    return Fin15Amendment(id:item.id,status:accept?'accepted':'rejected',
      oldAmount:item.oldAmount,proposedAmount:item.proposedAmount,
      currency:item.currency,reason:item.reason,createdAt:item.createdAt,
      originalClaimId:item.originalClaimId,customerName:item.customerName);
  }
}

void main(){
  testWidgets('merchant must confirm exact original/new amount before responding',(tester) async{
    final api=FakeAmendmentGateway();
    await tester.pumpWidget(MaterialApp(home:
      Fin15AmendmentsScreen(gateway:api,forMerchant:true)));
    await tester.pumpAndSettle();
    expect(find.textContaining('عميل معروف للتاجر'),findsOneWidget);
    expect(find.textContaining('18000.5'),findsWidgets);
    await tester.tap(find.byKey(const Key('fin15_accept_amend-1')));
    await tester.pumpAndSettle();
    expect(api.merchantDecisions,0);
    expect(find.textContaining('المبلغ الأصلي'),findsWidgets);
    expect(find.textContaining('المبلغ المقترح'),findsWidgets);
    await tester.tap(find.byKey(const Key('fin15_confirm_merchant_decision')));
    await tester.pumpAndSettle();
    expect(api.merchantDecisions,1);
    expect(api.lastAccepted,true);
  });
  testWidgets('customer proposal sends new exact amount only after explicit submit',(tester) async{
    final api=FakeAmendmentGateway();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(
      builder:(context)=>FilledButton(
        onPressed:()=>showDialog<bool>(context:context,
          builder:(_)=>Fin15AmountProposalDialog(
            gateway:api,originalAmount:Decimal.parse('20000'),
            currency:CurrencyCode.yer,claimId:'claim-old')),
        child:const Text('فتح طلب التعديل')),
    ))));
    await tester.tap(find.text('فتح طلب التعديل'));
    await tester.pumpAndSettle();
    expect(api.customerRequests,0);
    await tester.enterText(find.byKey(const Key('fin15_new_amount')),'18000.5000');
    await tester.enterText(find.byKey(const Key('fin15_change_reason')),'Correct quantity');
    await tester.tap(find.byKey(const Key('fin15_submit_proposal')));
    await tester.pumpAndSettle();
    expect(api.customerRequests,1);
    expect(api.lastProposed,Decimal.parse('18000.5000'));
    expect(api.lastReason,'Correct quantity');
  });
  testWidgets('same original and proposed amount cannot create amendment',(tester) async{
    final api=FakeAmendmentGateway();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(
      builder:(context)=>FilledButton(
        onPressed:()=>showDialog<bool>(context:context,
          builder:(_)=>Fin15AmountProposalDialog(
            gateway:api,originalAmount:Decimal.parse('20000'),
            currency:CurrencyCode.yer,claimId:'claim-old')),
        child:const Text('فتح طلب التعديل')),
    ))));
    await tester.tap(find.text('فتح طلب التعديل'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('fin15_new_amount')),'20000.0000');
    await tester.enterText(find.byKey(const Key('fin15_change_reason')),'Wrong same amount');
    await tester.tap(find.byKey(const Key('fin15_submit_proposal')));
    await tester.pumpAndSettle();
    expect(api.customerRequests,0);
    expect(find.textContaining('مختلفًا عن القيمة الأصلية'),findsOneWidget);
  });
}
