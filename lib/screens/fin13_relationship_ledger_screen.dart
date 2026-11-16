import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/fin08_api_client.dart';
import '../services/fin13_ledger_gateway.dart';
import '../services/fin14_batch_gateway.dart';
import '../services/fin15_amendment_gateway.dart';
import '../services/fin16_credit_gateway.dart';
import 'fin16_credit_limits_screen.dart';
import 'fin15_amendments_screen.dart';

/// Authenticated FIN-13 ledger view. Only mount after trusted JWT login;
/// tenant authorization and consent are ALWAYS checked by the server.
class Fin13RelationshipLedgerScreen extends StatefulWidget {
  const Fin13RelationshipLedgerScreen({super.key,required this.gateway,
    required this.relationshipId,required this.actorId,required this.role,
    this.batchGateway,this.amendmentGateway,this.creditGateway});
  final Fin13LedgerGateway gateway;
  final Fin14BatchGateway? batchGateway;
  final Fin15AmendmentGateway? amendmentGateway;
  final Fin16CreditGateway? creditGateway;
  final String relationshipId,actorId;
  final ParticipantRole role;
  @override
  State<Fin13RelationshipLedgerScreen> createState()=>_Fin13RelationshipLedgerScreenState();
}

class _Fin13RelationshipLedgerScreenState extends State<Fin13RelationshipLedgerScreen> {
  CurrencyCode _currency=CurrencyCode.yer;
  Fin13Balances? _balances;
  Fin13Policy? _policy;
  List<Fin13Operation> _operations=const [];
  String? _cursor,_error;
  bool _loading=false,_acting=false;
  final Set<String> _selectedForBatch={};

  @override
  void initState(){super.initState();_load();}

  String _errorText(Object e)=>e is Fin08ApiError?e.message:
    'لم تتأكد قراءة البيانات من الخادم. تحقق من الاتصال ثم أعد المحاولة.';

  Future<void> _load({bool more=false}) async {
    if(_loading)return;
    setState((){_loading=true;_error=null;});
    try {
      if(more){
        if(_cursor==null)return;
        final page=await widget.gateway.operations(widget.relationshipId,cursor:_cursor);
        if(!mounted)return;
        setState((){
          _operations=List.unmodifiable([..._operations,...page.items]);
          _cursor=page.nextCursor;
        });
      }else{
        // All three reads must succeed before displaying a fresh snapshot.
        final balances=await widget.gateway.balances(widget.relationshipId);
        final policy=await widget.gateway.policy(widget.relationshipId);
        final page=await widget.gateway.operations(widget.relationshipId);
        if(!mounted)return;
        setState((){
          _balances=balances;_policy=policy;
          _operations=page.items;_cursor=page.nextCursor;
        });
      }
    }catch(e){if(mounted)setState(()=>_error=_errorText(e));}
    finally{if(mounted)setState(()=>_loading=false);}
  }

  String _newIdempotency(){
    final r=Random.secure();
    return 'fin13-'+List<int>.generate(20,(_)=>r.nextInt(256))
      .map((b)=>b.toRadixString(16).padLeft(2,'0')).join();
  }

  Future<void> _newOperation(MovementType kind) async {
    if(_acting)return;
    var amountText='';
    var descriptionText='';
    final key=_newIdempotency(); // stable for retries within this dialog
    CurrencyCode currency=_currency;
    var saving=false;
    String? failure;
    final saved=await showDialog<bool>(context:context,barrierDismissible:false,
      builder:(dialogContext)=>StatefulBuilder(
        builder:(ctx,update)=>AlertDialog(
          title:Text(kind==MovementType.debt?'طلب تسجيل دين':'تسجيل دفعة'),
          content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
            Text(kind==MovementType.debt
              ?'لا يزيد الدين الرصيد المعتمد قبل موافقة العميل أو سريان تفويضه للديون الجديدة.'
              :'لا تنقص الدفعة الرصيد المعتمد قبل موافقة الطرف الآخر.'),
            const SizedBox(height:12),
            TextField(key:const Key('fin13_amount'),onChanged:(value)=>amountText=value,
              keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:const InputDecoration(labelText:'المبلغ')),
            DropdownButton<CurrencyCode>(
              key:const Key('fin13_currency'),value:currency,isExpanded:true,
              onChanged:saving?null:(v){if(v!=null)update(()=>currency=v);},
              items:CurrencyCode.values.map((v)=>DropdownMenuItem(
                value:v,child:Text(v.name.toUpperCase()))).toList()),
            TextField(onChanged:(value)=>descriptionText=value,decoration:const InputDecoration(
              labelText:'الوصف (اختياري)')),
            if(failure!=null)Text(failure!,
              style:TextStyle(color:Theme.of(ctx).colorScheme.error)),
          ])),
          actions:[
            TextButton(onPressed:saving?null:()=>Navigator.pop(ctx,false),
              child:const Text('إلغاء')),
            FilledButton(key:const Key('fin13_submit_operation'),onPressed:saving?null:() async{
              final raw=amountText.trim();
              if(!RegExp(r'^\d{1,16}(?:\.\d{1,4})?$').hasMatch(raw) ||
                  Decimal.parse(raw)<=Decimal.zero){
                update(()=>failure='المبلغ يجب أن يكون موجباً وبدقة لا تتجاوز 4 منازل.');
                return;
              }
              update((){saving=true;failure=null;});
              var success=false;
              try {
                final result=await widget.gateway.create(widget.relationshipId,
                  type:kind,amount:Decimal.parse(raw),currency:currency,
                  idempotencyKey:key,description:descriptionText.trim().isEmpty?
                    null:descriptionText.trim());
                if(!ctx.mounted)return;
                success=true;
                Navigator.pop(ctx,true);
                if(mounted){
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
                    result.creditWarning!=null
                      ?'تنبيه ائتماني: الرصيد المتوقع ${result.creditWarning!.projected} ${result.creditWarning!.currency.name.toUpperCase()} يتجاوز الحد ${result.creditWarning!.limit}. العملية محفوظة وفق سياسة التنبيه.'
                      : result.status=='approved'
                        ?'أكد الخادم اعتماد العملية وفق تفويض العميل المسجل.'
                        :'حُفظ الطلب لدى الخادم بانتظار موافقة الطرف الآخر.')));
                }
              }catch(e){if(ctx.mounted)update(()=>failure=_errorText(e));}
              finally{if(!success&&ctx.mounted)update(()=>saving=false);}
            },child:const Text('إرسال الطلب')),
          ],
        )));
    if(saved==true&&mounted)await _load();
  }

  Future<void> _proposeDebtChange(Fin13Operation operation) async {
    if(widget.amendmentGateway==null ||
       widget.role!=ParticipantRole.customer ||
       operation.type!=MovementType.debt || !operation.pending ||
       operation.createdBy==widget.actorId || _acting || _loading)return;
    final saved=await showDialog<bool>(context:context,
      barrierDismissible:false,
      builder:(_)=>Fin15AmountProposalDialog(
        gateway:widget.amendmentGateway!,
        relationshipId:widget.relationshipId,operationId:operation.id,
        originalAmount:operation.amount,currency:operation.currency));
    if(saved==true && mounted){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('سُجل طلب تعديل مبلغ الدين، وينتظر قرار التاجر.')));
      await _load();
    }
  }

  Future<void> _decide(Fin13Operation operation,bool accept) async {
    if(_acting || !operation.pending || operation.createdBy==widget.actorId)return;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(accept?'اعتماد العملية؟':'رفض العملية؟'),
      content:Text((operation.type==MovementType.debt?'دين':'دفعة')+' بقيمة '+
        operation.amount.toString()+' '+operation.currency.name.toUpperCase()+
        '. قرارك يخص هذه العملية وحدها.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(key:const Key('fin13_confirm_decision'),
          onPressed:()=>Navigator.pop(ctx,true),child:Text(accept?'أوافق':'أرفض')),
      ]));
    if(!mounted||yes!=true)return;
    setState(()=>_acting=true);
    try{
      final result=await widget.gateway.decide(widget.relationshipId,operation.id,accept:accept);
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
        result.posted?'اعتمد الخادم القيد المالي مرة واحدة.':
          accept?'سُجل القرار لدى الخادم.':'رفض الطلب دون أثر مالي.')));
      await _load();
    }catch(e){if(mounted)_showError(e);}
    finally{if(mounted)setState(()=>_acting=false);}
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(_errorText(error))));
  }

  Future<void> _batchDecide(bool accept) async {
    if(widget.batchGateway==null || _acting || _loading ||
       _selectedForBatch.isEmpty || _selectedForBatch.length>50)return;
    final eligible=_operations.where((x)=>x.pending &&
      x.createdBy!=widget.actorId && _selectedForBatch.contains(x.id))
      .toList(growable:false);
    if(eligible.length!=_selectedForBatch.length) {
      _showError(const Fin08ApiError('تغيّرت صلاحيات الطلبات. حدّث القائمة ثم أعد التحديد.'));
      return;
    }
    final debt={for(final currency in CurrencyCode.values)currency:Decimal.zero};
    final payment={for(final currency in CurrencyCode.values)currency:Decimal.zero};
    for(final op in eligible){
      final bucket=op.type==MovementType.payment?payment:debt;
      bucket[op.currency]=bucket[op.currency]!+op.amount;
    }
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(accept?'اعتماد العمليات المحددة؟':'رفض العمليات المحددة؟'),
      content:SizedBox(width:420,child:SingleChildScrollView(child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,
        children:[
          Text('عدد الطلبات التي اخترتها: '+eligible.length.toString()),
          const Divider(),
          for(final op in eligible)Text(
            (op.type==MovementType.debt?'دين':'دفعة')+' — '+
            op.amount.toString()+' '+op.currency.name.toUpperCase()),
          const Divider(),
          for(final unit in CurrencyCode.values)
            if(debt[unit]!=Decimal.zero || payment[unit]!=Decimal.zero)
              Text(unit.name.toUpperCase()+' | ديون: '+debt[unit].toString()+
                ' | دفعات: '+payment[unit].toString()+
                ' | صافي تقديري غير معتمد: '+
                (debt[unit]!-payment[unit]!).toString()),
          const SizedBox(height:8),
          const Text('القرار يخص العناصر المحددة فقط. لا يدخل الرصيد المعتمد قبل تأكيد الخادم.',
            style:TextStyle(fontWeight:FontWeight.w600)),
        ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(key:const Key('fin14_confirm_operation_batch'),
          onPressed:()=>Navigator.pop(ctx,true),
          child:Text(accept?'اعتماد المحدد':'رفض المحدد')),
      ]));
    if(!mounted || yes!=true)return;
    setState(()=>_acting=true);
    try{
      final result=await widget.batchGateway!.decideRelationship(widget.relationshipId,{
        for(final op in eligible)op.id:accept,
      });
      final returned=result.items.map((x)=>x['id']).toSet();
      if(result.scope!='selected_relationship_operations_only' ||
        returned.length!=eligible.length ||
        !eligible.every((x)=>returned.contains(x.id))) {
        throw const Fin08ApiError('لم يؤكد الخادم قرارات كل العناصر المحددة.',code:'invalid_response');
      }
      if(!mounted)return;
      setState(()=>_selectedForBatch.clear());
      await _load();
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
          'حفظ الخادم قرارات '+eligible.length.toString()+
          ' طلبات محددة؛ قيود معتمدة جديدة: '+result.newlyPosted.toString())));
      }
    }catch(e){if(mounted)_showError(e);}
    finally{if(mounted)setState(()=>_acting=false);}
  }

  Future<void> _setAuto(bool enabled) async {
    if(widget.role!=ParticipantRole.customer||_acting)return;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(enabled?'تفويض اعتماد الديون الجديدة؟':'إيقاف التفويض التلقائي؟'),
      content:Text(enabled?
        'يسري التفويض على ديون هذا التاجر الجديدة فقط. لا يشمل الديون السابقة أو الدفعات أو التصحيحات. ويمكنك إيقافه لاحقاً.'
        :'الديون الجديدة بعد إيقاف التفويض تتطلب موافقتك اليدوية. لا تُلغى القيود المعتمدة سابقاً.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(key:const Key('fin13_confirm_policy'),
          onPressed:()=>Navigator.pop(ctx,true),child:const Text('تأكيد')),
      ]));
    if(!mounted||yes!=true)return;
    setState(()=>_acting=true);
    try{
      final policy=await widget.gateway.setPolicy(widget.relationshipId,enabled:enabled);
      if(!mounted)return;
      setState(()=>_policy=policy);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
        policy.enabled?'فُعّل التفويض للديون المستقبلية فقط.':'أوقف الخادم التفويض.')));
    }catch(e){if(mounted)_showError(e);}
    finally{if(mounted)setState(()=>_acting=false);}
  }

  String _day(DateTime date)=>date.year.toString().padLeft(4,'0')+'-'+
    date.month.toString().padLeft(2,'0')+'-'+date.day.toString().padLeft(2,'0');

  Future<void> _statement() async {
    final now=DateTime.now();
    final range=await showDateRangePicker(context:context,
      firstDate:DateTime(2020),lastDate:now.add(const Duration(days:1)),
      initialDateRange:DateTimeRange(start:DateTime(now.year,now.month,1),end:now));
    if(range==null||!mounted)return;
    setState(()=>_acting=true);
    try{
      final result=await widget.gateway.statement(widget.relationshipId,_currency,
        _day(range.start),_day(range.end));
      if(!mounted)return;
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('كشف معتمد من الخادم'),
        content:SizedBox(width:420,child:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('العملة: '+result.currency.name.toUpperCase()),
            Text('الرصيد الافتتاحي: '+result.openingBalance.toString()),
            Text('الديون المعتمدة: '+result.approvedDebts.toString()),
            Text('الدفعات المعتمدة: '+result.approvedPayments.toString()),
            Text('الرصيد الختامي: '+result.closingBalance.toString()),
            const Divider(),
            for(final e in result.entries)
              ListTile(dense:true,title:Text(
                (e.type==MovementType.debt?'دين':'دفعة')+' • '+e.amount.toString()),
                subtitle:Text('تاريخ الاعتماد: '+e.postedAt.toLocal().toString()),
                trailing:IconButton(icon:const Icon(Icons.undo_outlined),
                  tooltip:'طلب عكس موثق',onPressed:()=>_requestReversal(e.id)),
              ),
          ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))],
      ));
    }catch(e){if(mounted)_showError(e);}
    finally{if(mounted)setState(()=>_acting=false);}
  }

  Future<void> _requestReversal(String movementId) async {
    // No immediate posting: request becomes pending until the other approves.
    var reasonText='';
    final key=_newIdempotency();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('طلب عكس قيد معتمد'),
      content:TextField(onChanged:(value)=>reasonText=value,maxLength:500,
        decoration:const InputDecoration(labelText:'سبب العكس')),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إرسال طلب العكس')),
      ]));
    if(ok!=true || !mounted)return;
    try{
      await widget.gateway.reverse(widget.relationshipId,movementId,
        reason:reasonText.trim(),idempotencyKey:key);
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('سُجل طلب عكس معلق. لا يتغير الرصيد حتى موافقة الطرف الآخر.')));
        await _load();
      }
    }catch(e){if(mounted)_showError(e);}

  }

  @override
  Widget build(BuildContext context){
    final palette=Theme.of(context).colorScheme;
    final balance=_balances?.forCurrency(_currency);
    return Scaffold(
      appBar:AppBar(title:const Text('الدفتر المالي المشترك'),
        actions:[IconButton(onPressed:_loading?null:()=>_load(),
          tooltip:'تحديث من الخادم',icon:const Icon(Icons.refresh))]),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Text('الأرصدة المعتمدة فقط؛ لا تدخل المعلقات في الرصيد.',
          style:TextStyle(color:palette.onSurfaceVariant)),
        const SizedBox(height:12),
        Wrap(spacing:8,children:[
          for(final unit in CurrencyCode.values)
            ChoiceChip(key:Key('fin13_currency_'+unit.name),
              label:Text(unit.name.toUpperCase()),selected:_currency==unit,
              onSelected:(_)=>setState(()=>_currency=unit)),
        ]),
        const SizedBox(height:10),
        if(balance!=null) Card(child:Padding(padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(balance.net<Decimal.zero?'رصيد دائن لصالح العميل':'الرصيد المعتمد',
              style:TextStyle(color:palette.onSurfaceVariant)),
            Text(balance.net.toString()+' '+_currency.name.toUpperCase(),
              key:const Key('fin13_approved_net'),
              style:Theme.of(context).textTheme.headlineMedium),
            Text('ديون معتمدة: '+balance.approvedDebts.toString()),
            Text('دفعات معتمدة: '+balance.approvedPayments.toString()),
          ]))),
        if(widget.role==ParticipantRole.customer && _policy!=null)
          SwitchListTile(key:const Key('fin13_auto_policy'),
            value:_policy!.enabled,onChanged:_acting?null:_setAuto,
            title:const Text('اعتماد ديون هذا التاجر الجديدة تلقائياً'),
            subtitle:const Text('مغلق افتراضياً؛ لا يشمل القديم أو الدفعات أو العكس.')),
        const SizedBox(height:8),
        Wrap(spacing:8,runSpacing:8,children:[
          if(widget.role==ParticipantRole.merchant)
            FilledButton.icon(key:const Key('fin13_new_debt'),
              onPressed:_acting?null:()=>_newOperation(MovementType.debt),
              icon:const Icon(Icons.add),label:const Text('طلب دين')),
          FilledButton.icon(key:const Key('fin13_new_payment'),
            onPressed:_acting?null:()=>_newOperation(MovementType.payment),
            icon:const Icon(Icons.payments_outlined),label:const Text('تسجيل دفعة')),
          OutlinedButton.icon(key:const Key('fin13_open_statement'),
            onPressed:_acting?null:_statement,
            icon:const Icon(Icons.receipt_long_outlined),
            label:const Text('كشف الحساب المعتمد')),
        ]),
        if(widget.creditGateway!=null) ...[
          const SizedBox(height:9),
          OutlinedButton.icon(
            key:const Key('fin16_open_credit_limits'),
            onPressed:_loading||_acting?null:() async{
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder:(_)=>Fin16CreditLimitsScreen(
                  gateway:widget.creditGateway!,
                  relationshipId:widget.relationshipId,
                  merchantCanEdit:widget.role==ParticipantRole.merchant)));
              if(mounted)await _load();
            },
            icon:const Icon(Icons.account_balance_wallet_outlined),
            label:const Text('حدود الائتمان والمخاطر المعلقة'),
          ),
        ],
        if(widget.amendmentGateway!=null) ...[
          const SizedBox(height:9),
          OutlinedButton.icon(
            key:const Key('fin15_relationship_amendments'),
            onPressed:_loading?null:() async{
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder:(_)=>Fin15AmendmentsScreen(
                  gateway:widget.amendmentGateway!,
                  forMerchant:widget.role==ParticipantRole.merchant)));
              if(mounted)await _load();
            },
            icon:const Icon(Icons.edit_note_outlined),
            label:const Text('طلبات تعديل مبالغ الديون'),
          ),
        ],
        const SizedBox(height:18),
        Text('العمليات الجديدة والمعلقة',style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:8),
        if(widget.batchGateway!=null) ...[
          Text('حدد عمليات الطرف الآخر المراد اتخاذ قرار جماعي بشأنها. الحد 50.',
            style:TextStyle(color:palette.onSurfaceVariant)),
          if(_selectedForBatch.isNotEmpty)Wrap(spacing:8,children:[
            FilledButton(key:const Key('fin14_operation_batch_accept'),
              onPressed:_acting?null:()=>_batchDecide(true),
              child:Text('اعتماد المحدد ('+_selectedForBatch.length.toString()+')')),
            OutlinedButton(key:const Key('fin14_operation_batch_reject'),
              onPressed:_acting?null:()=>_batchDecide(false),
              child:const Text('رفض المحدد')),
          ]),
          const SizedBox(height:8),
        ],
        if(_operations.isEmpty && !_loading && _error==null)
          const Text('لا توجد عمليات جديدة في هذه العلاقة.'),
        for(final op in _operations.where((x)=>x.currency==_currency)) Card(
          key:Key('fin13_operation_'+op.id),
          child:Padding(padding:const EdgeInsets.all(12),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text((op.type==MovementType.debt?'دين':'دفعة')+' — '+
                op.amount.toString()+' '+op.currency.name.toUpperCase(),
                style:const TextStyle(fontWeight:FontWeight.w700)),
              Text(switch(op.status){
                'approved'=>'معتمد',
                'rejected'=>'مرفوض',
                'superseded'=>'سجل أصلي مستبدل — لا يدخل الرصيد',
                _=>op.amendmentPending?'بانتظار رد التاجر على تعديل المبلغ':'معلق — بانتظار موافقة الطرف الآخر'
              },style:TextStyle(color:palette.onSurfaceVariant)),
              if(op.approvalMethod=='delegated_policy')
                const Text('اعتماد آلي بتفويض العميل'),
              if(op.description!=null)Text(op.description!),
              if(widget.amendmentGateway!=null &&
                 widget.role==ParticipantRole.customer &&
                 op.pending && op.type==MovementType.debt &&
                 op.createdBy!=widget.actorId)
                OutlinedButton.icon(
                  key:Key('fin15_amend_operation_'+op.id),
                  icon:const Icon(Icons.edit_outlined),
                  onPressed:()=>_proposeDebtChange(op),
                  label:const Text('طلب تعديل المبلغ'),
                ),
              if(op.pending && op.createdBy!=widget.actorId && widget.batchGateway!=null)
                CheckboxListTile(
                  key:Key('fin14_select_operation_'+op.id),
                  title:const Text('تحديد للمراجعة الجماعية'),
                  value:_selectedForBatch.contains(op.id),
                  onChanged:_acting?null:(checked){setState((){
                    if(checked==true&&_selectedForBatch.length<50){
                      _selectedForBatch.add(op.id);
                    }else if(checked==false){_selectedForBatch.remove(op.id);}
                  });},
                ),
              if(op.pending && op.createdBy!=widget.actorId && !_acting)
                Row(children:[
                  TextButton(onPressed:()=>_decide(op,true),child:const Text('موافقة')),
                  TextButton(onPressed:()=>_decide(op,false),child:const Text('رفض')),
                ]),
            ],
          )),
        ),
        if(_cursor!=null&&!_loading)
          TextButton(key:const Key('fin13_load_more'),
            onPressed:()=>_load(more:true),child:const Text('المزيد من العمليات')),
        if(_error!=null)Column(children:[
          Text(_error!,style:TextStyle(color:palette.error),
            key:const Key('fin13_ledger_error')),
          TextButton(onPressed:()=>_load(),child:const Text('إعادة المحاولة')),
        ]),
        if(_loading)const Center(child:Padding(padding:EdgeInsets.all(14),
          child:CircularProgressIndicator())),
      ]),
    );
  }
}
