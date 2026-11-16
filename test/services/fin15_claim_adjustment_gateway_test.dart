import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qat_link/services/fin08_api_client.dart';
import 'package:qat_link/services/fin15_claim_adjustment_gateway.dart';

void main(){
  test('customer proposal carries decimal text and actor is enforced by JWT, not body',() async{
    var calls=0;
    final api=Fin15HttpClaimAdjustmentGateway(Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://financial.test/'),
      accessToken:() async=>'verified-customer-jwt',
      client:MockClient((req) async {
        calls++;
        expect(req.url.path,'/v1/customer/previous-claims/claim-uuid/amount-adjustment');
        expect(req.headers['authorization'],'Bearer verified-customer-jwt');
        final payload=jsonDecode(req.body) as Map<String,dynamic>;
        expect(payload['proposed_amount'],'1000.2501');
        expect(payload['reason'],'Original invoice differs');
        expect(payload.containsKey('customer_id'),false);
        return http.Response(jsonEncode({
          'adjustment_id':'adjust-1','claim_id':'claim-uuid','status':'pending',
          'replayed':false
        }),201);
      })));
    final result=await api.request('claim-uuid',
      proposedAmount:Decimal.parse('1000.2501'),reason:'Original invoice differs');
    expect(result.status,'pending');
    expect(result.sourceClaimId,'claim-uuid');
    expect(result.replayed,false);
    expect(calls,1);
    await expectLater(api.request('claim-uuid',
      proposedAmount:Decimal.zero,reason:'Invalid'),throwsArgumentError);
    expect(calls,1);
  });
  test('merchant acceptance returns a new claim that still requires customer review',() async{
    final api=Fin15HttpClaimAdjustmentGateway(Fin08HttpClaimsGateway(
      baseUri:Uri.parse('https://financial.test/'),
      accessToken:() async=>'merchant-jwt',
      client:MockClient((req) async {
        expect(req.url.path,'/v1/merchant/claim-adjustments/change-id/decision');
        expect((jsonDecode(req.body) as Map)['decision'],'accept');
        return http.Response(jsonEncode({
          'adjustment_id':'change-id','status':'accepted','source_claim_id':'original',
          'replacement_claim_id':'new-pending','replayed':false
        }),200);
      })));
    final result=await api.decide('change-id',accept:true);
    expect(result.status,'accepted');
    expect(result.sourceClaimId,'original');
    expect(result.replacementClaimId,'new-pending');
  });
  test('unexpected reply is rejected and cannot imply a successful financial amendment',(){
    expect(()=>Fin15AdjustmentReceipt.fromJson({
      'adjustment_id':'x','status':'approved','replacement_claim_id':'new'
    }),throwsFormatException);
  });
}
