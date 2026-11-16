import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/fin08_api_client.dart';
import '../widgets/finance_display.dart';

/// Restores durable merchant-only contacts/claims from FIN-09 server API.
/// Requires a real merchant JWT from trusted authentication. Not the full
/// approved financial ledger; never labels claim sums as total debt balance.
class Fin08MerchantBookScreen extends StatefulWidget {
  const Fin08MerchantBookScreen({super.key,required this.gateway});
  final Fin08ClaimsGateway gateway;
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
    final name=TextEditingController();
    final phone=TextEditingController();
    var saving=false;
    String? failure;
    try {
      await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(
        builder:(ctx,setDialog)=>AlertDialog(
          title:const Text('إضافة عميل إلى سجل التاجر'),
          content:Column(mainAxisSize:MainAxisSize.min,children:[
            const Text('جهة اتصال خاصة، وليست حساباً أو مديونية معتمدة.'),
            TextField(controller:name,decoration:const InputDecoration(labelText:'اسم العميل')),
            TextField(controller:phone,keyboardType:TextInputType.phone,
              decoration:const InputDecoration(labelText:'رقم الجوال')),
            if(failure!=null)Text(failure!,style:TextStyle(color:Theme.of(ctx).colorScheme.error)),
          ]),
          actions:[
            TextButton(onPressed:saving?null:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
            FilledButton(key:const Key('fin08_save_contact'),
              onPressed:saving?null:() async {
                setDialog((){saving=true;failure=null;});
                try{
                  await widget.gateway.createMerchantContact(name:name.text.trim(),phone:phone.text.trim());
                  if(!ctx.mounted)return;
                  Navigator.pop(ctx);
                  await _loadContacts();
                }catch(e){if(ctx.mounted)setDialog(()=>failure=_message(e));}
                finally{if(ctx.mounted)setDialog(()=>saving=false);}
              },child:const Text('حفظ لدى الخادم')),
          ],
        ),
      ));
    } finally {name.dispose();phone.dispose();}
  }

  Future<void> _addClaim() async {
    final contact=_selected;
    if(contact==null)return;
    final amount=TextEditingController();
    final description=TextEditingController();
    CurrencyCode currency=CurrencyCode.yer;
    // Retain one secure random idempotency key for this ENTIRE dialog lifetime.
    // On network failure the same key is reused, avoiding double posting.
    final random=Random.secure();
    final key='claim-'+List<int>.generate(20,(_)=>random.nextInt(256))
      .map((n)=>n.toRadixString(16).padLeft(2,'0')).join();
    var saving=false;
    String? failure;
    try{
      await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(
        builder:(ctx,setDialog)=>AlertDialog(
          title:Text('مطالبة معلقة — ${contact.name}'),
          content:Column(mainAxisSize:MainAxisSize.min,children:[
            const Text('لا تُضاف إلى الرصيد المعتمد قبل موافقة العميل والعلاقة.'),
            TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:const InputDecoration(labelText:'المبلغ')),
            DropdownButton<CurrencyCode>(value:currency,isExpanded:true,
              items:CurrencyCode.values.map((c)=>DropdownMenuItem(
                value:c,child:Text(c.name.toUpperCase()))).toList(),
              onChanged:saving?null:(next){if(next!=null)setDialog(()=>currency=next);}),
            TextField(controller:description,
              decoration:const InputDecoration(labelText:'الوصف (اختياري)')),
            if(failure!=null)Text(failure!,style:TextStyle(color:Theme.of(ctx).colorScheme.error)),
          ]),
          actions:[
            TextButton(onPressed:saving?null:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
            FilledButton(key:const Key('fin08_save_claim'),onPressed:saving?null:() async {
              Decimal money;
              try{money=Decimal.parse(amount.text.trim());}
              catch(_){setDialog(()=>failure='أدخل مبلغاً عشرياً صحيحاً.');return;}
              setDialog((){saving=true;failure=null;});
              try{
                await widget.gateway.createMerchantClaim(
                  contactId:contact.id,amount:money,currency:currency,
                  idempotencyKey:key,description:description.text.trim().isEmpty?null:description.text.trim());
                if(!ctx.mounted)return;
                Navigator.pop(ctx);
                await _select(contact);
              }catch(e){if(ctx.mounted)setDialog(()=>failure=_message(e));}
              finally{if(ctx.mounted)setDialog(()=>saving=false);}
            },child:const Text('حفظ كمطالبة معلقة')),
          ],
        ),
      ));
    }finally{amount.dispose();description.dispose();}
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
          if(_selected==null) ...[
            for(final bucket in _summary) Card(child:Padding(
              padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(bucket.currency.name.toUpperCase(),style:const TextStyle(fontWeight:FontWeight.bold)),
                Text('خارج التطبيق: ${FinanceDisplay.amount(bucket.outsideApp)}'),
                Text('بانتظار الموافقات: ${FinanceDisplay.amount(bucket.awaitingCustomer)}'),
                Text('معتمد من هذه المطالبات فقط: ${FinanceDisplay.amount(bucket.approvedFromClaims)}'),
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
                subtitle:Text('${claim.description??'مبلغ سجله التاجر'}\n${claim.stage.label}'),
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