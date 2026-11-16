import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/services/fin08_api_client.dart';
import 'package:qat_link/services/fin16_credit_gateway.dart';

void main(){
  final relation='11111111-1111-4111-8111-111111111111';
  Map<String,dynamic> row(String currency,{
      bool enabled=false,String? amount,String? mode,String balance='0.0000',
      String pendingDebts='0.0000',String pendingPayments='0.0000',
      String pendingNet='0.0000',bool exceeded=false})=> {
    'currency':currency,'enabled':enabled,'version':enabled?2:0,
    'limit_amount':amount,'mode':mode,'updated_at':null,
    'approved_balance':balance,'pending_debts':pendingDebts,
    'pending_payments':pendingPayments,'pending_net_estimate':pendingNet,
    'approved_exceeds_limit':exceeded,
  };
  test('credit GET is scoped and keeps exact signed approved and pending currencies separate',() async{
    final client=MockClient((req)async{
      expect(req.headers['authorization'],'Bearer verified-token');
      expect(req.url.path,'/v1/relationships/$relation/credit-limits');
      return http.Response(jsonEncode({
        'relationship_id':relation,
        'scope':'approved_ledger_and_separate_unapproved_exposure',
        'currencies':[
          row('YER',enabled:true,mode:'block',amount:'500.0000',
            balance:'-100.0000',pendingDebts:'20000.0000',
            pendingPayments:'10000.0000',pendingNet:'10000.0000'),
          row('SAR',enabled:true,mode:'warn',amount:'5.0000',
            balance:'7.2501',exceeded:true),
          row('USD'),
        ],
      }),200);
    });
    final api=Fin16HttpCreditGateway(Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://qatlink.test/'),client:client,
      accessToken:()async=>'verified-token'));
    final snapshot=await api.read(relation);
    expect(snapshot.forCurrency(CurrencyCode.yer).approvedBalance,Decimal.parse('-100'));
    expect(snapshot.forCurrency(CurrencyCode.yer).pendingDebts,Decimal.parse('20000'));
    expect(snapshot.forCurrency(CurrencyCode.yer).pendingPayments,Decimal.parse('10000'));
    expect(snapshot.forCurrency(CurrencyCode.yer).pendingNetEstimate,Decimal.parse('10000'));
    expect(snapshot.forCurrency(CurrencyCode.sar).approvedExceedsLimit,true);
    expect(snapshot.forCurrency(CurrencyCode.usd).enabled,false);
    client.close();
  });
  test('merchant limit update/disable sends Decimal as string and returns verified currency',() async{
    var calls=0;
    final client=MockClient((req)async{
      calls++;
      expect(req.headers['authorization'],'Bearer verified-token');
      expect(req.method,'POST');
      final j=jsonDecode(req.body) as Map<String,dynamic>;
      expect(j['currency'],'USD');
      if(j['enabled']==true){
        expect(j['limit_amount'],'200.0001');
        expect(j['mode'],'warn');
        return http.Response(jsonEncode({
          'relationship_id':relation,'currency':'USD','enabled':true,
          'mode':'warn','limit_amount':'200.0001','version':1,'replayed':false,
        }),200);
      }
      expect(j.containsKey('limit_amount'),false);
      return http.Response(jsonEncode({
        'relationship_id':relation,'currency':'USD','enabled':false,
        'mode':null,'limit_amount':null,'version':2,'replayed':false,
      }),200);
    });
    final api=Fin16HttpCreditGateway(Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://qatlink.test/'),client:client,
      accessToken:()async=>'verified-token'));
    final enabled=await api.set(relation,CurrencyCode.usd,enabled:true,
      limitAmount:Decimal.parse('200.0001'),mode:'warn');
    expect(enabled.limitAmount,Decimal.parse('200.0001'));
    final disabled=await api.set(relation,CurrencyCode.usd,enabled:false);
    expect(disabled.enabled,false);
    expect(disabled.version,2);
    expect(calls,2);
    client.close();
  });
  test('missing currencies, false ledger scope and invalid approved money fail closed',(){
    expect(()=>Fin16CreditSnapshot.fromJson({
      'scope':'pre_registration_claims_only_not_full_ledger','relationship_id':relation,
      'currencies':[],
    }),throwsFormatException);
    expect(()=>Fin16CreditSnapshot.fromJson({
      'scope':'approved_ledger_and_separate_unapproved_exposure',
      'relationship_id':relation,'currencies':[row('YER')],
    }),throwsFormatException);
    expect(()=>Fin16CreditCurrency.fromJson(row('USD',balance: 'NaN')),
      throwsFormatException);
  });
}
