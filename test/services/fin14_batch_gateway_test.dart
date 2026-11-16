import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qat_link/services/fin08_api_client.dart';
import 'package:qat_link/services/fin14_batch_gateway.dart';

void main(){
  test('customer selects exact historical claims and sees separate currency review totals',() async {
    final client=MockClient((req) async {
      expect(req.method,'POST');
      expect(req.url.path,'/v1/customer/previous-claims/batch-decisions');
      expect(req.headers['authorization'],'Bearer trusted-identity-jwt');
      final payload=jsonDecode(req.body) as Map<String,dynamic>;
      final decisions=payload['decisions'] as List;
      expect(decisions.length,2);
      expect(decisions.map((x)=>(x as Map)['id']).toSet(),{'one','two'});
      expect(decisions.map((x)=>(x as Map)['decision']).toSet(),{'accept','reject'});
      return http.Response(jsonEncode({
        'scope':'selected_claims_only','newly_posted_count':0,
        'items':[{'id':'one','decision':'accept','ledger_posted':false},
          {'id':'two','decision':'reject','ledger_posted':false}],
        'reviewed_by_currency':[
          {'currency':'YER','selected_debts':'20000.0000',
            'selected_payments':'10000.0000','selected_net_estimate':'10000.0000'},
          {'currency':'USD','selected_debts':'0.0000',
            'selected_payments':'0.0000','selected_net_estimate':'0.0000'}
        ]
      }),200);
    });
    final gateway=Fin14HttpBatchGateway(Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://ledger.test/'),
      client:client,accessToken:()async=>'trusted-identity-jwt'));
    final r=await gateway.decideHistorical({'one':true,'two':false});
    expect(r.scope,'selected_claims_only');
    expect(r.newlyPosted,0);
    expect(r.reviewed.first.debts,Decimal.parse('20000'));
    expect(r.reviewed.first.payments,Decimal.parse('10000'));
    expect(r.reviewed.first.estimate,Decimal.parse('10000'));
    client.close();
  });

  test('a relationship batch uses independently authorized ledger route',()async{
    final client=MockClient((req) async {
      expect(req.url.path,'/v1/relationships/rel-1/operations/batch-decisions');
      expect((jsonDecode(req.body) as Map)['decisions'],[
        {'id':'op-1','decision':'accept'}
      ]);
      return http.Response(jsonEncode({
        'scope':'selected_relationship_operations_only','newly_posted_count':1,
        'items':[{'id':'op-1','decision':'accept','ledger_posted':true}],
        'reviewed_by_currency':[{'currency':'SAR','selected_debts':'0.0000',
          'selected_payments':'5.2501','selected_net_estimate':'-5.2501'}]
      }),200);
    });
    final gateway=Fin14HttpBatchGateway(Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://ledger.test/'),client:client,
      accessToken:()async=>'jwt'));
    final r=await gateway.decideRelationship('rel-1',{'op-1':true});
    expect(r.newlyPosted,1);
    expect(r.reviewed.single.estimate,Decimal.parse('-5.2501'));
    client.close();
  });

  test('a batch cannot have zero or over 50 items',()async{
    final client=MockClient((_)async=>http.Response('{}',200));
    final gateway=Fin14HttpBatchGateway(Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://ledger.test/'),client:client,
      accessToken:()async=>'jwt'));
    await expectLater(gateway.decideHistorical({}),throwsArgumentError);
    await expectLater(gateway.decideHistorical({
      for(var i=0;i<51;i++)'claim-$i':true,
    }),throwsArgumentError);
    client.close();
  });

  test('client rejects a server response not scoped to selected items',()async{
    final client=MockClient((_)async=>http.Response(jsonEncode({
      'scope':'approved_ledger_only','newly_posted_count':0,
      'items':[],'reviewed_by_currency':[]
    }),200));
    final gateway=Fin14HttpBatchGateway(Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://ledger.test/'),client:client,
      accessToken:()async=>'jwt'));
    await expectLater(gateway.decideHistorical({'a':true}),throwsFormatException);
    client.close();
  });
}
