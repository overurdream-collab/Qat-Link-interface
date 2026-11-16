import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/screens/fin08_merchant_book_screen.dart';
import 'package:qat_link/services/fin08_api_client.dart';

class MerchantGatewayFake implements Fin08ClaimsGateway {
  final contact=Fin08MerchantContact(
    id:'contact-1',name:'عميل التاجر',phone:'+967771234567',
    createdAt:DateTime.utc(2026,11,16));
  String? priorKey;
  int attempts=0;
  Decimal? lastAmount;

  @override
  Future<Fin08Page<Fin08MerchantContact>> merchantContacts({String? cursor,int limit=50}) async =>
    Fin08Page([contact],null);
  @override
  Future<List<Fin08CurrencyBuckets>> merchantClaimSummary() async =>
    [Fin08CurrencyBuckets(currency:CurrencyCode.yer,
      outsideApp:Decimal.parse('75'),awaitingCustomer:Decimal.zero,
      approvedFromClaims:Decimal.zero)];
  @override
  Future<Fin08Page<Fin08MerchantClaim>> merchantClaims(String contactId,{String? cursor,int limit=50}) async =>
    Fin08Page([Fin08MerchantClaim(id:'claim-1',contactId:contactId,
      amount:Decimal.parse('75'),currency:CurrencyCode.yer,
      createdAt:DateTime.utc(2026,11,16),stage:Fin08Stage.outsideApp)],null);
  @override
  Future<Fin08ClaimReceipt> createMerchantClaim({required String contactId,
      required Decimal amount,required CurrencyCode currency,
      required String idempotencyKey,String? description}) async {
    attempts++;
    lastAmount=amount;
    if(priorKey==null)priorKey=idempotencyKey;
    else if(priorKey!=idempotencyKey)throw const Fin08ApiError('مفتاح مكرر غير ثابت');
    if(attempts==1) throw const Fin08ApiError('فشل مؤقت من الخادم');
    return const Fin08ClaimReceipt(claimId:'claim-new',replayed:false);
  }
  @override
  Future<Fin08MerchantContact> createMerchantContact({required String name,required String phone}) async =>contact;
  @override
  Future<Fin08Page<Fin08PreviousClaim>> customerPreviousClaims({String? cursor,int limit=50}) async =>throw UnimplementedError();
  @override
  Future<Fin08ClaimDecisionReceipt> decidePreviousClaim(String claimId,{required bool accept}) async =>throw UnimplementedError();
}

void main(){
  testWidgets('restores merchant contacts and shows pending amounts as non-approved', (tester) async {
    final api=MerchantGatewayFake();
    await tester.pumpWidget(MaterialApp(home:Fin08MerchantBookScreen(gateway:api)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin08_contact_contact-1')),findsOneWidget);
    expect(find.textContaining('معتمد من هذه المطالبات فقط: 0'),findsOneWidget);
    await tester.tap(find.byKey(const Key('fin08_contact_contact-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin08_merchant_claim_claim-1')),findsOneWidget);
    expect(find.textContaining('غير معتمد'),findsWidgets);
  });

  testWidgets('failed claim save retains idempotency key on retry, does not claim approval', (tester) async {
    final api=MerchantGatewayFake();
    await tester.pumpWidget(MaterialApp(home:Fin08MerchantBookScreen(gateway:api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin08_contact_contact-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل دين معلق'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first,'1250.50');
    await tester.tap(find.byKey(const Key('fin08_save_claim')));
    await tester.pumpAndSettle();
    expect(find.text('فشل مؤقت من الخادم'),findsOneWidget);
    expect(api.attempts,1);
    await tester.tap(find.byKey(const Key('fin08_save_claim')));
    await tester.pumpAndSettle();
    expect(api.attempts,2);
    expect(api.lastAmount,Decimal.parse('1250.50'));
    expect(api.priorKey,isNotNull);
    expect(find.byKey(const Key('fin08_merchant_claim_claim-1')),findsOneWidget);
  });
}