import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';
import '../services/fin08_api_client.dart';
import '../services/fin08_pending_statement.dart';
import '../services/fin15_amendment_gateway.dart';
import 'fin15_amendments_screen.dart';
import '../widgets/finance_display.dart';

/// Restores durable merchant-only contacts/claims from FIN-09 server API.
/// Requires a real merchant JWT from trusted authentication. Not the full
/// approved financial ledger; never labels claim sums as total debt balance.
class Fin08MerchantBookScreen extends StatefulWidget {
  const Fin08MerchantBookScreen({super.key,required this.gateway,this.amendmentGateway});
  final Fin08ClaimsGateway gateway;
  final Fin15AmendmentGateway? amendmentGateway;
  @override
  State<Fin08MerchantBookScreen> createState() => _Fin08MerchantBookScreenState();
}

class _Fin08MerchantBookScreenState extends State<Fin08MerchantBookScreen> {
  List<Fin08MerchantContact> _contacts=const [];
  List<Fin08MerchantClaim> _claims=const [];
  List<Fin08CurrencyBuckets> _summary=const [];
  String? _contactsCursor;
  String? _claimsCursor;
  Fin08MerchantContact? _selected;
  String? _error;
  bool _loading=false;
  bool _statementLoading=false;

  @override
  void initState(){super.initState();_loadContacts();}

  Future<void> _loadContacts({bool more=false}) async {
    if(_loading) return;
    setState(() {_loading=true;_error=null;});
    try {
      final page=await widget.gateway.merchantContacts(cursor:more?_contactsCursor:null);
      final totals=await widget.gateway.merchantClaimSummary();
      if(!mounted)return;
      setState(() {
        _contacts=more?List.unmodifiable([..._contacts,...page.items]):page.items;
        _contactsCursor=page.nextCursor;
        _summary=totals;
      });
    } catch(e){if(mounted)setState(()=>_error=_message(e));}
    finally{if(mounted)setState(()=>_loading=false);}
  }

  Future<void> _select(Fin08MerchantContact? contact,{bool more=false}) async {
    if(_loading)return;
    setState(() {
      _selected=contact;_error=null;_loading=true;
      if(!more){_claims=const [];_claimsCursor=null;}
    });
    try {
      if(contact==null){setState((){_claims=const [];_claimsCursor=null;});return;}
      final page=await widget.gateway.merchantClaims(contact.id,cursor:more?_claimsCursor:null);
      if(!mounted)return;
      setState((){
        _claims=more?List.unmodifiable([..._claims,...page.items]):page.items;
        _claimsCursor=page.nextCursor;
      });
    } catch(e){if(mounted)setState(()=>_error=_message(e));}
    finally{if(mounted)setState(()=>_loading=false);}
  }

  String _message(Object error)=>error is Fin08ApiError?error.message:
    'تعذر الاتصال بالخادم. لم نؤكد حفظ البيانات.';

  Future<void> _addContact() async {
    var name='';
    var phone='';
    var saving=false;
    String? failure;
    Fin08ClaimReceipt? confirmedReceipt;
    final saved=await showDialog<bool>(
        context:context,barrierDismissible:false,
        builder:(dialogContext)=>StatefulBuilder(
          builder:(ctx,setDialog)=>AlertDialog(
            scrollable:true,
            title:const Text('إضافة عميل إلى سجل التاجر'),
            content:Column(mainAxisSize:MainAxisSize.min,children:[
              const Text('جهة اتصال خاصة، وليست حساباً أو مديونية معتمدة.'),
              TextField(onChanged:(v)=>name=v,decoration:const InputDecoration(labelText:'اسم العميل')),
              TextField(onChanged:(v)=>phone=v,keyboardType:TextInputType.phone,
                decoration:const InputDecoration(labelText:'رقم الجوال')),
              if(failure!=null)Text(failure!,style:TextStyle(color:Theme.of(ctx).colorScheme.error)),
            ]),
            actions:[
              TextButton(onPressed:saving?null:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
              FilledButton(key:const Key('fin08_save_contact'),
                onPressed:saving?null:() async {
                  setDialog((){saving=true;failure=null;});
                  var success=false;
                  try{
                    await widget.gateway.createMerchantContact(name:name.trim(),phone:phone.trim());
                    if(!ctx.mounted)return;
                    success=true;
                    Navigator.pop(ctx,true);
                  }catch(e){if(ctx.mounted)setDialog(()=>failure=_message(e));}
                  finally{if(!success && ctx.mounted)setDialog(()=>saving=false);}
                },child:const Text('حفظ لدى الخادم')),
            ],
          ),
        ),
      );
      // Refresh AFTER the route has closed; never mutate a disposed dialog.
      if(saved==true && mounted)await _loadContacts();

  }

  Future<void> _addClaim({MovementType type=MovementType.debt}) async {
    final contact=_selected;
    if(contact==null)return;
    var amountText='';
    var descriptionText='';
    CurrencyCode currency=CurrencyCode.yer;
    // Keep same key throughout retries of THIS request, including timeout.
    final random=Random.secure();
    final key='claim-'+List<int>.generate(20,(_)=>random.nextInt(256))
      .map((n)=>n.toRadixString(16).padLeft(2,'0')).join();
    var saving=false;
    String? failure;
    final saved=await showDialog<bool>(
        context:context,barrierDismissible:false,
        builder:(dialogContext)=>StatefulBuilder(
          builder:(ctx,setDialog)=>AlertDialog(
            scrollable:true,
            title:Text('${type==MovementType.payment?'دفعة':'دين'} معلق — ${contact.name}'),
            content:Column(mainAxisSize:MainAxisSize.min,children:[
              Text(type==MovementType.payment
                ?'هذه دفعة مسجلة من طرف التاجر؛ لا تخصم من الرصيد المعتمد قبل موافقة العميل والعلاقة.'
                :'لا يُضاف الدين إلى الرصيد المعتمد قبل موافقة العميل والعلاقة.'),
              TextField(onChanged:(v)=>amountText=v,keyboardType:const TextInputType.numberWithOptions(decimal:true),
                decoration:const InputDecoration(labelText:'المبلغ')),
              DropdownButton<CurrencyCode>(value:currency,isExpanded:true,
                items:CurrencyCode.values.map((c)=>DropdownMenuItem(
                  value:c,child:Text(c.name.toUpperCase()))).toList(),
                onChanged:saving?null:(next){if(next!=null)setDialog(()=>currency=next);}),
              TextField(onChanged:(v)=>descriptionText=v,
                decoration:const InputDecoration(labelText:'الوصف (اختياري)')),
              if(failure!=null)Text(failure!,style:TextStyle(color:Theme.of(ctx).colorScheme.error)),
            ]),
            actions:[
              TextButton(onPressed:saving?null:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
              FilledButton(key:const Key('fin08_save_claim'),onPressed:saving?null:() async {
                Decimal money;
                try{money=Decimal.parse(amountText.trim());}
                catch(_){setDialog(()=>failure='أدخل مبلغاً عشرياً صحيحاً.');return;}
                setDialog((){saving=true;failure=null;});
                var success=false;
                try{
                  confirmedReceipt=await widget.gateway.createMerchantClaim(
                    contactId:contact.id,amount:money,currency:currency,type:type,
                    idempotencyKey:key,description:descriptionText.trim().isEmpty?null:descriptionText.trim());
                  if(!ctx.mounted)return;
                  success=true;
                  Navigator.pop(ctx,true);
                }catch(e){if(ctx.mounted)setDialog(()=>failure=_message(e));}
                finally{if(!success && ctx.mounted)setDialog(()=>saving=false);}
              },child:Text(type==MovementType.payment?'حفظ كدفعة معلقة':'حفظ كدين معلق')),
            ],
          ),
        ),
      );
      if(saved==true && mounted){
        await _select(contact);
        final warning=confirmedReceipt?.creditWarning;
        if(warning!=null && mounted){
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
            'تنبيه ائتماني: المبلغ المتوقع ${warning.projected} ${warning.currency.name.toUpperCase()} يتجاوز الحد ${warning.limit}. الدين مسجل كمطالبة ولا يُعتمد دون موافقة العميل.')));
        }
      }

  }

  Future<void> _requestRelationship() async {
    final contact=_selected;
    if(contact==null || _loading)return;
    final approved=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('إرسال طلب الارتباط؟'),
      content:Text('يمكن طلب الارتباط مع ${contact.name} بعد التحقق الخادمي من انضمامه. '
        'لن تصبح ديونه معتمدة بمجرد إرسال الطلب. موافقة العميل مستقلة لكل دين.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(key:const Key('fin10_confirm_merchant_request'),
          onPressed:()=>Navigator.pop(ctx,true),child:const Text('إرسال الطلب')),
      ],
    ));
    if(approved!=true || !mounted)return;
    try{
      await widget.gateway.requestMerchantRelationship(contact.id);
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('حُفظ طلب الارتباط لدى الخادم بانتظار العميل.')));
    }catch(e){
      if(!mounted)return;
      final message=e is Fin08ApiError && e.statusCode==404
        ?'لا تتوفر مطابقة هوية موثقة لهذا العميل حتى الآن. لم يُرسل طلب الارتباط.'
        :_message(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
    }
  }

  /// Fetches ALL pages again from authenticated merchant API before copying.
  /// No partial or stale local UI list is ever represented as a complete statement.
  Future<void> _copyPendingStatement() async {
    final contact=_selected;
    if(contact==null || _loading || _statementLoading)return;
    final confirmed=await showDialog<bool>(
      context:context,
      builder:(dialog)=>AlertDialog(
        title:const Text('نسخ بيان المطالبات المعلقة؟'),
        content:const Text(
          'سيتم نسخ الديون والدفعات غير المعتمدة من سجل التاجر، كل نوع منفصل. '
          'هذا ليس إقراراً من العميل ولا كشفاً للديون المعتمدة. '
          'راجع رقم المستلم وبيانات العميل قبل إرسال البيان عبر واتساب أو غيره. '
          'لن يرسل التطبيق أي رسالة تلقائياً.'),
        actions:[
          TextButton(onPressed:()=>Navigator.of(dialog).pop(false),child:const Text('إلغاء')),
          FilledButton(key:const Key('fin11_confirm_copy_pending'),
            onPressed:()=>Navigator.of(dialog).pop(true),
            child:const Text('نسخ البيان فقط')),
        ],
      ),
    );
    if(!mounted || confirmed!=true)return;
    setState(()=>_statementLoading=true);
    try {
      final all=<Fin08MerchantClaim>[];
      final seenClaims=<String>{};
      final seenCursors=<String>{};
      String? cursor;
      // A pathological page stream must fail, never silently copy an incomplete report.
      for(var pageCount=0;pageCount<1000;pageCount++){
        final page=await widget.gateway.merchantClaims(contact.id,cursor:cursor);
        for(final row in page.items){
          if(row.contactId!=contact.id || !seenClaims.add(row.id)){
            throw const Fin08ApiError('نتائج الخادم غير متسقة. لم يُنسخ الكشف.');
          }
          all.add(row);
        }
        cursor=page.nextCursor;
        if(cursor==null)break;
        if(page.items.isEmpty || !seenCursors.add(cursor)){
          throw const Fin08ApiError('لم يكتمل استرجاع جميع المطالبات. لم يُنسخ الكشف.');
        }
      }
      if(cursor!=null){
        throw const Fin08ApiError('عدد المطالبات كبير جداً لاسترجاعه كاملاً. لم يُنسخ الكشف.');
      }
      final statement=Fin08PendingStatement.compose(contact:contact,claims:all);
      await Clipboard.setData(ClipboardData(text:statement));
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('نُسخ البيان غير المعتمد. راجع رقم المستلم قبل المشاركة.'),
      ));
    }catch(e){
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text(e is Fin08ApiError?e.message:'تعذر إعداد كشف كامل من الخادم؛ لم يُنسخ أي بيان.'),
      ));
    }finally{
      if(mounted)setState(()=>_statementLoading=false);
    }
  }

  @override
  Widget build(BuildContext context){
    final c=Theme.of(context).colorScheme;
    return Scaffold(
      appBar:AppBar(title:Text(_selected==null?'سجل مطالبات التاجر':_selected!.name),
        leading:_selected==null?null:IconButton(
          tooltip:'العودة للعملاء',icon:const Icon(Icons.arrow_back),
          onPressed:_loading?null:()=>_select(null))),
      floatingActionButton:FloatingActionButton.extended(
        onPressed:_loading?null:(_selected==null?_addContact:_addClaim),
        icon:const Icon(Icons.add),
        label:Text(_selected==null?'إضافة عميل':'تسجيل دين معلق')),
      body:RefreshIndicator(
        onRefresh:()=>_selected==null?_loadContacts():_select(_selected),
        child:ListView(padding:const EdgeInsets.fromLTRB(16,14,16,85),children:[
          Text('هذا سجل مطالبات التاجر. لا تُعد المبالغ المعلقة إقراراً من العميل.',
            style:TextStyle(color:c.onSurfaceVariant)),
          const SizedBox(height:12),
          if(widget.amendmentGateway!=null) ...[
            OutlinedButton.icon(
              key:const Key('fin15_merchant_amendments'),
              icon:const Icon(Icons.edit_note_outlined),
              label:const Text('طلبات تعديل مبالغ الديون'),
              onPressed:_loading?null:() async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder:(_)=>Fin15AmendmentsScreen(
                    gateway:widget.amendmentGateway!,forMerchant:true)));
                if(!mounted)return;
                if(_selected==null)await _loadContacts();
                else await _select(_selected);
              },
            ),
            const SizedBox(height:8),
          ],
          if(_selected!=null) ...[
            OutlinedButton.icon(
              key:const Key('fin13_add_pending_payment'),
              onPressed:_loading?null:()=>_addClaim(type:MovementType.payment),
              icon:const Icon(Icons.payments_outlined),
              label:const Text('تسجيل دفعة معلقة من العميل'),
            ),
            const SizedBox(height:8),
            OutlinedButton.icon(
              key:const Key('fin11_copy_pending_statement'),
              onPressed:(_loading || _statementLoading)?null:_copyPendingStatement,
              icon:const Icon(Icons.copy_all_outlined),
              label:Text(_statementLoading?'جاري تجهيز البيان الكامل...':'نسخ كشف المطالبات المعلقة'),
            ),
            const SizedBox(height:8),
            OutlinedButton.icon(
              key:const Key('fin10_request_relationship'),
              onPressed:_loading?null:_requestRelationship,
              icon:const Icon(Icons.handshake_outlined),
              label:const Text('طلب ارتباط مع العميل'),
            ),
            const SizedBox(height:12),
          ],
          if(_selected==null) ...[
            for(final bucket in _summary) Card(child:Padding(
              padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(bucket.currency.name.toUpperCase(),style:const TextStyle(fontWeight:FontWeight.bold)),
                Text('ديون خارج التطبيق غير معتمدة: ${FinanceDisplay.amount(bucket.outsideApp)}'),
                Text('دفعات خارج التطبيق غير معتمدة: ${FinanceDisplay.amount(bucket.outsideAppPayments)}'),
                Text('ديون تنتظر الموافقات: ${FinanceDisplay.amount(bucket.awaitingCustomer)}'),
                Text('دفعات تنتظر الموافقات: ${FinanceDisplay.amount(bucket.awaitingPayments)}'),
                Text('معتمد من هذه المطالبات فقط: ${FinanceDisplay.amount(bucket.approvedFromClaims-bucket.approvedPaymentsFromClaims)}'),
                Text('هذا صافي المطالبات التاريخية فقط وليس الرصيد المالي الشامل.',style:TextStyle(color:c.onSurfaceVariant,fontSize:11)),
              ]))),
            const SizedBox(height:12),
            if(!_loading && _contacts.isEmpty && _error==null)
              const Text('لا توجد جهات اتصال محفوظة لدى الخادم.'),
            for(final contact in _contacts) Card(child:ListTile(
              key:Key('fin08_contact_${contact.id}'),
              title:Text(contact.name),subtitle:Text(contact.phone),
              trailing:const Icon(Icons.chevron_left),
              onTap:()=>_select(contact),
            )),
            if(_contactsCursor!=null && !_loading)
              TextButton(key:const Key('fin08_more_contacts'),
                onPressed:()=>_loadContacts(more:true),child:const Text('المزيد من العملاء')),
          ] else ...[
            for(final claim in _claims) Card(
              key:Key('fin08_merchant_claim_${claim.id}'),
              child:ListTile(
                title:Text('${FinanceDisplay.amount(claim.amount)} ${FinanceDisplay.currencyCode(claim.currency)}'),
                subtitle:Text('${claim.type==MovementType.payment?'دفعة':'دين'} | ${claim.description??'مبلغ سجله التاجر'}\n${claim.stage.labelFor(claim.type)}'),
              ),
            ),
            if(!_loading && _claims.isEmpty && _error==null)
              const Text('لا توجد مطالبات لهذا العميل.'),
            if(_claimsCursor!=null && !_loading)
              TextButton(key:const Key('fin08_more_claims'),
                onPressed:()=>_select(_selected,more:true),child:const Text('المزيد من المطالبات')),
          ],
          if(_error!=null)...[
            Text(_error!,key:const Key('fin08_merchant_error'),style:TextStyle(color:c.error)),
            TextButton(onPressed:_loading?null:()=>_selected==null?_loadContacts():_select(_selected),
              child:const Text('إعادة المحاولة')),
          ],
          if(_loading)const Center(child:Padding(padding:EdgeInsets.all(12),child:CircularProgressIndicator())),
        ]),
      ),
    );
  }
}