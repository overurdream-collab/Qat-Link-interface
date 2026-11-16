import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;

import '../models/app_models.dart';

/// An authenticated transport; the token MUST be issued by a trusted identity
/// provider after actual phone verification. Never use a PIN/local phone check
/// as authentication. The client does not persist tokens or claims.
class Fin08ApiError implements Exception {
  const Fin08ApiError(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;
  @override
  String toString() => 'Fin08ApiError: $message';
}

class Fin08Page<T> {
  const Fin08Page(this.items, this.nextCursor);
  final List<T> items;
  final String? nextCursor;
  bool get hasMore => nextCursor != null;
}

enum Fin08Stage {
  outsideApp,
  awaitingReview,
  acceptedAwaitingRelationship,
  acceptedAwaitingPosting,
  awaitingMerchantAdjustment,
  superseded,
  rejected,
  approved;

  static Fin08Stage fromWire(String value) => switch (value) {
        'outside_app' => outsideApp,
        'awaiting_review' => awaitingReview,
        'accepted_awaiting_relationship' => acceptedAwaitingRelationship,
        'accepted_awaiting_posting' => acceptedAwaitingPosting,
        'awaiting_merchant_adjustment' => awaitingMerchantAdjustment,
        'superseded' => superseded,
        'rejected' => rejected,
        'approved' => approved,
        _ => throw const FormatException('Unknown FIN-08 claim stage'),
      };

  String labelFor(MovementType kind) => kind == MovementType.payment
      ? switch (this) {
          outsideApp => 'دفعة خارج التطبيق — غير معتمدة',
          awaitingReview => 'دفعة بانتظار موافقة العميل — غير معتمدة',
          acceptedAwaitingRelationship => 'وافق العميل على الدفعة — العلاقة معلقة',
          acceptedAwaitingPosting => 'الدفعة تنتظر الترحيل',
          awaitingMerchantAdjustment => 'طلب تعديل الدفعة بانتظار التاجر',
          superseded => 'استُبدلت الدفعة بطلب جديد للمراجعة',
          rejected => 'دفعة مرفوضة — لا تؤثر على الرصيد',
          approved => 'دفعة معتمدة',
        }
      : label;

  String get label => switch (this) {
        outsideApp => 'عميل خارج التطبيق — غير معتمد',
        awaitingReview => 'بانتظار موافقة العميل — غير معتمد',
        acceptedAwaitingRelationship => 'وافق العميل — الارتباط معلق',
        acceptedAwaitingPosting => 'بانتظار الترحيل الموثق',
        awaitingMerchantAdjustment => 'طلب تعديل المبلغ بانتظار التاجر',
        superseded => 'استُبدل الدين بطلب جديد للمراجعة',
        rejected => 'مرفوض — لا يدخل الرصيد',
        approved => 'دين معتمد',
      };
}

CurrencyCode _currency(Object? wire) {
  if (wire is! String) throw const FormatException('Currency missing');
  return switch (wire) {
    'YER' => CurrencyCode.yer,
    'SAR' => CurrencyCode.sar,
    'USD' => CurrencyCode.usd,
    _ => throw const FormatException('Unsupported currency'),
  };
}

MovementType _movementType(Object? value) => switch (value) {
  null || 'debt' => MovementType.debt,
  'payment' => MovementType.payment,
  _ => throw const FormatException('Unknown movement type'),
};

Decimal _optionalDecimal(Map<String,dynamic> data,String key) {
  final value=data[key];
  if(value==null) return Decimal.zero; // FIN-08 response compatibility.
  if(value is! String) throw const FormatException('Invalid money field');
  return Decimal.parse(value);
}

String _str(Map<String, dynamic> data, String key, {String? alternative}) {
  final value = data[key] ?? (alternative == null ? null : data[alternative]);
  if (value is! String || value.isEmpty) throw FormatException('Missing $key');
  return value;
}

DateTime _date(Map<String, dynamic> data, String key) =>
    DateTime.parse(_str(data, key));

class Fin08MerchantContact {
  const Fin08MerchantContact({required this.id, required this.name,
    required this.phone, required this.createdAt});
  final String id;
  final String name;
  final String phone;
  final DateTime createdAt;

  factory Fin08MerchantContact.fromJson(Map<String, dynamic> json) =>
      Fin08MerchantContact(
        id: _str(json, 'contact_id', alternative: 'id'),
        name: _str(json, 'name'),
        phone: _str(json, 'phone'),
        createdAt: _date(json, 'created_at'),
      );
}

class Fin08MerchantClaim {
  const Fin08MerchantClaim({required this.id, required this.contactId,
    required this.amount, required this.currency, required this.createdAt,
    required this.stage, this.description, this.type=MovementType.debt,
    this.pendingAdjustmentId,this.proposedAmount,this.sourceClaimId,this.occurredAt});
  final String id;
  final String contactId;
  final Decimal amount;
  final CurrencyCode currency;
  final String? description;
  final DateTime createdAt;
  final Fin08Stage stage;
  final MovementType type;
  final String? pendingAdjustmentId,sourceClaimId;
  final Decimal? proposedAmount;
  final DateTime? occurredAt;

  factory Fin08MerchantClaim.fromJson(Map<String, dynamic> json) =>
      Fin08MerchantClaim(
        id: _str(json, 'claim_id', alternative: 'id'),
        contactId: _str(json, 'contact_id'),
        amount: Decimal.parse(_str(json, 'amount')),
        currency: _currency(json['currency']),
        description: json['description'] as String?,
        createdAt: _date(json, 'created_at'),
        stage: Fin08Stage.fromWire(_str(json, 'stage')),
        type: _movementType(json['type']),
        pendingAdjustmentId:json['pending_adjustment_id'] as String?,
        proposedAmount:json['proposed_amount'] is String? 
          ?(json['proposed_amount'] is String ? Decimal.parse(json['proposed_amount'] as String):null):null,
        sourceClaimId:json['source_claim_id'] as String?,
        occurredAt:json['occurred_at'] is String? 
          ?(json['occurred_at'] is String ? DateTime.parse(json['occurred_at'] as String):null):null,
      );
}

class Fin08PreviousClaim {
  const Fin08PreviousClaim({required this.id, required this.merchantId,
    required this.merchantName, required this.amount, required this.currency,
    required this.createdAt, required this.stage, this.description,
    this.type=MovementType.debt,this.pendingAdjustmentId,this.proposedAmount,
    this.sourceClaimId,this.occurredAt});
  final String id;
  final String merchantId;
  final String merchantName;
  final Decimal amount;
  final CurrencyCode currency;
  final DateTime createdAt;
  final String? description;
  final Fin08Stage stage;
  final MovementType type;
  final String? pendingAdjustmentId,sourceClaimId;
  final Decimal? proposedAmount;
  final DateTime? occurredAt;
  bool get canReview => stage == Fin08Stage.awaitingReview;

  factory Fin08PreviousClaim.fromJson(Map<String, dynamic> json) =>
      Fin08PreviousClaim(
        id: _str(json, 'claim_id'),
        merchantId: _str(json, 'merchant_id'),
        merchantName: _str(json, 'merchant_display_name'),
        amount: Decimal.parse(_str(json, 'amount')),
        currency: _currency(json['currency']),
        description: json['description'] as String?,
        createdAt: _date(json, 'created_at'),
        stage: Fin08Stage.fromWire(_str(json, 'stage')),
        type: _movementType(json['type']),
        pendingAdjustmentId:json['pending_adjustment_id'] as String?,
        proposedAmount:json['proposed_amount'] is String
          ?Decimal.parse(json['proposed_amount'] as String):null,
        sourceClaimId:json['source_claim_id'] as String?,
        occurredAt:json['occurred_at'] is String
          ?DateTime.parse(json['occurred_at'] as String):null,
      );
}

class Fin08CustomerRelationship {
  const Fin08CustomerRelationship({required this.id,required this.merchantId,
    required this.merchantName,required this.status,required this.createdAt});
  final String id;
  final String merchantId;
  final String merchantName;
  final String status;
  final DateTime createdAt;
  bool get canDecide => status=='pending';
  factory Fin08CustomerRelationship.fromJson(Map<String,dynamic> json) {
    final state=_str(json,'status');
    if(!['pending','approved','rejected'].contains(state)) {
      throw const FormatException('Unknown relationship status');
    }
    return Fin08CustomerRelationship(id:_str(json,'relationship_id'),
      merchantId:_str(json,'merchant_id'),
      merchantName:_str(json,'merchant_display_name'),
      status:state,createdAt:_date(json,'created_at'));
  }
}

class Fin08RelationshipReceipt {
  const Fin08RelationshipReceipt({required this.relationshipId,required this.status,
    required this.newlyPostedDebts});
  final String relationshipId;
  final String status;
  final int newlyPostedDebts;
}

class Fin08ClaimReceipt {
  const Fin08ClaimReceipt({required this.claimId, required this.replayed});
  final String claimId;
  final bool replayed;
}

class Fin08ClaimDecisionReceipt {
  const Fin08ClaimDecisionReceipt({required this.claimId,
    required this.decision, required this.recorded, required this.ledgerPosted});
  final String claimId;
  final String decision;
  final bool recorded;
  final bool ledgerPosted;
}

class Fin08CurrencyBuckets {
  Fin08CurrencyBuckets({required this.currency,required this.outsideApp,
    required this.awaitingCustomer,required this.approvedFromClaims,
    Decimal? outsideAppPayments,Decimal? awaitingPayments,
    Decimal? approvedPaymentsFromClaims})
      : outsideAppPayments=outsideAppPayments??Decimal.zero,
        awaitingPayments=awaitingPayments??Decimal.zero,
        approvedPaymentsFromClaims=approvedPaymentsFromClaims??Decimal.zero;
  final CurrencyCode currency;
  final Decimal outsideApp;
  final Decimal outsideAppPayments;
  final Decimal awaitingCustomer;
  final Decimal awaitingPayments;
  final Decimal approvedPaymentsFromClaims;
  /// Only approved pre-registration claims, NOT full accounting net.
  final Decimal approvedFromClaims;
  factory Fin08CurrencyBuckets.fromJson(Map<String,dynamic> json) =>
      Fin08CurrencyBuckets(
        currency:_currency(json['currency']),
        outsideApp:Decimal.parse(_str(json,'outside_app')),
        awaitingCustomer:Decimal.parse(_str(json,'awaiting_customer_or_relationship')),
        approvedFromClaims:Decimal.parse(_str(json,'approved_from_claims')),
        outsideAppPayments:_optionalDecimal(json,'outside_app_payments'),
        awaitingPayments:_optionalDecimal(json,'awaiting_payments'),
        approvedPaymentsFromClaims:_optionalDecimal(json,'approved_payments_from_claims'),
      );
}

/// Enables mock transport and customer/merchant UI without fake success.
abstract class Fin08ClaimsGateway {
  Future<Fin08Page<Fin08MerchantContact>> merchantContacts({String? cursor,int limit=50});
  Future<Fin08Page<Fin08MerchantClaim>> merchantClaims(String contactId,{String? cursor,int limit=50});
  Future<Fin08MerchantContact> createMerchantContact({required String name,required String phone});
  Future<Fin08ClaimReceipt> createMerchantClaim({required String contactId,required Decimal amount,
    required CurrencyCode currency,required String idempotencyKey,String? description,
    MovementType type=MovementType.debt});
  Future<List<Fin08CurrencyBuckets>> merchantClaimSummary();
  Future<String> requestMerchantRelationship(String contactId);
  Future<Fin08Page<Fin08CustomerRelationship>> customerRelationships({String? cursor,int limit=50});
  Future<Fin08RelationshipReceipt> decideRelationship(String relationshipId,{required bool accept});
  Future<Fin08Page<Fin08PreviousClaim>> customerPreviousClaims({String? cursor,int limit=50});
  Future<Fin08ClaimDecisionReceipt> decidePreviousClaim(String claimId,{required bool accept});
}

class Fin08HttpClaimsGateway implements Fin08ClaimsGateway {
  Fin08HttpClaimsGateway({required this.baseUri,required this.client,
    required this.accessToken, this.timeout=const Duration(seconds:20)}) {
    final secure=baseUri.scheme=='https';
    final loopback=baseUri.scheme=='http' &&
        (baseUri.host=='127.0.0.1'||baseUri.host=='localhost'||baseUri.host=='::1');
    if (!secure && !loopback) throw ArgumentError('HTTPS is required outside local testing');
    if (baseUri.userInfo.isNotEmpty || baseUri.hasQuery || baseUri.hasFragment) {
      throw ArgumentError('Use a clean service base URI');
    }
  }

  final Uri baseUri;
  final http.Client client;
  final Future<String> Function() accessToken;
  final Duration timeout;

  Future<Map<String,dynamic>> _request(String method,String path,
      {Map<String,String>? query,Object? body,String? idempotencyKey}) async {
    final token=await accessToken();
    if (token.trim().isEmpty) throw const Fin08ApiError('يجب تسجيل الدخول بحساب موثق قبل المتابعة.',code:'no_session');
    final uri=baseUri.resolve(path).replace(queryParameters:query);
    final headers=<String,String>{'authorization':'Bearer $token','accept':'application/json'};
    if(body!=null) headers['content-type']='application/json';
    if(idempotencyKey!=null) headers['Idempotency-Key']=idempotencyKey;
    try {
      final response=await (method=='GET'
          ?client.get(uri,headers:headers)
          :client.post(uri,headers:headers,body:jsonEncode(body))).timeout(timeout);
      Map<String,dynamic> decoded;
      try {
        final value=jsonDecode(response.body);
        if(value is! Map<String,dynamic>) throw const FormatException('Unexpected response');
        decoded=value;
      } on FormatException {
        throw const Fin08ApiError('رد غير مفهوم من الخادم.',code:'invalid_response');
      }
      if(response.statusCode<200 || response.statusCode>=300) {
        throw Fin08ApiError(
          response.statusCode==401?'انتهت جلسة الدخول. أعد تسجيل الدخول.':
          response.statusCode==403?'ليس لديك صلاحية تنفيذ هذا الإجراء.':
          response.statusCode==409?'يوجد تعارض في الطلب أو سبق اتخاذ قرار مختلف.':
          response.statusCode>=500?'الخادم غير متاح حالياً. لم نؤكد حفظ العملية.':
          (decoded['message'] is String ? decoded['message'] as String : 'فشل الطلب.'),
          statusCode:response.statusCode,
          code:decoded['error'] is String ? decoded['error'] as String : null,
        );
      }
      return decoded;
    } on Fin08ApiError { rethrow; }
      on TimeoutException { throw const Fin08ApiError('انتهت مهلة الاتصال. تحقق من حالة الطلب قبل إعادة الإرسال.',code:'timeout'); }
      on http.ClientException { throw const Fin08ApiError('تعذر الاتصال بالخادم. لم نؤكد تسجيل العملية.',code:'network'); }
      on Exception { throw const Fin08ApiError('تعذر الاتصال بالخادم. لم نؤكد تسجيل العملية.',code:'network'); }
  }

  /// Reuses the verified session and HTTPS policy for FIN-13 financial endpoints.
  /// This is transport only: every authorization decision remains on the server.
  Future<Map<String,dynamic>> sendFinancial(String method,String path,
      {Map<String,String>? query,Object? body,String? idempotencyKey}) {
    if((method!='GET' && method!='POST') ||
        !(path.startsWith('v1/relationships/') ||
          path.startsWith('v1/customer/relationships/') ||
          path=='v1/customer/previous-claims/batch-decisions' ||
          RegExp(r'^v1/customer/previous-claims/[A-Za-z0-9_-]+/amount-adjustment
        path.contains('..') || path.startsWith('/')) {
      throw ArgumentError('Invalid financial request route');
    }
    return _request(method,path,query:query,body:body,idempotencyKey:idempotencyKey);
  }

  Fin08Page<T> _parsePage<T>(Map<String,dynamic> result,T Function(Map<String,dynamic>) parse) {
    final raw=result['items'];
    if(raw is! List) throw const Fin08ApiError('قائمة غير صالحة من الخادم.',code:'invalid_response');
    try {
      final values=raw.map((item)=>parse(Map<String,dynamic>.from(item as Map))).toList(growable:false);
      final cursor=result['next_cursor'];
      if(cursor!=null && cursor is! String) throw const FormatException('cursor');
      return Fin08Page<T>(values,cursor as String?);
    } on FormatException { throw const Fin08ApiError('بيانات غير صالحة من الخادم.',code:'invalid_response'); }
      on TypeError { throw const Fin08ApiError('بيانات غير صالحة من الخادم.',code:'invalid_response'); }
  }

  Map<String,String> _pagination(String? cursor,int limit) => {
    'limit':'$limit',if(cursor!=null)'cursor':cursor,
  };

  @override
  Future<Fin08Page<Fin08MerchantContact>> merchantContacts({String? cursor,int limit=50}) async =>
      _parsePage(await _request('GET','v1/merchant/contacts',query:_pagination(cursor,limit)),Fin08MerchantContact.fromJson);

  @override
  Future<Fin08Page<Fin08MerchantClaim>> merchantClaims(String contactId,{String? cursor,int limit=50}) async =>
      _parsePage(await _request('GET','v1/merchant/contacts/${Uri.encodeComponent(contactId)}/claims',
        query:_pagination(cursor,limit)),Fin08MerchantClaim.fromJson);

  @override
  Future<Fin08MerchantContact> createMerchantContact({required String name,required String phone}) async =>
      Fin08MerchantContact.fromJson(await _request('POST','v1/merchant/contacts',body:{'name':name,'phone':phone}));

  @override
  Future<Fin08ClaimReceipt> createMerchantClaim({required String contactId,
      required Decimal amount,required CurrencyCode currency,
      required String idempotencyKey,String? description,
      MovementType type=MovementType.debt}) async {
    if(amount<=Decimal.zero) throw ArgumentError.value(amount,'amount','Must be positive');
    final value=await _request('POST','v1/merchant/claims',idempotencyKey:idempotencyKey,
        body:{'contact_id':contactId,'amount':amount.toString(),
          'currency':currency.name.toUpperCase(),'type':type.name,if(description!=null)'description':description});
    return Fin08ClaimReceipt(claimId:_str(value,'id'),replayed:value['replayed']==true);
  }

  @override
  Future<List<Fin08CurrencyBuckets>> merchantClaimSummary() async {
    final response=await _request('GET','v1/merchant/claims/summary');
    if(response['approved_scope']!='pre_registration_claims_only_not_full_ledger') {
      throw const Fin08ApiError('نطاق الرصيد غير موثق.',code:'invalid_response');
    }
    final raw=response['currencies'];
    if(raw is! List) throw const Fin08ApiError('ملخص غير صالح من الخادم.',code:'invalid_response');
    return raw.map((v)=>Fin08CurrencyBuckets.fromJson(Map<String,dynamic>.from(v as Map))).toList(growable:false);
  }

  @override
  Future<String> requestMerchantRelationship(String contactId) async {
    final data=await _request('POST','v1/merchant/relationship-requests',
      body:{'contact_id':contactId});
    final status=_str(data,'status');
    if(status!='pending')throw const Fin08ApiError('حالة الارتباط غير مؤكدة.',code:'invalid_response');
    return _str(data,'relationship_id');
  }

  @override
  Future<Fin08Page<Fin08CustomerRelationship>> customerRelationships({String? cursor,int limit=50}) async =>
    _parsePage(await _request('GET','v1/customer/relationships',query:_pagination(cursor,limit)),
      Fin08CustomerRelationship.fromJson);

  @override
  Future<Fin08RelationshipReceipt> decideRelationship(String relationshipId,{required bool accept}) async {
    final result=await _request('POST','v1/customer/relationships/${Uri.encodeComponent(relationshipId)}/decision',
      body:{'decision':accept?'accept':'reject'});
    final status=_str(result,'status');
    if(status!=(accept?'approved':'rejected')) {
      throw const Fin08ApiError('قرار العلاقة غير مؤكد.',code:'invalid_response');
    }
    return Fin08RelationshipReceipt(relationshipId:_str(result,'relationship_id'),
      status:status,newlyPostedDebts:result['newly_posted_debts'] is int
        ?result['newly_posted_debts'] as int:0);
  }

  @override
  Future<Fin08Page<Fin08PreviousClaim>> customerPreviousClaims({String? cursor,int limit=50}) async =>
      _parsePage(await _request('GET','v1/customer/previous-claims',query:_pagination(cursor,limit)),
        Fin08PreviousClaim.fromJson);

  @override
  Future<Fin08ClaimDecisionReceipt> decidePreviousClaim(String claimId,{required bool accept}) async {
    final result=await _request('POST','v1/customer/previous-claims/${Uri.encodeComponent(claimId)}/decision',
      body:{'decision':accept?'accept':'reject'});
    final decision=_str(result,'decision');
    if(decision!=(accept?'accept':'reject')) throw const Fin08ApiError('القرار غير مؤكد من الخادم.',code:'invalid_response');
    return Fin08ClaimDecisionReceipt(claimId:_str(result,'claim_id'),decision:decision,
      recorded:result['recorded']==true,ledgerPosted:result['ledger_posted']==true);
  }
}).hasMatch(path) ||
          RegExp(r'^v1/merchant/claim-adjustments/[A-Za-z0-9_-]+/decision
        path.contains('..') || path.startsWith('/')) {
      throw ArgumentError('Invalid financial request route');
    }
    return _request(method,path,query:query,body:body,idempotencyKey:idempotencyKey);
  }

  Fin08Page<T> _parsePage<T>(Map<String,dynamic> result,T Function(Map<String,dynamic>) parse) {
    final raw=result['items'];
    if(raw is! List) throw const Fin08ApiError('قائمة غير صالحة من الخادم.',code:'invalid_response');
    try {
      final values=raw.map((item)=>parse(Map<String,dynamic>.from(item as Map))).toList(growable:false);
      final cursor=result['next_cursor'];
      if(cursor!=null && cursor is! String) throw const FormatException('cursor');
      return Fin08Page<T>(values,cursor as String?);
    } on FormatException { throw const Fin08ApiError('بيانات غير صالحة من الخادم.',code:'invalid_response'); }
      on TypeError { throw const Fin08ApiError('بيانات غير صالحة من الخادم.',code:'invalid_response'); }
  }

  Map<String,String> _pagination(String? cursor,int limit) => {
    'limit':'$limit',if(cursor!=null)'cursor':cursor,
  };

  @override
  Future<Fin08Page<Fin08MerchantContact>> merchantContacts({String? cursor,int limit=50}) async =>
      _parsePage(await _request('GET','v1/merchant/contacts',query:_pagination(cursor,limit)),Fin08MerchantContact.fromJson);

  @override
  Future<Fin08Page<Fin08MerchantClaim>> merchantClaims(String contactId,{String? cursor,int limit=50}) async =>
      _parsePage(await _request('GET','v1/merchant/contacts/${Uri.encodeComponent(contactId)}/claims',
        query:_pagination(cursor,limit)),Fin08MerchantClaim.fromJson);

  @override
  Future<Fin08MerchantContact> createMerchantContact({required String name,required String phone}) async =>
      Fin08MerchantContact.fromJson(await _request('POST','v1/merchant/contacts',body:{'name':name,'phone':phone}));

  @override
  Future<Fin08ClaimReceipt> createMerchantClaim({required String contactId,
      required Decimal amount,required CurrencyCode currency,
      required String idempotencyKey,String? description,
      MovementType type=MovementType.debt}) async {
    if(amount<=Decimal.zero) throw ArgumentError.value(amount,'amount','Must be positive');
    final value=await _request('POST','v1/merchant/claims',idempotencyKey:idempotencyKey,
        body:{'contact_id':contactId,'amount':amount.toString(),
          'currency':currency.name.toUpperCase(),'type':type.name,if(description!=null)'description':description});
    return Fin08ClaimReceipt(claimId:_str(value,'id'),replayed:value['replayed']==true);
  }

  @override
  Future<List<Fin08CurrencyBuckets>> merchantClaimSummary() async {
    final response=await _request('GET','v1/merchant/claims/summary');
    if(response['approved_scope']!='pre_registration_claims_only_not_full_ledger') {
      throw const Fin08ApiError('نطاق الرصيد غير موثق.',code:'invalid_response');
    }
    final raw=response['currencies'];
    if(raw is! List) throw const Fin08ApiError('ملخص غير صالح من الخادم.',code:'invalid_response');
    return raw.map((v)=>Fin08CurrencyBuckets.fromJson(Map<String,dynamic>.from(v as Map))).toList(growable:false);
  }

  @override
  Future<String> requestMerchantRelationship(String contactId) async {
    final data=await _request('POST','v1/merchant/relationship-requests',
      body:{'contact_id':contactId});
    final status=_str(data,'status');
    if(status!='pending')throw const Fin08ApiError('حالة الارتباط غير مؤكدة.',code:'invalid_response');
    return _str(data,'relationship_id');
  }

  @override
  Future<Fin08Page<Fin08CustomerRelationship>> customerRelationships({String? cursor,int limit=50}) async =>
    _parsePage(await _request('GET','v1/customer/relationships',query:_pagination(cursor,limit)),
      Fin08CustomerRelationship.fromJson);

  @override
  Future<Fin08RelationshipReceipt> decideRelationship(String relationshipId,{required bool accept}) async {
    final result=await _request('POST','v1/customer/relationships/${Uri.encodeComponent(relationshipId)}/decision',
      body:{'decision':accept?'accept':'reject'});
    final status=_str(result,'status');
    if(status!=(accept?'approved':'rejected')) {
      throw const Fin08ApiError('قرار العلاقة غير مؤكد.',code:'invalid_response');
    }
    return Fin08RelationshipReceipt(relationshipId:_str(result,'relationship_id'),
      status:status,newlyPostedDebts:result['newly_posted_debts'] is int
        ?result['newly_posted_debts'] as int:0);
  }

  @override
  Future<Fin08Page<Fin08PreviousClaim>> customerPreviousClaims({String? cursor,int limit=50}) async =>
      _parsePage(await _request('GET','v1/customer/previous-claims',query:_pagination(cursor,limit)),
        Fin08PreviousClaim.fromJson);

  @override
  Future<Fin08ClaimDecisionReceipt> decidePreviousClaim(String claimId,{required bool accept}) async {
    final result=await _request('POST','v1/customer/previous-claims/${Uri.encodeComponent(claimId)}/decision',
      body:{'decision':accept?'accept':'reject'});
    final decision=_str(result,'decision');
    if(decision!=(accept?'accept':'reject')) throw const Fin08ApiError('القرار غير مؤكد من الخادم.',code:'invalid_response');
    return Fin08ClaimDecisionReceipt(claimId:_str(result,'claim_id'),decision:decision,
      recorded:result['recorded']==true,ledgerPosted:result['ledger_posted']==true);
  }
}).hasMatch(path)) ||
        path.contains('..') || path.startsWith('/')) {
      throw ArgumentError('Invalid financial request route');
    }
    return _request(method,path,query:query,body:body,idempotencyKey:idempotencyKey);
  }

  Fin08Page<T> _parsePage<T>(Map<String,dynamic> result,T Function(Map<String,dynamic>) parse) {
    final raw=result['items'];
    if(raw is! List) throw const Fin08ApiError('قائمة غير صالحة من الخادم.',code:'invalid_response');
    try {
      final values=raw.map((item)=>parse(Map<String,dynamic>.from(item as Map))).toList(growable:false);
      final cursor=result['next_cursor'];
      if(cursor!=null && cursor is! String) throw const FormatException('cursor');
      return Fin08Page<T>(values,cursor as String?);
    } on FormatException { throw const Fin08ApiError('بيانات غير صالحة من الخادم.',code:'invalid_response'); }
      on TypeError { throw const Fin08ApiError('بيانات غير صالحة من الخادم.',code:'invalid_response'); }
  }

  Map<String,String> _pagination(String? cursor,int limit) => {
    'limit':'$limit',if(cursor!=null)'cursor':cursor,
  };

  @override
  Future<Fin08Page<Fin08MerchantContact>> merchantContacts({String? cursor,int limit=50}) async =>
      _parsePage(await _request('GET','v1/merchant/contacts',query:_pagination(cursor,limit)),Fin08MerchantContact.fromJson);

  @override
  Future<Fin08Page<Fin08MerchantClaim>> merchantClaims(String contactId,{String? cursor,int limit=50}) async =>
      _parsePage(await _request('GET','v1/merchant/contacts/${Uri.encodeComponent(contactId)}/claims',
        query:_pagination(cursor,limit)),Fin08MerchantClaim.fromJson);

  @override
  Future<Fin08MerchantContact> createMerchantContact({required String name,required String phone}) async =>
      Fin08MerchantContact.fromJson(await _request('POST','v1/merchant/contacts',body:{'name':name,'phone':phone}));

  @override
  Future<Fin08ClaimReceipt> createMerchantClaim({required String contactId,
      required Decimal amount,required CurrencyCode currency,
      required String idempotencyKey,String? description,
      MovementType type=MovementType.debt}) async {
    if(amount<=Decimal.zero) throw ArgumentError.value(amount,'amount','Must be positive');
    final value=await _request('POST','v1/merchant/claims',idempotencyKey:idempotencyKey,
        body:{'contact_id':contactId,'amount':amount.toString(),
          'currency':currency.name.toUpperCase(),'type':type.name,if(description!=null)'description':description});
    return Fin08ClaimReceipt(claimId:_str(value,'id'),replayed:value['replayed']==true);
  }

  @override
  Future<List<Fin08CurrencyBuckets>> merchantClaimSummary() async {
    final response=await _request('GET','v1/merchant/claims/summary');
    if(response['approved_scope']!='pre_registration_claims_only_not_full_ledger') {
      throw const Fin08ApiError('نطاق الرصيد غير موثق.',code:'invalid_response');
    }
    final raw=response['currencies'];
    if(raw is! List) throw const Fin08ApiError('ملخص غير صالح من الخادم.',code:'invalid_response');
    return raw.map((v)=>Fin08CurrencyBuckets.fromJson(Map<String,dynamic>.from(v as Map))).toList(growable:false);
  }

  @override
  Future<String> requestMerchantRelationship(String contactId) async {
    final data=await _request('POST','v1/merchant/relationship-requests',
      body:{'contact_id':contactId});
    final status=_str(data,'status');
    if(status!='pending')throw const Fin08ApiError('حالة الارتباط غير مؤكدة.',code:'invalid_response');
    return _str(data,'relationship_id');
  }

  @override
  Future<Fin08Page<Fin08CustomerRelationship>> customerRelationships({String? cursor,int limit=50}) async =>
    _parsePage(await _request('GET','v1/customer/relationships',query:_pagination(cursor,limit)),
      Fin08CustomerRelationship.fromJson);

  @override
  Future<Fin08RelationshipReceipt> decideRelationship(String relationshipId,{required bool accept}) async {
    final result=await _request('POST','v1/customer/relationships/${Uri.encodeComponent(relationshipId)}/decision',
      body:{'decision':accept?'accept':'reject'});
    final status=_str(result,'status');
    if(status!=(accept?'approved':'rejected')) {
      throw const Fin08ApiError('قرار العلاقة غير مؤكد.',code:'invalid_response');
    }
    return Fin08RelationshipReceipt(relationshipId:_str(result,'relationship_id'),
      status:status,newlyPostedDebts:result['newly_posted_debts'] is int
        ?result['newly_posted_debts'] as int:0);
  }

  @override
  Future<Fin08Page<Fin08PreviousClaim>> customerPreviousClaims({String? cursor,int limit=50}) async =>
      _parsePage(await _request('GET','v1/customer/previous-claims',query:_pagination(cursor,limit)),
        Fin08PreviousClaim.fromJson);

  @override
  Future<Fin08ClaimDecisionReceipt> decidePreviousClaim(String claimId,{required bool accept}) async {
    final result=await _request('POST','v1/customer/previous-claims/${Uri.encodeComponent(claimId)}/decision',
      body:{'decision':accept?'accept':'reject'});
    final decision=_str(result,'decision');
    if(decision!=(accept?'accept':'reject')) throw const Fin08ApiError('القرار غير مؤكد من الخادم.',code:'invalid_response');
    return Fin08ClaimDecisionReceipt(claimId:_str(result,'claim_id'),decision:decision,
      recorded:result['recorded']==true,ledgerPosted:result['ledger_posted']==true);
  }
}