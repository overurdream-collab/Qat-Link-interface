import 'package:decimal/decimal.dart';
import '../models/app_models.dart';
import 'fin08_api_client.dart';

/// FIN-13 DTOs; all state, posting and authorization decisions remain server-side.
String _value(Map<String,dynamic> j,String k){
  final v=j[k];
  if(v is! String || v.isEmpty)throw FormatException('Invalid '+k);
  return v;
}
Decimal _amount(Map<String,dynamic> j,String k)=>Decimal.parse(_value(j,k));
CurrencyCode _currency(Map<String,dynamic> j)=>switch(_value(j,'currency')){
  'YER'=>CurrencyCode.yer,'SAR'=>CurrencyCode.sar,'USD'=>CurrencyCode.usd,
  _=>throw const FormatException('Invalid currency')};
MovementType _type(String value)=>switch(value){
  'debt'=>MovementType.debt,'payment'=>MovementType.payment,
  _=>throw const FormatException('Invalid financial type')};

class Fin13CurrencyBalance {
  const Fin13CurrencyBalance(this.currency,this.approvedDebts,this.approvedPayments,this.net);
  final CurrencyCode currency;
  final Decimal approvedDebts,approvedPayments,net;
  factory Fin13CurrencyBalance.fromJson(Map<String,dynamic> j)=>
    Fin13CurrencyBalance(_currency(j),_amount(j,'approved_debts'),
      _amount(j,'approved_payments'),_amount(j,'balance'));
}
class Fin13Balances {
  const Fin13Balances(this.relationshipId,this.currencies);
  final String relationshipId;
  final List<Fin13CurrencyBalance> currencies;
  Fin13CurrencyBalance forCurrency(CurrencyCode unit)=>
    currencies.firstWhere((row)=>row.currency==unit);
  factory Fin13Balances.fromJson(Map<String,dynamic> j){
    if(j['scope']!='approved_ledger_only' || j['currencies'] is! List){
      throw const FormatException('Unverified approved ledger scope');
    }
    return Fin13Balances(_value(j,'relationship_id'),(j['currencies'] as List)
      .map((x)=>Fin13CurrencyBalance.fromJson(Map<String,dynamic>.from(x as Map)))
      .toList(growable:false));
  }
}
class Fin13Entry {
  const Fin13Entry(this.id,this.type,this.amount,this.currency,this.postedAt,this.reversalOf);
  final String id;
  final MovementType type;
  final Decimal amount;
  final CurrencyCode currency;
  final DateTime postedAt;
  final String? reversalOf;
  factory Fin13Entry.fromJson(Map<String,dynamic> j)=>Fin13Entry(
    _value(j,'movement_id'),_type(_value(j,'type')),_amount(j,'amount'),
    _currency(j),DateTime.parse(_value(j,'posted_at')),
    j['reversal_of_movement_id'] as String?);
}
class Fin13Statement {
  const Fin13Statement(this.currency,this.from,this.to,this.openingBalance,
    this.approvedDebts,this.approvedPayments,this.closingBalance,this.entries);
  final CurrencyCode currency;
  final String from,to;
  final Decimal openingBalance,approvedDebts,approvedPayments,closingBalance;
  final List<Fin13Entry> entries;
  factory Fin13Statement.fromJson(Map<String,dynamic> j){
    if(j['scope']!='approved_ledger_only'||j['time_zone']!='Asia/Aden'||j['items'] is! List){
      throw const FormatException('Unverified financial statement');
    }
    return Fin13Statement(_currency(j),_value(j,'from'),_value(j,'to'),
      _amount(j,'opening_balance'),_amount(j,'approved_debts'),
      _amount(j,'approved_payments'),_amount(j,'closing_balance'),
      (j['items'] as List).map((x)=>
        Fin13Entry.fromJson(Map<String,dynamic>.from(x as Map))).toList(growable:false));
  }
}
class Fin13Operation {
  const Fin13Operation(this.id,this.type,this.amount,this.currency,
    this.status,this.createdBy,this.createdByRole,this.createdAt,
    this.approvalMethod,this.description,this.reversalOf);
  final String id, status,createdBy,createdByRole,approvalMethod;
  final String? description,reversalOf;
  final MovementType type;
  final Decimal amount;
  final CurrencyCode currency;
  final DateTime createdAt;
  bool get pending=>status=='pending';
  factory Fin13Operation.fromJson(Map<String,dynamic> j){
    final s=_value(j,'status');
    if(!['pending','approved','rejected'].contains(s))throw const FormatException('Invalid status');
    return Fin13Operation(_value(j,'id'),_type(_value(j,'operation_type')),
      _amount(j,'amount'),_currency(j),s,_value(j,'created_by'),
      _value(j,'created_by_role'),DateTime.parse(_value(j,'created_at')),
      _value(j,'approval_method'),j['description'] as String?,
      j['reversal_of_movement_id'] as String?);
  }
}
class Fin13Page {
  const Fin13Page(this.items,this.nextCursor);
  final List<Fin13Operation> items;
  final String? nextCursor;
  factory Fin13Page.fromJson(Map<String,dynamic> j){
    if(j['items'] is! List || (j['next_cursor']!=null && j['next_cursor'] is! String)){
      throw const FormatException('Invalid operation page');
    }
    return Fin13Page((j['items'] as List).map((x)=>
      Fin13Operation.fromJson(Map<String,dynamic>.from(x as Map))).toList(growable:false),
      j['next_cursor'] as String?);
  }
}
class Fin13Receipt {
  const Fin13Receipt(this.id,this.status,this.replayed,this.posted,this.approvalMethod);
  final String id,status;
  final bool replayed,posted;
  final String? approvalMethod;
  factory Fin13Receipt.fromJson(Map<String,dynamic> j){
    final s=_value(j,'status');
    if(!['pending','approved','rejected'].contains(s))throw const FormatException('Invalid receipt');
    return Fin13Receipt(_value(j,'operation_id'),s,
      j['replayed']==true,j['ledger_posted']==true,j['approval_method'] as String?);
  }
}
class Fin13Policy {
  const Fin13Policy(this.enabled,this.version,this.effectiveAt);
  final bool enabled;
  final int version;
  final DateTime? effectiveAt;
  factory Fin13Policy.fromJson(Map<String,dynamic> j){
    if(j['enabled'] is! bool||j['version'] is! int)throw const FormatException('Invalid policy');
    return Fin13Policy(j['enabled'] as bool,j['version'] as int,
      j['effective_at'] is String ? DateTime.parse(j['effective_at'] as String):null);
  }
}
abstract class Fin13LedgerGateway {
  Future<Fin13Balances> balances(String relationship);
  Future<Fin13Statement> statement(String relationship,CurrencyCode currency,String from,String to);
  Future<Fin13Page> operations(String relationship,{String? cursor,int limit=50});
  Future<Fin13Receipt> create(String relationship,{required MovementType type,
    required Decimal amount,required CurrencyCode currency,required String idempotencyKey,
    String? description});
  Future<Fin13Receipt> decide(String relationship,String operation,{required bool accept});
  Future<Fin13Receipt> reverse(String relationship,String movement,{
    required String reason,required String idempotencyKey});
  Future<Fin13Policy> policy(String relationship);
  Future<Fin13Policy> setPolicy(String relationship,{required bool enabled});
}
/// Inject AFTER verified JWT login. PIN-only login must never instantiate this.
class Fin13HttpLedgerGateway implements Fin13LedgerGateway {
  const Fin13HttpLedgerGateway(this.transport);
  final Fin08HttpClaimsGateway transport;
  String _base(String id)=>'v1/relationships/'+Uri.encodeComponent(id);
  @override
  Future<Fin13Balances> balances(String id) async=>Fin13Balances.fromJson(
    await transport.sendFinancial('GET',_base(id)+'/balances'));
  @override
  Future<Fin13Statement> statement(String id,CurrencyCode unit,String from,String to) async=>
    Fin13Statement.fromJson(await transport.sendFinancial('GET',_base(id)+'/statement',
      query:{'currency':unit.name.toUpperCase(),'from':from,'to':to}));
  @override
  Future<Fin13Page> operations(String id,{String? cursor,int limit=50}) async=>
    Fin13Page.fromJson(await transport.sendFinancial('GET',_base(id)+'/operations',
      query:{'limit':limit.toString(),if(cursor!=null)'cursor':cursor}));
  @override
  Future<Fin13Receipt> create(String id,{required MovementType type,required Decimal amount,
      required CurrencyCode currency,required String idempotencyKey,String? description}) async {
    if(amount<=Decimal.zero)throw ArgumentError.value(amount,'amount','Must be positive');
    return Fin13Receipt.fromJson(await transport.sendFinancial('POST',_base(id)+'/operations',
      idempotencyKey:idempotencyKey,body:{
        'type':type.name,'amount':amount.toString(),'currency':currency.name.toUpperCase(),
        if(description!=null)'description':description}));
  }
  @override
  Future<Fin13Receipt> decide(String id,String operation,{required bool accept}) async=>
    Fin13Receipt.fromJson(await transport.sendFinancial('POST',
      _base(id)+'/operations/'+Uri.encodeComponent(operation)+'/decision',
      body:{'decision':accept?'accept':'reject'}));
  @override
  Future<Fin13Receipt> reverse(String id,String movement,{
      required String reason,required String idempotencyKey}) async=>
    Fin13Receipt.fromJson(await transport.sendFinancial('POST',_base(id)+'/reversals',
      idempotencyKey:idempotencyKey,body:{'movement_id':movement,'reason':reason}));
  @override
  Future<Fin13Policy> policy(String id) async=>
    Fin13Policy.fromJson(await transport.sendFinancial('GET',_base(id)+'/auto-approval'));
  @override
  Future<Fin13Policy> setPolicy(String id,{required bool enabled}) async=>
    Fin13Policy.fromJson(await transport.sendFinancial('POST',
      'v1/customer/relationships/'+Uri.encodeComponent(id)+'/auto-approval',
      body:{'enabled':enabled}));
}
