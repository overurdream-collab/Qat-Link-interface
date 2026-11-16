import 'package:decimal/decimal.dart';

import 'fin08_api_client.dart';
import '../models/app_models.dart';

/// A proposal is NOT a financial ledger entry. All consents stay on the server.
class Fin15Amendment {
  const Fin15Amendment({required this.id,required this.status,
    required this.oldAmount,required this.proposedAmount,
    required this.currency,required this.reason,required this.createdAt,
    this.originalClaimId,this.originalOperationId,this.replacementClaimId,
    this.replacementOperationId,this.ledgerPosted=false,this.replayed=false});
  final String id,status,reason;
  final Decimal oldAmount,proposedAmount;
  final CurrencyCode currency;
  final DateTime createdAt;
  final String? originalClaimId,originalOperationId,
      replacementClaimId,replacementOperationId;
  final bool ledgerPosted,replayed;

  bool get pending=>status=='pending';
  bool get isHistorical=>originalClaimId!=null;

  factory Fin15Amendment.fromJson(Map<String,dynamic> j){
    String required(String key){
      final v=j[key];
      if(v is! String||v.isEmpty)throw FormatException('Invalid '+key);
      return v;
    }
    final status=required('status');
    if(!['pending','accepted','rejected'].contains(status)){
      throw const FormatException('Unsupported amendment status');
    }
    final unit=switch(required('currency')){
      'YER'=>CurrencyCode.yer,
      'SAR'=>CurrencyCode.sar,
      'USD'=>CurrencyCode.usd,
      _=>throw const FormatException('Unsupported currency')
    };
    final claim=j['original_claim_id'] as String?;
    final operation=j['original_operation_id'] as String?;
    if((claim==null)==(operation==null))throw const FormatException('Invalid amendment source');
    return Fin15Amendment(
      id:required('amendment_id'),status:status,
      oldAmount:Decimal.parse(required('original_amount')),
      proposedAmount:Decimal.parse(required('proposed_amount')),
      currency:unit,reason:required('reason'),
      createdAt:DateTime.parse(required('recorded_at')),
      originalClaimId:claim,originalOperationId:operation,
      replacementClaimId:j['replacement_claim_id'] as String?,
      replacementOperationId:j['replacement_operation_id'] as String?,
      ledgerPosted:j['ledger_posted']==true,replayed:j['replayed']==true);
  }
}
class Fin15Page {
  const Fin15Page(this.items,this.nextCursor);
  final List<Fin15Amendment> items;
  final String? nextCursor;
  factory Fin15Page.fromJson(Map<String,dynamic> j){
    if(j['items'] is! List ||
        (j['next_cursor']!=null&&j['next_cursor'] is! String)){
      throw const FormatException('Invalid amendment list');
    }
    return Fin15Page((j['items'] as List)
      .map((x)=>Fin15Amendment.fromJson(Map<String,dynamic>.from(x as Map)))
      .toList(growable:false),j['next_cursor'] as String?);
  }
}
abstract class Fin15AmendmentGateway {
  Future<Fin15Amendment> proposeHistorical(String claimId,{
    required Decimal amount,required String reason,required String idempotencyKey});
  Future<Fin15Amendment> proposeOperation(String relationshipId,String operationId,{
    required Decimal amount,required String reason,required String idempotencyKey});
  Future<Fin15Amendment> merchantDecision(String amendmentId,{required bool accept});
  Future<Fin15Page> list({required bool forMerchant,String? cursor,int limit=50});
}
/// Only construct with Fin08HttpClaimsGateway using real, verified JWT login.
class Fin15HttpAmendmentGateway implements Fin15AmendmentGateway {
  const Fin15HttpAmendmentGateway(this.transport);
  final Fin08HttpClaimsGateway transport;

  Map<String,String> _body(Decimal amount,String reason){
    if(amount<=Decimal.zero)throw ArgumentError.value(amount,'amount','Must be positive');
    final text=reason.trim();
    if(text.length<3||text.length>500)throw ArgumentError.value(reason,'reason');
    return {'proposed_amount':amount.toString(),'reason':text};
  }
  @override
  Future<Fin15Amendment> proposeHistorical(String claimId,{
      required Decimal amount,required String reason,required String idempotencyKey}) async =>
    Fin15Amendment.fromJson(await transport.sendFinancial('POST',
      'v1/customer/previous-claims/'+Uri.encodeComponent(claimId)+'/amendments',
      idempotencyKey:idempotencyKey,body:_body(amount,reason)));
  @override
  Future<Fin15Amendment> proposeOperation(String relationshipId,String operationId,{
      required Decimal amount,required String reason,required String idempotencyKey}) async =>
    Fin15Amendment.fromJson(await transport.sendFinancial('POST',
      'v1/relationships/'+Uri.encodeComponent(relationshipId)+'/operations/'+
        Uri.encodeComponent(operationId)+'/amendments',
      idempotencyKey:idempotencyKey,body:_body(amount,reason)));
  @override
  Future<Fin15Amendment> merchantDecision(String id,{required bool accept}) async =>
    Fin15Amendment.fromJson(await transport.sendFinancial('POST',
      'v1/merchant/amendments/'+Uri.encodeComponent(id)+'/decision',
      body:{'decision':accept?'accept':'reject'}));
  @override
  Future<Fin15Page> list({required bool forMerchant,String? cursor,int limit=50}) async {
    if(limit<1||limit>100)throw ArgumentError.value(limit,'limit');
    return Fin15Page.fromJson(await transport.sendFinancial('GET',
      forMerchant?'v1/merchant/amendments':'v1/customer/amendments',
      query:{'limit':limit.toString(),if(cursor!=null)'cursor':cursor}));
  }
}
