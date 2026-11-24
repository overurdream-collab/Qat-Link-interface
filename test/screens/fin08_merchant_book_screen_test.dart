import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/screens/fin08_merchant_book_screen.dart';
import 'package:qat_link/services/fin08_api_client.dart';

class MerchantGatewayFake implements Fin08ClaimsGateway {
  MerchantGatewayFake({this.relationshipStatus});
  final String? relationshipStatus;
  final contact=Fin08MerchantContact(
    id:'contact-1',name:'عميل التاجر',phone:'+967771234567',
    createdAt:DateTime.utc(2026,11,16));
  String? priorKey;
  String? lastContactSearch;
  String? lastClaimSearch;
  MovementType? lastClaimType;
  CurrencyCode? lastClaimCurrency;
  String? lastClaimFrom;
  String? lastClaimTo;
  String? lastClaimSort;
  int attempts=0;
  Decimal? lastAmount;
  MovementType? lastType;
  String? lastContactName;
  String? lastContactPhone;

  @override
  Future<String> requestMerchantRelationship(String contactId) async => throw UnimplementedError();
  @override
  Future<Fin08Page<Fin08CustomerRelationship>> customerRelationships({String? cursor,int limit=50}) async =>
    const Fin08Page<Fin08CustomerRelationship>([],null);
  @override
  Future<Fin08RelationshipReceipt> decideRelationship(String relationshipId,{required bool accept}) async =>
    throw UnimplementedError();
  @override
  Future<Fin08Page<Fin08MerchantContact>> merchantContacts({String? cursor,int limit=50,String? search,MovementType? type,CurrencyCode? currency,String? from,String? to,String sort='newest'}) async {
    lastContactSearch=search;
    if(search!=null && !contact.name.contains(search) && !contact.phone.contains(search)) {
      return const Fin08Page<Fin08MerchantContact>([],null);
    }
    return Fin08Page([contact],null);
  }
  @override
  Future<List<Fin08CurrencyBuckets>> merchantClaimSummary() async =>
    [Fin08CurrencyBuckets(currency:CurrencyCode.yer,
      outsideApp:Decimal.parse('75'),awaitingCustomer:Decimal.zero,
      approvedFromClaims:Decimal.zero)];
  @override
  Future<Fin08Page<Fin08MerchantClaim>> merchantClaims(String contactId,{String? cursor,int limit=50,String? search,MovementType? type,CurrencyCode? currency,String? from,String? to,String sort='newest'}) async {
    lastClaimSearch=search;
    lastClaimType=type;
    lastClaimCurrency=currency;
    lastClaimFrom=from;
    lastClaimTo=to;
    lastClaimSort=sort;
    if(search!=null && !'75'.contains(search)) {
      return const Fin08Page<Fin08MerchantClaim>([],null);
    }
    if(type!=null && type!=MovementType.debt) {
      return const Fin08Page<Fin08MerchantClaim>([],null);
    }
    if(currency!=null && currency!=CurrencyCode.yer) {
      return const Fin08Page<Fin08MerchantClaim>([],null);
    }
    return Fin08Page([Fin08MerchantClaim(id:'claim-1',contactId:contactId,
      amount:Decimal.parse('75'),currency:CurrencyCode.yer,
      createdAt:DateTime.utc(2026,11,16),stage:Fin08Stage.outsideApp,
      relationshipId:relationshipStatus==null?null:'relationship-1',
      relationshipStatus:relationshipStatus)],null);
  }
  @override
  Future<Fin08ClaimReceipt> createMerchantClaim({required String contactId,
      required Decimal amount,required CurrencyCode currency,
      required String idempotencyKey,String? description,MovementType type=MovementType.debt}) async {
    attempts++;
    lastAmount=amount;
    lastType=type;
    if(priorKey==null)priorKey=idempotencyKey;
    else if(priorKey!=idempotencyKey)throw const Fin08ApiError('مفتاح مكرر غير ثابت');
    if(attempts==1) throw const Fin08ApiError('فشل مؤقت من الخادم');
    return const Fin08ClaimReceipt(claimId:'claim-new',replayed:false);
  }
  @override
  Future<Fin08MerchantContact> createMerchantContact({required String name,required String phone}) async {
    lastContactName=name;
    lastContactPhone=phone;
    return contact;
  }
  @override
  Future<Fin08Page<Fin08PreviousClaim>> customerPreviousClaims({String? cursor,int limit=50}) async =>throw UnimplementedError();
  @override
  Future<Fin08ClaimDecisionReceipt> decidePreviousClaim(String claimId,{required bool accept}) async =>throw UnimplementedError();
}

class MultiPageStatementGateway extends MerchantGatewayFake {
  bool failSecondPage=false;
  int restoreCalls=0;

  @override
  Future<Fin08Page<Fin08MerchantClaim>> merchantClaims(String contactId,{String? cursor,int limit=50,String? search,MovementType? type,CurrencyCode? currency,String? from,String? to,String sort='newest'}) async {
    restoreCalls++;
    if(cursor==null)return Fin08Page([
      Fin08MerchantClaim(id:'pending-a',contactId:contactId,
        amount:Decimal.parse('100.25'),currency:CurrencyCode.yer,
        stage:Fin08Stage.outsideApp,createdAt:DateTime.utc(2026,11,15)),
      Fin08MerchantClaim(id:'approved-old',contactId:contactId,
        amount:Decimal.parse('990'),currency:CurrencyCode.yer,
        stage:Fin08Stage.approved,createdAt:DateTime.utc(2026,11,15)),
    ],'next-cursor');
    if(failSecondPage)throw const Fin08ApiError('تعذر قراءة الصفحة الثانية');
    return Fin08Page([
      Fin08MerchantClaim(id:'pending-b',contactId:contactId,
        amount:Decimal.parse('19.75'),currency:CurrencyCode.yer,
        stage:Fin08Stage.awaitingReview,createdAt:DateTime.utc(2026,11,16)),
      Fin08MerchantClaim(id:'pending-usd',contactId:contactId,
        amount:Decimal.parse('7'),currency:CurrencyCode.usd,
        stage:Fin08Stage.acceptedAwaitingRelationship,createdAt:DateTime.utc(2026,11,16)),
    ],null);
  }
}

void main(){
  // The widget test does not use the device clipboard plugin. Capture calls
  // synchronously via the platform channel and prove failed pagination never
  // publishes a partial financial statement.
  String? capturedStatement;
  setUp(() {
    capturedStatement = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        capturedStatement = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
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

  testWidgets('server-backed search filters contacts and claims without local guessing', (tester) async {
    final api=MerchantGatewayFake();
    await tester.pumpWidget(MaterialApp(home:Fin08MerchantBookScreen(gateway:api)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('fin08_contact_search')),'غير موجود');
    await tester.pump(const Duration(milliseconds:400));
    await tester.pumpAndSettle();
    expect(api.lastContactSearch,'غير موجود');
    expect(find.byKey(const Key('fin08_contact_contact-1')),findsNothing);
    expect(find.textContaining('لا توجد نتائج مطابقة'),findsOneWidget);

    await tester.enterText(find.byKey(const Key('fin08_contact_search')),'عميل');
    await tester.pump(const Duration(milliseconds:400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin08_contact_contact-1')));
    await tester.pumpAndSettle();
    expect(api.lastClaimSearch,isNull);

    await tester.enterText(find.byKey(const Key('fin08_claim_search')),'999');
    await tester.pump(const Duration(milliseconds:400));
    await tester.pumpAndSettle();
    expect(api.lastClaimSearch,'999');
    expect(find.byKey(const Key('fin08_merchant_claim_claim-1')),findsNothing);
    expect(find.textContaining('لا توجد مطالبات مطابقة'),findsOneWidget);
  });

  testWidgets('unregistered customer is saved on the server and restored from it', (tester) async {
    final api=MerchantGatewayFake();
    await tester.pumpWidget(MaterialApp(home:Fin08MerchantBookScreen(gateway:api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('fin08_contact_name')),'عميل جديد');
    await tester.enterText(find.byKey(const Key('fin08_contact_phone')),'+967771234567');
    await tester.tap(find.byKey(const Key('fin08_save_contact')));
    await tester.pumpAndSettle();
    expect(api.lastContactName,'عميل جديد');
    expect(api.lastContactPhone,'+967771234567');
    expect(find.byKey(const Key('fin08_contact_contact-1')),findsOneWidget);
  });

  testWidgets('claim type and currency filters are applied by the server query', (tester) async {
    final api=MerchantGatewayFake();
    await tester.pumpWidget(MaterialApp(home:Fin08MerchantBookScreen(gateway:api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin08_contact_contact-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fin08_claim_type_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('دفعات').last);
    await tester.pumpAndSettle();
    expect(api.lastClaimType,MovementType.payment);
    expect(find.byKey(const Key('fin08_merchant_claim_claim-1')),findsNothing);

    await tester.tap(find.byKey(const Key('fin08_claim_currency_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();
    expect(api.lastClaimCurrency,CurrencyCode.usd);

    await tester.tap(find.byKey(const Key('fin08_claim_sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المبلغ الأعلى').last);
    await tester.pumpAndSettle();
    expect(api.lastClaimSort,'amount_desc');
  });

  testWidgets('approved merchant claim exposes and opens the ledger', (tester) async {
    final api=MerchantGatewayFake(relationshipStatus:'approved');
    String? opened;
    await tester.pumpWidget(MaterialApp(home:Fin08MerchantBookScreen(
      gateway:api,
      onOpenLedger:(id)=>opened=id,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin08_contact_contact-1')));
    await tester.pumpAndSettle();
    final button=find.byKey(const Key('fin13_open_ledger_claim_claim-1'));
    expect(button,findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(opened,'relationship-1');
  });

  testWidgets('unapproved merchant claim does not expose the ledger', (tester) async {
    final api=MerchantGatewayFake();
    await tester.pumpWidget(MaterialApp(home:Fin08MerchantBookScreen(
      gateway:api,
      onOpenLedger:(_)=>fail('must not open without an approved relationship'),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin08_contact_contact-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin13_open_ledger_claim_claim-1')),findsNothing);
  });

  testWidgets('failed claim save retains idempotency key on retry, does not claim approval', (tester) async {
    final api=MerchantGatewayFake();
    await tester.pumpWidget(MaterialApp(home:Fin08MerchantBookScreen(gateway:api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin08_contact_contact-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل دين معلق'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('fin08_claim_amount')),'1250.50');
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
  testWidgets('copy pending statement requires confirmation and fetches ALL pages without approved rows', (tester) async {
    final api=MultiPageStatementGateway();
    await tester.pumpWidget(MaterialApp(home:Fin08MerchantBookScreen(gateway:api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin08_contact_contact-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin11_copy_pending_statement')));
    await tester.pumpAndSettle();
    expect(find.textContaining('راجع رقم المستلم'),findsWidgets);
    await tester.tap(find.byKey(const Key('fin11_confirm_copy_pending')));
    await tester.pumpAndSettle();
    final contents=capturedStatement ?? '';
    expect(contents,contains('معلقة وغير معتمدة'));
    expect(contents,contains('مجموع المبالغ المعلقة (YER): 120.00'));
    expect(contents,contains('مجموع المبالغ المعلقة (USD): 7'));
    expect(contents,isNot(contains('990 YER')));
    expect(api.restoreCalls,3);
  });

  testWidgets('failed subsequent page does not replace clipboard with incomplete statement', (tester) async {
    final api=MultiPageStatementGateway();
    await tester.pumpWidget(MaterialApp(home:Fin08MerchantBookScreen(gateway:api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin08_contact_contact-1')));
    await tester.pumpAndSettle();
    api.failSecondPage=true;
    await tester.tap(find.byKey(const Key('fin11_copy_pending_statement')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin11_confirm_copy_pending')));
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذر قراءة الصفحة الثانية'),findsOneWidget);
    expect(capturedStatement,isNull,reason:'Never copy a partial or unverified statement');
  });

  testWidgets('merchant explicitly registers a pending payment, not a debt', (tester) async {
    final api=MerchantGatewayFake();
    await tester.pumpWidget(MaterialApp(home:Fin08MerchantBookScreen(gateway:api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin08_contact_contact-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin13_add_pending_payment')));
    await tester.pumpAndSettle();
    expect(find.textContaining('دفعة مسجلة من طرف التاجر'),findsOneWidget);
    await tester.enterText(find.byKey(const Key('fin08_claim_amount')),'10000');
    await tester.tap(find.byKey(const Key('fin08_save_claim')));
    await tester.pumpAndSettle();
    expect(api.lastType,MovementType.payment);
    expect(api.lastAmount,Decimal.parse('10000'));
    expect(find.textContaining('فشل مؤقت من الخادم'),findsOneWidget);
    await tester.tap(find.byKey(const Key('fin08_save_claim')));
    await tester.pumpAndSettle();
    expect(api.attempts,2);
    expect(api.lastType,MovementType.payment);
  });

}