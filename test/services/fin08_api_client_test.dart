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

  test('FIN-10 customer sees relationship invitations, approves only chosen link', () async {
    var approvals = 0;
    final api = Fin08HttpClaimsGateway(
      baseUri: Uri.parse('https://qatlink.example/'),
      accessToken: () async => 'customer-verified-jwt',
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer customer-verified-jwt');
        if (request.method == 'GET') {
          expect(request.url.path, '/v1/customer/relationships');
          return http.Response(jsonEncode({
            'items': [{
              'relationship_id':'rel-one',
              'merchant_id':'merchant-one',
              'merchant_display_name':'متجر الأصالة',
              'status':'pending',
              'created_at':'2026-11-16T11:00:00.000Z',
              'decided_at':null,
            }],
            'next_cursor':null,
          }),200,headers:{'content-type':'application/json; charset=utf-8'});
        }
        expect(request.method,'POST');
        expect(request.url.path,'/v1/customer/relationships/rel-one/decision');
        expect((jsonDecode(request.body) as Map<String,dynamic>)['decision'],'accept');
        approvals++;
        return http.Response(jsonEncode({
          'relationship_id':'rel-one','status':'approved','newly_posted_debts':0,
        }),200);
      }),
    );
    final page=await api.customerRelationships();
    expect(page.items.single.merchantName,'متجر الأصالة');
    expect(page.items.single.canReview,true);
    expect(approvals,0);
    final receipt=await api.decideRelationship('rel-one',accept:true);
    expect(receipt.status,Fin08RelationshipStatus.approved);
    expect(receipt.newlyPostedDebts,0);
    expect(approvals,1);
  });

  test('FIN-10 rejects mismatched server relationship decision response', () async {
    final api=Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://qatlink.example/'),
      accessToken:() async=>'customer-verified-jwt',
      client:MockClient((request) async=>http.Response(jsonEncode({
        'relationship_id':'different-link','status':'approved','newly_posted_debts':0,
      }),200)),
    );
    await expectLater(api.decideRelationship('rel-one',accept:true),
      throwsA(isA<Fin08ApiError>()));
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
}