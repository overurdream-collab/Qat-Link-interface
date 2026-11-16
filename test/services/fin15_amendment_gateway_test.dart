import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qat_link/services/fin08_api_client.dart';
import 'package:qat_link/services/fin15_amendment_gateway.dart';

void main(){
  final claim='11111111-1111-4111-8111-111111111111';
  final relationship='22222222-2222-4222-8222-222222222222';
  final operation='33333333-3333-4333-8333-333333333333';
  final amendment='44444444-4444-4444-8444-444444444444';

  Map<String,dynamic> payload({String status='pending',bool modern=false})=> {
    'amendment_id':amendment,
    'original_claim_id':modern?null:claim,
    'original_operation_id':modern?operation:null,
    'original_amount':'20000.0000',
    'proposed_amount':'18000.5000',
    'currency':'YER',
    'reason':'Correct quantity',
    'customer_name':'Sample',
    'status':status,
    'recorded_at':'2026-11-17T12:00:00.000Z',
    'replacement_claim_id':null,
    'replacement_operation_id':null,
    'ledger_posted':false,
    'replayed':false
  };

  test('historical proposal sends exact decimal, reason and stable key through verified JWT',() async {
    var requests=0;
    final client=MockClient((request) async {
      requests++;
      expect(request.url.path,'/v1/customer/previous-claims/'+claim+'/amendments');
      expect(request.headers['authorization'],'Bearer real-verified-token');
      expect(request.headers['Idempotency-Key'],'fin15-proposal-001');
      final body=jsonDecode(request.body) as Map<String,dynamic>;
      expect(body['proposed_amount'],'18000.5');
      expect(body['reason'],'Correct quantity');
      return http.Response(jsonEncode(payload()),201);
    });
    final transport=Fin08HttpClaimsGateway(baseUri:Uri.parse('https://qatlink.test/'),
      client:client,accessToken:() async=>'real-verified-token');
    final gateway=Fin15HttpAmendmentGateway(transport);
    final result=await gateway.proposeHistorical(claim,amount:Decimal.parse('18000.5'),
      reason:'Correct quantity',idempotencyKey:'fin15-proposal-001');
    expect(result.pending,true);
    expect(result.proposedAmount,Decimal.parse('18000.5000'));
    expect(result.oldAmount,Decimal.parse('20000'));
    expect(result.ledgerPosted,false);
    expect(requests,1);
    client.close();
  });

  test('modern proposal, merchant response and private inbox use proper scoped routes',() async{
    final visited=<String>[];
    final client=MockClient((request) async{
      expect(request.headers['authorization'],'Bearer verified');
      visited.add(request.url.path);
      if(request.url.path.endsWith('/amendments')&&request.method=='POST'){
        return http.Response(jsonEncode(payload(modern:true)),201);
      }
      if(request.url.path.endsWith('/decision')){
        expect(jsonDecode(request.body)['decision'],'accept');
        return http.Response(jsonEncode(payload(status:'accepted',modern:true)),200);
      }
      return http.Response(jsonEncode({'items':[payload(modern:true)],'next_cursor':null}),200);
    });
    final transport=Fin08HttpClaimsGateway(baseUri:Uri.parse('https://qatlink.test/'),
      client:client,accessToken:() async=>'verified');
    final gateway=Fin15HttpAmendmentGateway(transport);
    final created=await gateway.proposeOperation(relationship,operation,
      amount:Decimal.parse('18000.5000'),reason:'Correct quantity',
      idempotencyKey:'fin15-modern-001');
    expect(created.originalOperationId,operation);
    final merchantResult=await gateway.merchantDecision(amendment,accept:true);
    expect(merchantResult.status,'accepted');
    final merchantInbox=await gateway.list(forMerchant:true);
    expect(merchantInbox.items.single.customerName,'Sample');
    await gateway.list(forMerchant:false);
    expect(visited,[
      '/v1/relationships/'+relationship+'/operations/'+operation+'/amendments',
      '/v1/merchant/amendments/'+amendment+'/decision',
      '/v1/merchant/amendments','/v1/customer/amendments'
    ]);
    client.close();
  });

  test('malformed source or invalid amount fail closed',() async{
    expect(()=>Fin15Amendment.fromJson(payload()..['original_operation_id']='duplicate'),
      throwsFormatException);
    final transport=Fin08HttpClaimsGateway(baseUri:Uri.parse('https://qatlink.test/'),
      client:MockClient((req) async=>http.Response('{}',200)),
      accessToken:() async=>'verified');
    final gateway=Fin15HttpAmendmentGateway(transport);
    await expectLater(gateway.proposeHistorical(claim,
      amount:Decimal.zero,reason:'Some reason',idempotencyKey:'safe-key-123'),
      throwsArgumentError);
  });
}
