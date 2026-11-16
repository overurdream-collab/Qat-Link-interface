import 'dart:math';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/fin08_api_client.dart';
import '../services/fin15_amendment_gateway.dart';
import '../widgets/finance_display.dart';

/// Displays customer proposals and authenticated merchant answers; never edits
/// an amount in place. The actual decision/posting belongs to PostgreSQL.
class Fin15AmendmentsScreen extends StatefulWidget {
  const Fin15AmendmentsScreen({super.key,required this.gateway,
    required this.forMerchant});
  final Fin15AmendmentGateway gateway;
  final bool forMerchant;
  @override
  State<Fin15AmendmentsScreen> createState()=>_Fin15AmendmentsScreenState();
}
class _Fin15AmendmentsScreenState extends State<Fin15AmendmentsScreen>{
  List<Fin15Amendment> _items=const [];
  String? _nextCursor,_error;
  bool _loading=false,_acting=false;

  @override
  void initState(){super.initState();_load();}

  String _failure(Object e)=>e is Fin08ApiError?e.message:
    'لم نؤكد استجابة الخادم. أعد التحقق من الطلب.';

  Future<void> _load({bool more=false}) async{
    if(_loading)return;
    setState((){_loading=true;_error=null;});
    try{
      final result=await widget.gateway.list(
        forMerchant:widget.forMerchant,cursor:more?_nextCursor:null);
      if(!mounted)return;
      setState((){
        _items=more?List.unmodifiable([..._items,...result.items]):result.items;
        _nextCursor=result.nextCursor;
      });
    }catch(e){if(mounted)setState(()=>_error=_failure(e));}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  Future<void> _decide(Fin15Amendment amendment,bool accept) async{
    if(_acting||!amendment.pending||!widget.forMerchant)return;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(accept?'الموافقة على المبلغ المقترح؟':'رفض المبلغ المقترح؟'),
      content:Text('المبلغ الأصلي: '+amendment.oldAmount.toString()+' '+
        amendment.currency.name.toUpperCase()+
        '\nالمبلغ المقترح من العميل: '+amendment.proposedAmount.toString()+' '+
        amendment.currency.name.toUpperCase()+
        '\nالسبب: '+amendment.reason+
        '\n'+(accept
          ?'قبولك ومقترح العميل يشكلان موافقة مستقلة على البديل. '
            'لا يرحّل الخادم أي مبلغ قبل تحقق شروط العلاقة.'
          :'الرفض يُبقي الدين الأصلي معلقًا دون تغيير رصيده.')),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(key:const Key('fin15_confirm_merchant_decision'),
          onPressed:()=>Navigator.pop(ctx,true),
          child:Text(accept?'أقبل التعديل':'أرفض التعديل')),
      ],
    ));
    if(ok!=true||!mounted)return;
    setState(()=>_acting=true);
    try{
      final saved=await widget.gateway.merchantDecision(amendment.id,accept:accept);
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
        saved.ledgerPosted
          ?'أكّد الخادم ترحيل القيد البديل بعد موافقتي الطرفين.'
          :accept
            ?'قُبل التعديل، والقيد البديل ينتظر استيفاء شروط الاعتماد.'
            :'رُفض التعديل؛ لم يتغير الرصيد المعتمد.')));
      await _load();
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(_failure(e))));
    }finally{if(mounted)setState(()=>_acting=false);}
  }
  @override
  Widget build(BuildContext context){
    final scheme=Theme.of(context).colorScheme;
    return Scaffold(
      appBar:AppBar(title:Text(widget.forMerchant?'طلبات تعديل الديون':'طلبات تعديلاتي'),
        actions:[IconButton(icon:const Icon(Icons.refresh),
          onPressed:_loading?null:()=>_load())]),
      body:RefreshIndicator(
        onRefresh:()=>_load(),
        child:ListView(padding:const EdgeInsets.all(16),children:[
          const Text('هذا السجل يوضح المبالغ الأصلية والمقترحة وقرارات التعديل. '
            'لا تدخل الطلبات المعلقة في الرصيد المعتمد.'),
          const SizedBox(height:12),
          if(_error!=null)Column(children:[
            Text(_error!,key:const Key('fin15_inbox_error'),
              style:TextStyle(color:scheme.error)),
            TextButton(onPressed:()=>_load(),child:const Text('إعادة المحاولة')),
          ]),
          if(_items.isEmpty&&!_loading&&_error==null)
            const Text('لا توجد طلبات تعديل مسجلة لهذا الحساب.'),
          for(final item in _items)Card(
            key:Key('fin15_amendment_'+item.id),
            child:Padding(padding:const EdgeInsets.all(12),child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(item.isHistorical?'دين سابق':'دين داخل العلاقة',
                  style:Theme.of(context).textTheme.titleMedium),
                Text('الأصلي: '+FinanceDisplay.amount(item.oldAmount)+' '+
                  item.currency.name.toUpperCase()),
                Text('المقترح: '+FinanceDisplay.amount(item.proposedAmount)+' '+
                  item.currency.name.toUpperCase(),
                  style:const TextStyle(fontWeight:FontWeight.bold)),
                Text('السبب: '+item.reason),
                Text(switch(item.status){
                  'accepted'=>'وافق التاجر — إنشاء البديل موثق',
                  'rejected'=>'رفض التاجر — الأصل محفوظ',
                  _=>'بانتظار قرار التاجر'
                },style:TextStyle(color:scheme.onSurfaceVariant)),
                if(item.pending&&widget.forMerchant)
                  Wrap(spacing:8,children:[
                    FilledButton(key:Key('fin15_accept_'+item.id),
                      onPressed:_acting?null:()=>_decide(item,true),
                      child:const Text('قبول التعديل')),
                    OutlinedButton(key:Key('fin15_reject_'+item.id),
                      onPressed:_acting?null:()=>_decide(item,false),
                      child:const Text('رفض التعديل')),
                  ]),
              ],
            )),
          ),
          if(_nextCursor!=null&&!_loading)
            TextButton(key:const Key('fin15_more_amendments'),
              onPressed:()=>_load(more:true),child:const Text('المزيد من الطلبات')),
          if(_loading)const Center(child:Padding(
            padding:EdgeInsets.all(15),child:CircularProgressIndicator())),
        ]),
      ),
    );
  }
}

/// The customer proposes a NEW amount, preserving the original and all
/// server-side independent consent. One stable idempotency key per dialog.
class Fin15AmountProposalDialog extends StatefulWidget {
  const Fin15AmountProposalDialog({super.key,required this.gateway,
    required this.originalAmount,required this.currency,this.claimId,
    this.relationshipId,this.operationId})
    : assert((claimId!=null) != (operationId!=null));
  final Fin15AmendmentGateway gateway;
  final Decimal originalAmount;
  final CurrencyCode currency;
  final String? claimId,relationshipId,operationId;

  @override
  State<Fin15AmountProposalDialog> createState()=>_Fin15AmountProposalDialogState();
}
class _Fin15AmountProposalDialogState extends State<Fin15AmountProposalDialog> {
  String _amount='',_reason='';
  String? _error;
  bool _saving=false;
  late final String _key;
  @override
  void initState(){
    super.initState();
    final random=Random.secure();
    _key='fin15-'+List<int>.generate(20,(_)=>random.nextInt(256))
      .map((n)=>n.toRadixString(16).padLeft(2,'0')).join();
  }
  Future<void> _submit() async{
    if(_saving)return;
    final raw=_amount.trim();
    if(!RegExp(r'^\d{1,16}(?:\.\d{1,4})?$').hasMatch(raw)){
      setState(()=>_error='أدخل مبلغًا صحيحًا بدقة لا تتجاوز أربع منازل.');
      return;
    }
    final value=Decimal.parse(raw);
    if(value<=Decimal.zero || value==widget.originalAmount){
      setState(()=>_error='حدد مبلغًا جديدًا موجبًا ومختلفًا عن القيمة الأصلية.');
      return;
    }
    if(_reason.trim().length<3||_reason.trim().length>500){
      setState(()=>_error='اكتب سبب التعديل بين 3 و500 حرف.');
      return;
    }
    setState((){_saving=true;_error=null;});
    try{
      if(widget.claimId!=null){
        await widget.gateway.proposeHistorical(widget.claimId!,
          amount:value,reason:_reason.trim(),idempotencyKey:_key);
      }else{
        await widget.gateway.proposeOperation(widget.relationshipId!,
          widget.operationId!,amount:value,reason:_reason.trim(),
          idempotencyKey:_key);
      }
      if(mounted)Navigator.of(context).pop(true);
    }catch(e){
      if(mounted)setState(()=>_error=e is Fin08ApiError?e.message:
        'لم نؤكد إرسال التعديل. أعد المحاولة بنفس الطلب.');
    }finally{if(mounted)setState(()=>_saving=false);}
  }
  @override
  Widget build(BuildContext context)=>AlertDialog(
    scrollable:true,title:const Text('طلب تعديل مبلغ الدين'),
    content:Column(mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('المبلغ الأصلي: '+widget.originalAmount.toString()+' '+
          widget.currency.name.toUpperCase()),
        const SizedBox(height:7),
        const Text('سيبقى المبلغ الأصلي محفوظًا، ولا يتغير الرصيد حتى '
          'تكتمل موافقة الطرفين على مبلغ بديل.'),
        TextField(key:const Key('fin15_new_amount'),
          keyboardType:const TextInputType.numberWithOptions(decimal:true),
          onChanged:(s)=>_amount=s,
          decoration:const InputDecoration(labelText:'المبلغ المقترح')),
        TextField(key:const Key('fin15_change_reason'),
          onChanged:(s)=>_reason=s,maxLength:500,
          decoration:const InputDecoration(labelText:'سبب الاعتراض أو التعديل')),
        if(_error!=null)Text(_error!,
          style:TextStyle(color:Theme.of(context).colorScheme.error)),
      ]),
    actions:[
      TextButton(onPressed:_saving?null:()=>Navigator.of(context).pop(false),
        child:const Text('إلغاء')),
      FilledButton(key:const Key('fin15_submit_proposal'),
        onPressed:_saving?null:_submit,
        child:Text(_saving?'جارٍ الإرسال...':'إرسال طلب تعديل')),
    ],
  );
}
