import 'package:decimal/decimal.dart';
import 'fin08_api_client.dart';

/// FIN-15 proposals are non-financial until independent merchant and customer
/// consent creates/posts a fresh claim. No client can mutate an approved amount.
class Fin15AdjustmentReceipt {
  const Fin15AdjustmentReceipt({required this.id,required this.status,
    required this.replayed,this.sourceClaimId,this.replacementClaimId});
  final String id,status;
  final bool replayed;
  final String? sourceClaimId,replacementClaimId;
  factory Fin15AdjustmentReceipt.fromJson(Map<String,dynamic> json){
    final id=json['adjustment_id'];
    final state=json['status'];
    if(id is! String || id.isEmpty ||
        !['pending','accepted','rejected'].contains(state)) {
      throw const FormatException('Invalid amount adjustment receipt');
    }
    return Fin15AdjustmentReceipt(id:id,status:state as String,
      replayed:json['replayed']==true,
      sourceClaimId:json['source_claim_id'] as String? ??
        json['claim_id'] as String?,
      replacementClaimId:json['replacement_claim_id'] as String?);
  }
}
abstract class Fin15ClaimAdjustmentGateway {
  Future<Fin15AdjustmentReceipt> request(String claimId,{
    required Decimal proposedAmount,required String reason});
  Future<Fin15AdjustmentReceipt> decide(String adjustmentId,{
    required bool accept});
}
/// Requires a verified JWT. Never activate for locally typed phone/PIN logins.
class Fin15HttpClaimAdjustmentGateway implements Fin15ClaimAdjustmentGateway {
  const Fin15HttpClaimAdjustmentGateway(this.client);
  final Fin08HttpClaimsGateway client;
  @override
  Future<Fin15AdjustmentReceipt> request(String claimId,{
      required Decimal proposedAmount,required String reason}) async {
    if(proposedAmount<=Decimal.zero) throw ArgumentError.value(
      proposedAmount,'proposedAmount','Amount must be positive');
    return Fin15AdjustmentReceipt.fromJson(await client.sendFinancial(
      'POST','v1/customer/previous-claims/'+Uri.encodeComponent(claimId)+'/amount-adjustment',
      body:{'proposed_amount':proposedAmount.toString(),'reason':reason}));
  }
  @override
  Future<Fin15AdjustmentReceipt> decide(String id,{required bool accept}) async =>
    Fin15AdjustmentReceipt.fromJson(await client.sendFinancial(
      'POST','v1/merchant/claim-adjustments/'+Uri.encodeComponent(id)+'/decision',
      body:{'decision':accept?'accept':'reject'}));
}
