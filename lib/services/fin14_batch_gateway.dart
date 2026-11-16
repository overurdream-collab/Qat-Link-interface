import 'package:decimal/decimal.dart';
import '../models/app_models.dart';
import 'fin08_api_client.dart';

/// Separate selection payload from any auto-approval configuration.
class Fin14ReviewTotal {
  const Fin14ReviewTotal(this.currency,this.debts,this.payments,this.estimate);
  final CurrencyCode currency;
  final Decimal debts,payments,estimate;
  factory Fin14ReviewTotal.fromJson(Map<String,dynamic> j){
    final unit=switch(j['currency']){
      'YER'=>CurrencyCode.yer,'SAR'=>CurrencyCode.sar,'USD'=>CurrencyCode.usd,
      _=>throw const FormatException('Unknown currency')};
    Decimal amount(String key){
      final v=j[key];
      if(v is! String)throw const FormatException('Invalid decimal sum');
      return Decimal.parse(v);
    }
    return Fin14ReviewTotal(unit,amount('selected_debts'),
      amount('selected_payments'),amount('selected_net_estimate'));
  }
}
class Fin14BatchResult {
  const Fin14BatchResult(this.newlyPosted,this.scope,this.items,this.reviewed);
  final int newlyPosted;
  final String scope;
  final List<Map<String,dynamic>> items;
  final List<Fin14ReviewTotal> reviewed;
  factory Fin14BatchResult.fromJson(Map<String,dynamic> j){
    if(j['newly_posted_count'] is! int || j['items'] is! List ||
        j['reviewed_by_currency'] is! List) {
      throw const FormatException('Invalid selective batch response');
    }
    final scope=j['scope'];
    if(scope!='selected_claims_only' &&
        scope!='selected_relationship_operations_only') {
      throw const FormatException('Unverified batch result scope');
    }
    final items=(j['items'] as List)
      .map((x)=>Map<String,dynamic>.from(x as Map)).toList(growable:false);
    final reviews=(j['reviewed_by_currency'] as List)
      .map((x)=>Fin14ReviewTotal.fromJson(Map<String,dynamic>.from(x as Map)))
      .toList(growable:false);
    return Fin14BatchResult(j['newly_posted_count'] as int,
      scope as String,items,reviews);
  }
}
abstract class Fin14BatchGateway {
  Future<Fin14BatchResult> decideHistorical(Map<String,bool> selected);
  Future<Fin14BatchResult> decideRelationship(String relationship,Map<String,bool> selected);
}
/// Transport shares the verified JWT and HTTPS enforcement of FIN-08/13.
class Fin14HttpBatchGateway implements Fin14BatchGateway {
  const Fin14HttpBatchGateway(this.transport);
  final Fin08HttpClaimsGateway transport;
  List<Map<String,String>> _choices(Map<String,bool> values){
    if(values.isEmpty||values.length>50)throw ArgumentError('Select 1–50 items');
    return values.entries.map((x)=>{
      'id':x.key,'decision':x.value?'accept':'reject'
    }).toList(growable:false);
  }
  @override
  Future<Fin14BatchResult> decideHistorical(Map<String,bool> selected) async{
    final result=await transport.sendFinancial('POST',
      'v1/customer/previous-claims/batch-decisions',
      body:{'decisions':_choices(selected)});
    final parsed=Fin14BatchResult.fromJson(result);
    if(parsed.scope!='selected_claims_only'){
      throw const FormatException('Unexpected batch scope');
    }
    return parsed;
  }
  @override
  Future<Fin14BatchResult> decideRelationship(String id,Map<String,bool> selected) async{
    final result=await transport.sendFinancial('POST',
      'v1/relationships/'+Uri.encodeComponent(id)+'/operations/batch-decisions',
      body:{'decisions':_choices(selected)});
    final parsed=Fin14BatchResult.fromJson(result);
    if(parsed.scope!='selected_relationship_operations_only'){
      throw const FormatException('Unexpected batch scope');
    }
    return parsed;
  }
}
