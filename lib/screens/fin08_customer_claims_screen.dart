import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import '../services/fin14_batch_gateway.dart';
import '../services/fin15_amendment_gateway.dart';
import 'fin15_amendments_screen.dart';

import '../services/fin08_api_client.dart';
import '../models/app_models.dart';
import 'fin08_customer_relationships_screen.dart';
import '../widgets/finance_display.dart';

/// Server-backed customer inbox for historical merchant debt CLAIMS.
/// Attach only after real authenticated customer login; never from a locally
/// validated phone, PIN or unverified mock account.
class Fin08CustomerClaimsScreen extends StatefulWidget {
  const Fin08CustomerClaimsScreen({super.key, required this.gateway,this.batchGateway,
    this.amendmentGateway});
  final Fin08ClaimsGateway gateway;
  final Fin14BatchGateway? batchGateway;
  final Fin15AmendmentGateway? amendmentGateway;

  @override
  State<Fin08CustomerClaimsScreen> createState() => _Fin08CustomerClaimsScreenState();
}

class _Fin08CustomerClaimsScreenState extends State<Fin08CustomerClaimsScreen> {
  List<Fin08PreviousClaim> _rows = const [];
  String? _cursor;
  String? _failure;
  bool _loading = false;
  final Set<String> _submitting = {};
  final Set<String> _selectedForBatch={};
  bool _batchBusy=false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (_loading) return;
    setState(() { _loading = true; _failure = null; });
    try {
      final page = await widget.gateway.customerPreviousClaims(
        cursor: append ? _cursor : null,
      );
      if (!mounted) return;
      setState(() {
        _rows = append ? List.unmodifiable([..._rows, ...page.items]) : page.items;
        _cursor = page.nextCursor;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _failure = error is Fin08ApiError
          ? error.message : 'تعذر جلب طلبات الديون من الخادم.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _batchDecision(bool accept) async {
    if(widget.batchGateway==null || _batchBusy || _loading ||
        _submitting.isNotEmpty || _selectedForBatch.isEmpty ||
        _selectedForBatch.length>50)return;
    final selected=_rows.where((r)=>r.canReview &&
      _selectedForBatch.contains(r.id)).toList(growable:false);
    if(selected.length!=_selectedForBatch.length){
      setState(()=>_failure='تغيّرت الطلبات المحددة؛ أعد مراجعة العناصر أولاً.');
      return;
    }
    final debtTotals={for(final unit in CurrencyCode.values) unit:Decimal.zero};
    final paymentTotals={for(final unit in CurrencyCode.values) unit:Decimal.zero};
    for(final row in selected){
      final totals=row.type==MovementType.payment?paymentTotals:debtTotals;
      totals[row.currency]=totals[row.currency]!+row.amount;
    }
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(accept?'مراجعة اعتماد العمليات المحددة':'مراجعة رفض العمليات المحددة'),
      content:SizedBox(width:420,child:SingleChildScrollView(child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,
        children:[
          Text('عدد العمليات المختارة: '+selected.length.toString()+
            ' — القرار لا يشمل أي عملية غير مختارة.'),
          const Divider(),
          for(final item in selected)Text(
            item.merchantName+' • '+(item.type==MovementType.debt?'دين':'دفعة')+
            ' • '+item.amount.toString()+' '+item.currency.name.toUpperCase()),
          const Divider(),
          for(final unit in CurrencyCode.values)
            if(debtTotals[unit]!=Decimal.zero||paymentTotals[unit]!=Decimal.zero)
              Text(unit.name.toUpperCase()+' — ديون: '+
                debtTotals[unit].toString()+' / دفعات: '+
                paymentTotals[unit].toString()+' / صافي تقديري غير معتمد: '+
                (debtTotals[unit]!-paymentTotals[unit]!).toString()),
          const SizedBox(height:8),
          const Text('تؤكد هذه العملية القرارات المختارة فقط. لا تنشأ قيود معتمدة قبل اكتمال شروط العلاقة والموافقة.',
            style:TextStyle(fontWeight:FontWeight.w700)),
        ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(key:const Key('fin14_confirm_batch'),
          onPressed:()=>Navigator.pop(ctx,true),child:Text(accept?'اعتماد المحدد':'رفض المحدد')),
      ]));
    if(!mounted||confirmed!=true)return;
    setState(()=>_batchBusy=true);
    try{
      final result=await widget.batchGateway!.decideHistorical({
        for(final row in selected)row.id:accept,
      });
      final ids=result.items.map((x)=>x['id']).toSet();
      if(ids.length!=selected.length ||
         !selected.every((x)=>ids.contains(x.id))) {
        throw const Fin08ApiError('لم يؤكد الخادم جميع القرارات المحددة.',code:'invalid_response');
      }
      if(!mounted)return;
      setState(()=>_selectedForBatch.clear());
      await _load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('أكد الخادم قرارات '+selected.length.toString()+
          ' عملية محددة؛ قيود معتمدة جديدة: '+result.newlyPosted.toString())));
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text(e is Fin08ApiError?e.message:
          'تعذر تأكيد المجموعة؛ لم نؤكد حفظ أي قرار. راجع الحالة ثم أعد المحاولة.')));
    }finally{if(mounted)setState(()=>_batchBusy=false);}
  }

  Future<void> _requestAmendment(Fin08PreviousClaim claim) async {
    if(widget.amendmentGateway==null || !claim.canReview ||
       claim.type!=MovementType.debt || _submitting.isNotEmpty ||
       _batchBusy || _loading)return;
    final saved=await showDialog<bool>(context:context,
      barrierDismissible:false,
      builder:(_)=>Fin15AmountProposalDialog(
        gateway:widget.amendmentGateway!,claimId:claim.id,
        originalAmount:claim.amount,currency:claim.currency));
    if(saved==true && mounted){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('حُفظ اقتراح المبلغ لدى الخادم. لن يُعتمد الأصل حتى يرد التاجر.')));
      await _load();
    }
  }

  Future<void> _decide(Fin08PreviousClaim claim, bool accept) async {
    if (_submitting.contains(claim.id) || !claim.canReview) return;
    final confirmed = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('${accept?'الموافقة':'رفض'} على ${claim.type==MovementType.payment?'هذه الدفعة':'هذا الدين'}؟'),
      content:Text('${claim.type==MovementType.payment?'دفعة':'مطالبة دين'} من ${claim.merchantName} بمبلغ '
        '${FinanceDisplay.amount(claim.amount)} '
        '${FinanceDisplay.currencyCode(claim.currency)}. '
        'يُسجّل قرارك لهذا الطلب وحده. '
        'لا يُعتمد الدين قبل قبول العلاقة وترحيل الحركة لدى الخادم.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(
          key:const Key('fin08_confirm_claim_decision'),
          onPressed:()=>Navigator.pop(ctx,true),
          child:Text(accept?'أوافق على العملية':'أرفض العملية'),
        ),
      ],
    ));
    if (!mounted || confirmed != true) return;
    setState(() => _submitting.add(claim.id));
    try {
      final result = await widget.gateway.decidePreviousClaim(claim.id,accept:accept);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
        result.ledgerPosted ? 'أكد الخادم اعتماد هذه العملية بعد اكتمال الموافقتين.' :
        accept ? 'سُجلت موافقتك على هذا الطلب فقط. قد يلزم إكمال اعتماد العلاقة.' :
        'سُجل رفض هذا الطلب دون أثر على الرصيد المعتمد.',
      )));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
        error is Fin08ApiError ? error.message :
        'لم نؤكد حفظ القرار. راجع الحالة قبل إعادة المحاولة.',
      )));
    } finally {
      if (mounted) setState(() => _submitting.remove(claim.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c=Theme.of(context).colorScheme;
    return Scaffold(
      appBar:AppBar(title:const Text('طلبات الديون السابقة')),
      body:RefreshIndicator(
        onRefresh:()=>_load(),
        child:ListView(
          padding:const EdgeInsets.all(16),
          children:[
            Text('ديون ودفعات سجّلها التجار قبل انضمامك',
              style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),
            const SizedBox(height:6),
            Text('كل طلب مستقل ويظل غير معتمد حتى تكتمل موافقتك '
                'على الدين والعلاقة. لا توجد موافقة جماعية تلقائية.',
                style:TextStyle(color:c.onSurfaceVariant)),
            const SizedBox(height:10),
            OutlinedButton.icon(
              key:const Key('fin10_open_relationships'),
              onPressed:() async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder:(_)=>Fin08CustomerRelationshipsScreen(gateway:widget.gateway)));
                if(mounted)await _load(); // Re-read posting after relationship decision.
              },
              icon:const Icon(Icons.handshake_outlined),
              label:const Text('مراجعة طلبات الارتباط بالتجار'),
            ),
            const SizedBox(height:16),
            if(widget.amendmentGateway!=null) ...[
              OutlinedButton.icon(
                key:const Key('fin15_customer_amendments'),
                icon:const Icon(Icons.edit_note_outlined),
                label:const Text('عرض طلبات تعديل المبالغ'),
                onPressed:_loading?null:() async{
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder:(_)=>Fin15AmendmentsScreen(
                      gateway:widget.amendmentGateway!,forMerchant:false)));
                  if(mounted)await _load();
                },
              ),
              const SizedBox(height:8),
            ],
            if(widget.batchGateway!=null) ...[
              Text('حدد العمليات التي تريد مراجعتها جماعياً — حتى 50 عملية.',
                style:TextStyle(color:c.onSurfaceVariant)),
              if(_selectedForBatch.isNotEmpty)Wrap(spacing:8,children:[
                FilledButton(key:const Key('fin14_batch_accept'),
                  onPressed:_batchBusy?null:()=>_batchDecision(true),
                  child:Text('اعتماد المحدد ('+_selectedForBatch.length.toString()+')')),
                OutlinedButton(key:const Key('fin14_batch_reject'),
                  onPressed:_batchBusy?null:()=>_batchDecision(false),
                  child:const Text('رفض المحدد')),
              ]),
              const SizedBox(height:8),
            ],
            if(_failure!=null) Padding(
              padding:const EdgeInsets.only(bottom:12),
              child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                Text(_failure!,key:const Key('fin08_inbox_error'),style:TextStyle(color:c.error)),
                TextButton(onPressed:_loading?null:()=>_load(),child:const Text('إعادة المحاولة')),
              ]),
            ),
            if(_rows.isEmpty && _loading)
              const Center(child:CircularProgressIndicator())
            else if(_rows.isEmpty && _failure==null)
              const Padding(padding:EdgeInsets.all(25),child:Text('لا توجد مطالبات سابقة لحسابك الموثق.')),
            for(final claim in _rows) Card(
              key:Key('fin08_claim_${claim.id}'),
              margin:const EdgeInsets.only(bottom:10),
              child:Padding(padding:const EdgeInsets.all(13),child:Column(
                crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                  Text(claim.merchantName,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800)),
                  const SizedBox(height:5),
                  Text('${FinanceDisplay.amount(claim.amount)} ${FinanceDisplay.currencyCode(claim.currency)}',
                    style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
                  if(claim.description!=null && claim.description!.isNotEmpty)
                    Text(claim.description!,style:TextStyle(color:c.onSurfaceVariant)),
                  const SizedBox(height:5),
                  Text(claim.stage.labelFor(claim.type),style:TextStyle(
                    color:claim.stage==Fin08Stage.approved?c.primary:c.onSurfaceVariant,
                    fontWeight:FontWeight.w700)),
                  if(claim.canReview && claim.type==MovementType.debt &&
                      widget.amendmentGateway!=null)
                    OutlinedButton.icon(
                      key:Key('fin15_amend_claim_'+claim.id),
                      onPressed:()=>_requestAmendment(claim),
                      icon:const Icon(Icons.edit_outlined),
                      label:const Text('طلب تعديل مبلغ الدين'),
                    ),
                  if(claim.canReview) ...[
                    if(widget.batchGateway!=null)CheckboxListTile(
                      key:Key('fin14_select_'+claim.id),
                      title:const Text('تحديد للمراجعة الجماعية'),
                      value:_selectedForBatch.contains(claim.id),
                      onChanged:_batchBusy?null:(checked){setState((){
                        if(checked==true && _selectedForBatch.length<50){
                          _selectedForBatch.add(claim.id);
                        }else if(checked==false){_selectedForBatch.remove(claim.id);}
                      });},
                    ),
                    const SizedBox(height:12),
                    Row(children:[
                      Expanded(child:FilledButton(
                        key:Key('fin08_accept_${claim.id}'),
                        onPressed:_submitting.contains(claim.id)?null:()=>_decide(claim,true),
                        child:const Text('موافقة'),
                      )),
                      const SizedBox(width:9),
                      Expanded(child:OutlinedButton(
                        key:Key('fin08_reject_${claim.id}'),
                        onPressed:_submitting.contains(claim.id)?null:()=>_decide(claim,false),
                        child:const Text('رفض'),
                      )),
                    ]),
                  ],
                ],
              )),
            ),
            if(_loading && _rows.isNotEmpty)
              const Center(child:Padding(padding:EdgeInsets.all(12),child:CircularProgressIndicator())),
            if(_cursor!=null && !_loading)
              TextButton(
                key:const Key('fin08_load_more'),
                onPressed:()=>_load(append:true),
                child:const Text('عرض مطالبات أقدم'),
              ),
          ],
        ),
      ),
    );
  }
}