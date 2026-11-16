import 'package:decimal/decimal.dart';
import '../models/app_models.dart';
import 'fin08_api_client.dart';

/// Financial limits use the approved ledger for blocking decisions. Pending
/// debt/payment exposure is ALWAYS separate and never an approved balance.
String _required(Map<String,dynamic> map,String key){
  final v=map[key];
  if(v is! String || v.isEmpty)throw FormatException('Invalid '+key);
  return v;
}
CurrencyCode _unit(Object? value)=>switch(value){
  'YER'=>CurrencyCode.yer,'SAR'=>CurrencyCode.sar,'USD'=>CurrencyCode.usd,
  _=>throw const FormatException('Unknown currency')
};
Decimal _money(Object? value){
  if(value is! String)throw const FormatException('Invalid Decimal string');
  return Decimal.parse(value);
}
class Fin16CreditCurrency {
  const Fin16CreditCurrency({
    required this.currency,required this.enabled,required this.version,
    required this.limitAmount,required this.mode,required this.approvedBalance,
    required this.pendingDebts,required this.pendingPayments,
    required this.pendingNetEstimate,required this.approvedExceedsLimit});
  final CurrencyCode currency;
  final bool enabled,approvedExceedsLimit;
  final int version;
  final Decimal? limitAmount;
  final String? mode;
  final Decimal approvedBalance,pendingDebts,pendingPayments,pendingNetEstimate;
  factory Fin16CreditCurrency.fromJson(Map<String,dynamic> j){
    if(j['enabled'] is! bool || j['version'] is! int ||
        j['approved_exceeds_limit'] is! bool){
      throw const FormatException('Invalid credit limit policy');
    }
    final active=j['enabled'] as bool;
    final unit=_unit(j['currency']);
    final mode=active?_required(j,'mode'):null;
    if(active && mode!='warn'&&mode!='block')throw const FormatException('Invalid credit mode');
    if(!active && (j['limit_amount']!=null||j['mode']!=null)){
      throw const FormatException('Disabled credit limit must not be active');
    }
    return Fin16CreditCurrency(currency:unit,enabled:active,
      version:j['version'] as int,mode:mode,
      limitAmount:active?_money(j['limit_amount']):null,
      approvedBalance:_money(j['approved_balance']),
      pendingDebts:_money(j['pending_debts']),
      pendingPayments:_money(j['pending_payments']),
      pendingNetEstimate:_money(j['pending_net_estimate']),
      approvedExceedsLimit:j['approved_exceeds_limit'] as bool);
  }
}
class Fin16CreditSnapshot {
  const Fin16CreditSnapshot(this.relationshipId,this.currencies);
  final String relationshipId;
  final List<Fin16CreditCurrency> currencies;
  Fin16CreditCurrency forCurrency(CurrencyCode unit)=>
    currencies.firstWhere((c)=>c.currency==unit);
  factory Fin16CreditSnapshot.fromJson(Map<String,dynamic> j){
    if(j['scope']!='approved_ledger_and_separate_unapproved_exposure' ||
        j['currencies'] is! List)throw const FormatException('Unverified credit exposure scope');
    final lines=(j['currencies'] as List).map((v)=>
      Fin16CreditCurrency.fromJson(Map<String,dynamic>.from(v as Map)))
      .toList(growable:false);
    if(lines.length!=3 || lines.map((c)=>c.currency).toSet().length!=3){
      throw const FormatException('Missing currency in credit exposure');
    }
    return Fin16CreditSnapshot(_required(j,'relationship_id'),lines);
  }
}
class Fin16PolicyReceipt {
  const Fin16PolicyReceipt(this.enabled,this.currency,this.mode,this.limitAmount,
    this.version,this.replayed);
  final CurrencyCode currency;
  final bool enabled,replayed;
  final String? mode;
  final Decimal? limitAmount;
  final int version;
  factory Fin16PolicyReceipt.fromJson(Map<String,dynamic> j){
    if(j['enabled'] is! bool || j['version'] is! int ||
        j['replayed'] is! bool)throw const FormatException('Invalid credit policy receipt');
    final active=j['enabled'] as bool;
    final mode=active?_required(j,'mode'):null;
    if(active && mode!='warn'&&mode!='block')throw const FormatException('Invalid mode');
    return Fin16PolicyReceipt(active,_unit(j['currency']),mode,
      active?_money(j['limit_amount']):null,
      j['version'] as int,j['replayed'] as bool);
  }
}
abstract class Fin16CreditGateway {
  Future<Fin16CreditSnapshot> read(String relationshipId);
  Future<Fin16PolicyReceipt> set(String relationshipId,CurrencyCode unit,{
    required bool enabled,Decimal? limitAmount,String? mode});
}
/// Requires a verified JWT transport. Not connected to the offline PIN login.
class Fin16HttpCreditGateway implements Fin16CreditGateway {
  const Fin16HttpCreditGateway(this.transport);
  final Fin08HttpClaimsGateway transport;
  String _path(String id)=>'v1/relationships/'+Uri.encodeComponent(id)+'/credit-limits';
  @override
  Future<Fin16CreditSnapshot> read(String id) async =>
    Fin16CreditSnapshot.fromJson(await transport.sendFinancial('GET',_path(id)));
  @override
  Future<Fin16PolicyReceipt> set(String id,CurrencyCode unit,{
      required bool enabled,Decimal? limitAmount,String? mode}) async{
    if(enabled && (limitAmount==null || limitAmount<Decimal.zero ||
        (mode!='warn' && mode!='block'))){
      throw ArgumentError('Enabled credit policy requires nonnegative amount and warn/block');
    }
    final result=await transport.sendFinancial('POST',_path(id),body:{
      'currency':unit.name.toUpperCase(),'enabled':enabled,
      if(enabled)'limit_amount':limitAmount!.toString(),
      if(enabled)'mode':mode,
    });
    final parsed=Fin16PolicyReceipt.fromJson(result);
    if(parsed.currency!=unit || parsed.enabled!=enabled){
      throw const Fin08ApiError('سياسة الحد الائتماني غير مؤكدة من الخادم.',code:'invalid_response');
    }
    return parsed;
  }
}
