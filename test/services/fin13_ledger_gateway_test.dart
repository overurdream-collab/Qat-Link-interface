import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/services/fin08_api_client.dart';
import 'package:qat_link/services/fin13_ledger_gateway.dart';

void main(){
  Fin13HttpLedgerGateway make(http.Client client)=>Fin13HttpLedgerGateway(
    Fin08HttpClaimsGateway(baseUri:Uri.parse('https://financial.test/'),
      client:client,accessToken:() async=>'verified-token'));
  final relationship='11111111-1111-4111-8111-111111111111';

  test('verified approved ledger balances and dated signed statement parse exact Decimal',() async{
    final client=MockClient((request) async {
      expect(request.headers['authorization'],'Bearer verified-token');
      if(request.url.path.endsWith('/balances')){
        return http.Response(jsonEncode({
          'scope':'approved_ledger_only','relationship_id':relationship,
          'currencies':[
            {'currency':'YER','approved_debts':'20000.0000',
             'approved_payments':'30000.0000','balance':'-10000.0000'},
            {'currency':'SAR','approved_debts':'0.0000',
             'approved_payments':'0.0000','balance':'0.0000'},
            {'currency':'USD','approved_debts':'0.0001',
             'approved_payments':'0.0000','balance':'0.0001'}
          ]
        }),200);
      }
      expect(request.url.queryParameters['currency'],'YER');
      expect(request.url.queryParameters['from'],'2026-11-01');
      return http.Response(jsonEncode({
        'scope':'approved_ledger_only','time_zone':'Asia/Aden',
        'relationship_id':relationship,'currency':'YER',
        'from':'2026-11-01','to':'2026-11-30',
        'opening_balance':'0.0000','approved_debts':'20000.0000',
        'approved_payments':'30000.0000','closing_balance':'-10000.0000',
        'items':[{'movement_id':'mid','amount':'30000.0000',
          'currency':'YER','type':'payment',
          'posted_at':'2026-11-17T12:00:00.000Z','reversal_of_movement_id':null}]
      }),200);
    });
    final gateway=make(client);
    final balances=await gateway.balances(relationship);
    expect(balances.forCurrency(CurrencyCode.yer).net,Decimal.parse('-10000'));
    expect(balances.forCurrency(CurrencyCode.usd).net,Decimal.parse('0.0001'));
    final statement=await gateway.statement(relationship,CurrencyCode.yer,'2026-11-01','2026-11-30');
    expect(statement.closingBalance,Decimal.parse('-10000'));
    expect(statement.entries.single.type,MovementType.payment);
    client.close();
  });

  test('payment request, decision, policy, reversal and cursor remain server-backed',() async{
    final seen=<String>[];
    final client=MockClient((request) async {
      expect(request.headers['authorization'],'Bearer verified-token');
      seen.add(request.url.path);
      if(request.url.path.endsWith('/operations')&&request.method=='POST'){
        expect(request.headers['Idempotency-Key'],'payment-action-001');
        final payload=jsonDecode(request.body) as Map<String,dynamic>;
        expect(payload['type'],'payment');
        expect(payload['currency'],'SAR');
        expect(payload['amount'],'5.2501');
        return http.Response(jsonEncode({
          'operation_id':'op1','status':'pending','ledger_posted':false,'replayed':false
        }),201);
      }
      if(request.url.path.endsWith('/decision')){
        expect((jsonDecode(request.body) as Map)['decision'],'accept');
        return http.Response(jsonEncode({
          'operation_id':'op1','status':'approved','ledger_posted':true,'replayed':false
        }),200);
      }
      if(request.url.path.endsWith('/reversals')){
        expect(request.headers['Idempotency-Key'],'reversal-action-001');
        return http.Response(jsonEncode({'operation_id':'r1','status':'pending','replayed':false}),201);
      }
      if(request.url.path.endsWith('/auto-approval')){
        return http.Response(jsonEncode({
          'enabled':request.method=='GET'?false:true,'version':1,
          'effective_at':'2026-11-17T10:00:00Z'
        }),200);
      }
      if(request.method=='GET'&&request.url.path.endsWith('/operations')){
        expect(request.url.queryParameters['cursor'],'signed-cursor');
        return http.Response(jsonEncode({
          'items':[{
            'id':'op1','operation_type':'payment','amount':'5.2501','currency':'SAR',
            'status':'pending','created_by':'merchant-a','created_by_role':'merchant',
            'approval_method':'manual','created_at':'2026-11-17T12:00:00Z',
            'description':'cash received','reversal_of_movement_id':null
          }],'next_cursor':null
        }),200);
      }
      return http.Response('{}',404);
    });
    final gateway=make(client);
    final payment=await gateway.create(relationship,
      type:MovementType.payment,amount:Decimal.parse('5.2501'),
      currency:CurrencyCode.sar,idempotencyKey:'payment-action-001');
    expect(payment.status,'pending');
    expect(payment.posted,false);
    expect((await gateway.decide(relationship,'op1',accept:true)).posted,true);
    expect((await gateway.reverse(relationship,'posted-movement-id',
      reason:'reviewed',idempotencyKey:'reversal-action-001')).status,'pending');
    expect((await gateway.policy(relationship)).enabled,false);
    expect((await gateway.setPolicy(relationship,enabled:true)).enabled,true);
    final page=await gateway.operations(relationship,cursor:'signed-cursor');
    expect(page.items.single.amount,Decimal.parse('5.2501'));
    expect(page.items.single.type,MovementType.payment);
    expect(seen.length,6);
    client.close();
  });

  test('rejects non-authoritative scope rather than showing false approved balances',(){
    expect(()=>Fin13Balances.fromJson({
      'scope':'pre_registration_claims_only_not_full_ledger','relationship_id':'x',
      'currencies':[]
    }),throwsFormatException);
  });
}
