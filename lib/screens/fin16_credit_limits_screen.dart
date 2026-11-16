import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/fin08_api_client.dart';
import '../services/fin16_credit_gateway.dart';

/// Approved balances come from the server. Only mount after verified JWT login.
class Fin16CreditLimitsScreen extends StatefulWidget {
  const Fin16CreditLimitsScreen({super.key,required this.gateway,
    required this.relationshipId,required this.merchantCanEdit});
  final Fin16CreditGateway gateway;
  final String relationshipId;
  final bool merchantCanEdit;
  @override
  State<Fin16CreditLimitsScreen> createState()=>_Fin16CreditLimitsScreenState();
}

class _Fin16CreditLimitsScreenState extends State<Fin16CreditLimitsScreen>{
  CurrencyCode _selected=CurrencyCode.yer;
  Fin16CreditSnapshot? _snapshot;
  bool _loading=false,_saving=false;
  String? _failure;

  @override
  void initState(){super.initState();_load();}
  String _message(Object e)=>e is Fin08ApiError?e.message:
    'تعذر التحقق من بيانات الحد الائتماني عبر الخادم.';

  Future<void> _load() async{
    if(_loading)return;
    setState((){_loading=true;_failure=null;});
    try{
      final snapshot=await widget.gateway.read(widget.relationshipId);
      if(snapshot.relationshipId!=widget.relationshipId){
        throw const FormatException('Credit exposure belongs to another relationship');
      }
      if(mounted)setState(()=>_snapshot=snapshot);
    }catch(e){
      if(mounted)setState(()=>_failure=_message(e));
    }finally{
      if(mounted)setState(()=>_loading=false);
    }
  }

  Future<void> _configure() async{
    if(_saving||_loading||!widget.merchantCanEdit)return;
    final current=_snapshot?.forCurrency(_selected);
    var mode=current?.enabled==true?current!.mode!:'warn';
    var text=current?.limitAmount?.toString()??'';
    String? failure;
    bool working=false;
    final chosen=_selected;
    final applied=await showDialog<bool>(context:context,barrierDismissible:false,
      builder:(dialogContext)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
        title:Text('حد الائتمان — ${chosen.name.toUpperCase()}'),
        content:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            const Text('الحد على الرصيد المعتمد مع الدين الجديد فقط. '
              'الديون والدفعات المعلقة ظاهرة منفصلة. المنع لا يلغي عمليات سابقة.'),
            const SizedBox(height:10),
            TextFormField(
              key:const Key('fin16_limit_amount'),initialValue:text,
              onChanged:(v)=>text=v,
              decoration:const InputDecoration(labelText:'الحد الائتماني'),
              keyboardType:const TextInputType.numberWithOptions(decimal:true)),
            const SizedBox(height:8),
            DropdownButton<String>(
              key:const Key('fin16_limit_mode'),
              value:mode,isExpanded:true,
              items:const [
                DropdownMenuItem(value:'warn',child:Text('تنبيه فقط')),
                DropdownMenuItem(value:'block',child:Text('منع إنشاء دين جديد')),
              ],
              onChanged:working?null:(next){if(next!=null)refresh(()=>mode=next);}),
            if(failure!=null)
              Text(failure!,style:TextStyle(color:Theme.of(ctx).colorScheme.error)),
          ],
        )),
        actions:[
          TextButton(onPressed:working?null:()=>Navigator.pop(ctx,false),
            child:const Text('إلغاء')),
          FilledButton(
            key:const Key('fin16_confirm_limit'),
            onPressed:working?null:() async{
              final raw=text.trim();
              if(!RegExp(r'^\d{1,16}(?:\.\d{1,4})?$').hasMatch(raw)){
                refresh(()=>failure='الحد رقم غير سالب بحد أقصى 4 منازل عشرية.');
                return;
              }
              refresh((){working=true;failure=null;});
              try{
                await widget.gateway.set(widget.relationshipId,chosen,
                  enabled:true,limitAmount:Decimal.parse(raw),mode:mode);
                if(ctx.mounted)Navigator.pop(ctx,true);
              }catch(e){
                if(ctx.mounted)refresh(()=>failure=_message(e));
              }finally{
                if(ctx.mounted)refresh(()=>working=false);
              }
            },
            child:const Text('حفظ السياسة')),
        ],
      )));
    if(applied==true&&mounted)await _load();
  }

  Future<void> _disable() async{
    if(_saving||_loading||!widget.merchantCanEdit)return;
    final chosen=_selected;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('إيقاف حد هذه العملة؟'),
      content:Text('يُعطّل الحد لـ ${chosen.name.toUpperCase()} فقط. '
        'الديون السابقة والمعتمدة والمعلقة لا تتغير.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(
          key:const Key('fin16_confirm_disable'),
          onPressed:()=>Navigator.pop(ctx,true),
          child:const Text('إيقاف الحد')),
      ]));
    if(yes!=true||!mounted)return;
    setState(()=>_saving=true);
    try{
      await widget.gateway.set(widget.relationshipId,chosen,enabled:false);
      if(mounted)await _load();
    }catch(e){
      if(mounted)setState(()=>_failure=_message(e));
    }finally{
      if(mounted)setState(()=>_saving=false);
    }
  }

  @override
  Widget build(BuildContext context){
    final color=Theme.of(context).colorScheme;
    final active=_snapshot?.forCurrency(_selected);
    return Scaffold(
      appBar:AppBar(title:const Text('الحدود الائتمانية والمخاطر'),
        actions:[IconButton(icon:const Icon(Icons.refresh),tooltip:'تحديث من الخادم',
          onPressed:_loading?null:_load)]),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Text('الرصيد المعتمد والمخاطر المعلقة منفصلان في كل عملة؛ '
          'لا تجمع هذه الشاشة العملات ولا تعتبر المعلقات ديوناً مؤكدة.',
          style:TextStyle(color:color.onSurfaceVariant)),
        const SizedBox(height:12),
        Wrap(spacing:8,children:[
          for(final unit in CurrencyCode.values)ChoiceChip(
            key:Key('fin16_currency_${unit.name}'),
            label:Text(unit.name.toUpperCase()),selected:_selected==unit,
            onSelected:(_)=>setState(()=>_selected=unit)),
        ]),
        const SizedBox(height:12),
        if(active!=null) ...[
          Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('الرصيد المعتمد — ${_selected.name.toUpperCase()}'),
              const SizedBox(height:3),
              Text(active.approvedBalance.toString(),
                key:const Key('fin16_approved_balance'),
                style:Theme.of(context).textTheme.headlineMedium),
              if(active.approvedBalance<Decimal.zero)
                const Text('رصيد دائن لصالح العميل'),
              const Divider(),
              Text(active.enabled
                ?'الحد: ${active.limitAmount} • ${active.mode=='block'?'منع':'تنبيه'}'
                :'لا يوجد حد ائتماني مُفعّل لهذه العملة',
                key:const Key('fin16_limit_status')),
              if(active.enabled)Text('المتاح من الرصيد المعتمد: '
                '${(active.limitAmount!-active.approvedBalance)}'),
              if(active.approvedExceedsLimit)
                Text('تنبيه: الرصيد المعتمد أعلى من الحد الحالي.',
                  style:TextStyle(color:color.error,fontWeight:FontWeight.w700)),
            ],
          ))),
          const SizedBox(height:8),
          Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('مخاطر إضافية غير معتمدة',
                style:TextStyle(fontWeight:FontWeight.w800)),
              Text('ديون معلقة: ${active.pendingDebts}',
                key:const Key('fin16_pending_debts')),
              Text('دفعات معلقة: ${active.pendingPayments}',
                key:const Key('fin16_pending_payments')),
              Text('صافي تقديري فقط: ${active.pendingNetEstimate}'),
              const Text('هذه المبالغ لا تدخل الرصيد المشترك المعتمد.'),
            ],
          ))),
          if(widget.merchantCanEdit) ...[
            const SizedBox(height:10),
            FilledButton.icon(key:const Key('fin16_edit_credit'),
              onPressed:_saving||_loading?null:_configure,
              icon:const Icon(Icons.tune_outlined),
              label:Text(active.enabled?'تعديل الحد':'تفعيل حد ائتماني')),
            if(active.enabled)
              OutlinedButton.icon(key:const Key('fin16_disable_credit'),
                onPressed:_saving||_loading?null:_disable,
                icon:const Icon(Icons.cancel_outlined),
                label:const Text('إيقاف حد هذه العملة')),
          ],
        ],
        if(_failure!=null)...[
          const SizedBox(height:12),
          Text(_failure!,key:const Key('fin16_credit_error'),
            style:TextStyle(color:color.error)),
          TextButton(onPressed:_loading?null:_load,child:const Text('إعادة المحاولة')),
        ],
        if(_loading)const Center(child:Padding(padding:EdgeInsets.all(20),
          child:CircularProgressIndicator())),
      ]),
    );
  }
}
