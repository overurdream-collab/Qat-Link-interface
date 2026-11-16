import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/fin08_api_client.dart';
import '../services/fin13_ledger_gateway.dart';

/// Authenticated FIN-13 ledger view. Only mount after trusted JWT login;
/// tenant authorization and consent are ALWAYS checked by the server.
class Fin13RelationshipLedgerScreen extends StatefulWidget {
  const Fin13RelationshipLedgerScreen({super.key,required this.gateway,
    required this.relationshipId,required this.actorId,required this.role});
  final Fin13LedgerGateway gateway;
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
    final amount=TextEditingController();
    final description=TextEditingController();
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
            TextField(key:const Key('fin13_amount'),controller:amount,
              keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:const InputDecoration(labelText:'المبلغ')),
            DropdownButton<CurrencyCode>(
              key:const Key('fin13_currency'),value:currency,isExpanded:true,
              onChanged:saving?null:(v){if(v!=null)update(()=>currency=v);},
              items:CurrencyCode.values.map((v)=>DropdownMenuItem(
                value:v,child:Text(v.name.toUpperCase()))).toList()),
            TextField(controller:description,decoration:const InputDecoration(
              labelText:'الوصف (اختياري)')),
            if(failure!=null)Text(failure!,
              style:TextStyle(color:Theme.of(ctx).colorScheme.error)),
          ])),
          actions:[
            TextButton(onPressed:saving?null:()=>Navigator.pop(ctx,false),
              child:const Text('إلغاء')),
            FilledButton(key:const Key('fin13_submit_operation'),onPressed:saving?null:() async{
              final raw=amount.text.trim();
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
                  idempotencyKey:key,description:description.text.trim().isEmpty?
                    null:description.text.trim());
                if(!ctx.mounted)return;
                success=true;
                Navigator.pop(ctx,true);
                if(mounted){
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
                    result.status=='approved'
                     ?'أكد الخادم اعتماد العملية وفق تفويض العميل المسجل.'
                     :'حُفظ الطلب لدى الخادم بانتظار موافقة الطرف الآخر.')));
                }
              }catch(e){if(ctx.mounted)update(()=>failure=_errorText(e));}
              finally{if(!success&&ctx.mounted)update(()=>saving=false);}
            },child:const Text('إرسال الطلب')),
          ],
        )));
    // Keep input controllers alive until the dialog widgets finish unmounting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      amount.dispose();
      description.dispose();
    });
    if(saved==true&&mounted)await _load();
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
    final reason=TextEditingController();
    final key=_newIdempotency();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('طلب عكس قيد معتمد'),
      content:TextField(controller:reason,maxLength:500,
        decoration:const InputDecoration(labelText:'سبب العكس')),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إرسال طلب العكس')),
      ]));
    if(ok!=true || !mounted){
      WidgetsBinding.instance.addPostFrameCallback((_)=>reason.dispose());
      return;
    }
    try{
      await widget.gateway.reverse(widget.relationshipId,movementId,
        reason:reason.text.trim(),idempotencyKey:key);
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('سُجل طلب عكس معلق. لا يتغير الرصيد حتى موافقة الطرف الآخر.')));
        await _load();
      }
    }catch(e){if(mounted)_showError(e);}
    finally{WidgetsBinding.instance.addPostFrameCallback((_)=>reason.dispose());}
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
        const SizedBox(height:18),
        Text('العمليات الجديدة والمعلقة',style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:8),
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
                _=>'معلق — بانتظار موافقة الطرف الآخر'
              },style:TextStyle(color:palette.onSurfaceVariant)),
              if(op.approvalMethod=='delegated_policy')
                const Text('اعتماد آلي بتفويض العميل'),
              if(op.description!=null)Text(op.description!),
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
