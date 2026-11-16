import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/services/fin08_api_client.dart';

void main() {
  test('rejects unencrypted non-loopback transport', () {
    expect(() => Fin08HttpClaimsGateway(
      baseUri: Uri.parse('http://qatlink.example/'),
      client: MockClient((_) async => http.Response('{}',200)),
      accessToken:() async => 'token',
    ),throwsArgumentError);
  });

  test('does not call server when there is no authenticated session', () async {
    var calls=0;
    final api=Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://qatlink.example/'),
      client:MockClient((_) async {calls++;return http.Response('{}',200);}),
      accessToken:() async => '',
    );
    await expectLater(api.customerPreviousClaims(),throwsA(isA<Fin08ApiError>()));
    expect(calls,0);
  });

  test('loads every page of verified historical claims and preserves per-claim stage', () async {
    final paths=<String>[];
    final api=Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://qatlink.example/'),
      accessToken:() async=>'jwt-verified-by-real-issuer',
      client:MockClient((req) async {
        expect(req.headers['authorization'],'Bearer jwt-verified-by-real-issuer');
        paths.add(req.url.toString());
        final cursor=req.url.queryParameters['cursor'];
        return http.Response(jsonEncode({
          'next_cursor':cursor==null?'signed-cursor':null,
          'items':[{ 'claim_id':cursor==null?'claim-1':'claim-2',
            'merchant_id':'merchant-1','merchant_display_name':'متجر صالح',
            'amount':cursor==null?'1250.5000':'10.0000','currency':cursor==null?'YER':'USD',
            'description':null,'created_at':'2026-11-15T11:00:00.000Z',
            'stage':cursor==null?'awaiting_review':'accepted_awaiting_relationship' }],
        }),200,headers:{'content-type':'application/json'});
      }),
    );
    final first=await api.customerPreviousClaims(limit:1);
    expect(first.items.single.amount,Decimal.parse('1250.5000'));
    expect(first.items.single.canReview,true);
    expect(first.items.single.currency,CurrencyCode.yer);
    expect(first.hasMore,true);
    final second=await api.customerPreviousClaims(limit:1,cursor:first.nextCursor);
    expect(second.items.single.currency,CurrencyCode.usd);
    expect(second.items.single.canReview,false);
    expect(second.hasMore,false);
    expect(paths,hasLength(2));
    expect(Uri.parse(paths[1]).queryParameters['cursor'],'signed-cursor');
  });

  test('posts decimal amount as string, preserves caller idempotency key and stays pending', () async {
    late http.Request seen;
    final api=Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://qatlink.example/'),
      accessToken:() async=>'verified-jwt',
      client:MockClient((req) async {
        seen=req;
        return http.Response(jsonEncode({'id':'claim-uuid','replayed':false}),201);
      }),
    );
    final receipt=await api.createMerchantClaim(
      contactId:'contact-uuid',amount:Decimal.parse('10.25'),
      currency:CurrencyCode.sar,idempotencyKey:'merchant-unique-action-0001',
    );
    final sent=jsonDecode(seen.body) as Map<String,dynamic>;
    expect(seen.headers['Idempotency-Key'],'merchant-unique-action-0001');
    expect(sent['amount'],'10.25');
    expect(sent['currency'],'SAR');
    expect(receipt.claimId,'claim-uuid');
    expect(receipt.replayed,false);
  });

  test('HTTP conflict is error; never claims a successful approval', () async {
    final api=Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://qatlink.example/'),
      accessToken:() async=>'verified-jwt',
      client:MockClient((req) async=>http.Response(
        jsonEncode({'error':'conflict','message':'Already decided'}),409)),
    );
    await expectLater(api.decidePreviousClaim('claim-uuid',accept:true),
      throwsA(isA<Fin08ApiError>().having((e)=>e.statusCode,'status',409)));
  });

  test('merchant summary remains separate per currency and cannot pretend to be full ledger', () async {
    final api=Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://qatlink.example/'),
      accessToken:() async=>'verified-jwt',
      client:MockClient((_) async => http.Response(jsonEncode({
        'approved_scope':'pre_registration_claims_only_not_full_ledger',
        'currencies':[
          {'currency':'YER','outside_app':'200.0000','awaiting_customer_or_relationship':'100.0000','approved_from_claims':'0.0000'},
          {'currency':'USD','outside_app':'0.0000','awaiting_customer_or_relationship':'10.2500','approved_from_claims':'20.0000'},
        ],
      }),200)),
    );
    final byCurrency=await api.merchantClaimSummary();
    expect(byCurrency.length,2);
    expect(byCurrency.first.currency,CurrencyCode.yer);
    expect(byCurrency.last.currency,CurrencyCode.usd);
    expect(byCurrency.last.approvedFromClaims,Decimal.parse('20'));
  });
  test('relation request and customer decision use independent authenticated endpoints',() async {
    var actions=0;
    final api=Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://qatlink.example/'),
      accessToken:() async=>'verified-token',
      client:MockClient((req) async {
        expect(req.headers['authorization'],'Bearer verified-token');
        if(req.url.path=='/v1/customer/relationships' && req.method=='GET'){
          actions++;
          return http.Response(jsonEncode({'items':[{
            'relationship_id':'relationship-1','merchant_id':'merchant-1',
            'merchant_display_name':'متجر القمة','status':'pending',
            'created_at':'2026-11-16T00:00:00Z',
          }],'next_cursor':null}),200,headers:{'content-type':'application/json; charset=utf-8'});
        }
        if(req.url.path=='/v1/customer/relationships/relationship-1/decision'){
          actions++;
          expect(jsonDecode(req.body)['decision'],'accept');
          return http.Response(jsonEncode({'relationship_id':'relationship-1',
            'status':'approved','newly_posted_debts':1}),200);
        }
        if(req.url.path=='/v1/merchant/relationship-requests'){
          actions++;
          expect(jsonDecode(req.body)['contact_id'],'contact-1');
          return http.Response(jsonEncode({'relationship_id':'relationship-2','status':'pending'}),201);
        }
        return http.Response('{}',404);
      }),
    );
    final list=await api.customerRelationships();
    expect(list.items.single.canDecide,true);
    expect(list.items.single.merchantName,'متجر القمة');
    final decision=await api.decideRelationship('relationship-1',accept:true);
    expect(decision.status,'approved');
    expect(decision.newlyPostedDebts,1);
    final requested=await api.requestMerchantRelationship('contact-1');
    expect(requested,'relationship-2');
    expect(actions,3);
  });

  test('atomic batch gateway sends only explicitly chosen claim IDs and checks receipt',() async{
    late http.Request captured;
    final api=Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://qatlink.example/'),
      accessToken:() async=>'trusted-customer-jwt',
      client:MockClient((request) async {
        captured=request;
        return http.Response(jsonEncode({
          'decision':'accept','selected_count':2,'newly_recorded_count':2,
          'newly_posted_count':0,'totals_by_currency_and_type':[
            {'currency':'YER','type':'debt','total_amount':'20000.0000','selected_count':1},
            {'currency':'USD','type':'payment','total_amount':'5.2501','selected_count':1}
          ],'outcomes':[]
        }),200);
      })
    );
    final receipt=await api.decidePreviousClaimsBatch(['id1','id2'],accept:true);
    expect(captured.url.path,'/v1/customer/previous-claims/batch-decision');
    expect(captured.headers['authorization'],'Bearer trusted-customer-jwt');
    final payload=jsonDecode(captured.body) as Map<String,dynamic>;
    expect(payload['claim_ids'],['id1','id2']);
    expect(payload['decision'],'accept');
    expect(receipt.selectedCount,2);
    expect(receipt.postedCount,0);
    expect(receipt.totals.last.amount,Decimal.parse('5.2501'));
    expect(receipt.totals.last.type,MovementType.payment);
    await expectLater(api.decidePreviousClaimsBatch(['x','x'],accept:true),
      throwsArgumentError);
  });
  test('batch result count mismatch is rejected; never claims customer approved unverified list',() async{
    final api=Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://qatlink.example/'),
      accessToken:() async=>'trusted-customer-jwt',
      client:MockClient((_) async=>http.Response(jsonEncode({
        'decision':'accept','selected_count':1,'newly_recorded_count':1,
        'newly_posted_count':0,'totals_by_currency_and_type':[]
      }),200))
    );
    await expectLater(api.decidePreviousClaimsBatch(['a','b'],accept:true),
      throwsA(isA<Fin08ApiError>()));
  });

}