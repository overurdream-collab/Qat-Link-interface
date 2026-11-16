import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import '../services/fin08_api_client.dart';
import '../models/app_models.dart';
import 'fin08_customer_relationships_screen.dart';
import '../widgets/finance_display.dart';

/// Server-backed customer inbox for historical merchant debt CLAIMS.
/// Attach only after real authenticated customer login; never from a locally
/// validated phone, PIN or unverified mock account.
class Fin08CustomerClaimsScreen extends StatefulWidget {
  const Fin08CustomerClaimsScreen({super.key, required this.gateway});
  final Fin08ClaimsGateway gateway;

  @override
  State<Fin08CustomerClaimsScreen> createState() => _Fin08CustomerClaimsScreenState();
}

class _Fin08CustomerClaimsScreenState extends State<Fin08CustomerClaimsScreen> {
  List<Fin08PreviousClaim> _rows = const [];
  String? _cursor;
  String? _failure;
  bool _loading = false;
  bool _batchMode = false;
  bool _batchActing = false;
  final Set<String> _selectedClaimIds = {};
  final Set<String> _submitting = {};

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
        if(!append)_selectedClaimIds.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _failure = error is Fin08ApiError
          ? error.message : 'تعذر جلب طلبات الديون من الخادم.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(Fin08PreviousClaim claim, bool accept) async {
    if (_batchActing || _submitting.contains(claim.id) || !claim.canReview) return;
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

  // Every customer-selected claim and subtotal is reviewed before ONE atomic
  // server transaction. Failed batches make no local or authoritative changes.
  Future<void> _decideBatch(bool accept) async {
    if(_batchActing || _selectedClaimIds.isEmpty || _selectedClaimIds.length>50)return;
    final selected=_rows.where((claim)=>
      claim.canReview && _selectedClaimIds.contains(claim.id)).toList();
    if(selected.length!=_selectedClaimIds.length)return;
    selected.sort((a,b)=>a.id.compareTo(b.id));
    final subtotals=<String,Decimal>{};
    for(final claim in selected){
      final key='${claim.type.name}:${claim.currency.name.toUpperCase()}';
      subtotals.update(key,(previous)=>previous+claim.amount,ifAbsent:()=>claim.amount);
    }
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(accept?'اعتماد العمليات المحددة؟':'رفض العمليات المحددة؟'),
      content:SizedBox(width:450,child:SingleChildScrollView(child:Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Text('عدد العمليات المختارة: ${selected.length}. كل قرار مستقل. '
            'الموافقة لا تعتمد العلاقة تلقائياً ولا تدرج المبالغ في الرصيد '
            'المعتمد قبل اكتمال موافقة العلاقة.'),
          const SizedBox(height:10),
          for(final entry in subtotals.entries)
            Text('${entry.key.startsWith('payment:')?'دفعات':'ديون'} '
              '${entry.key.split(':').last}: ${FinanceDisplay.amount(entry.value)}',
              style:const TextStyle(fontWeight:FontWeight.w700)),
          const Divider(),
          for(final claim in selected)
            Padding(padding:const EdgeInsets.symmetric(vertical:5),
              child:Text('${claim.merchantName} — '
                '${claim.type==MovementType.payment?'دفعة':'دين'} '
                '${FinanceDisplay.amount(claim.amount)} '
                '${claim.currency.name.toUpperCase()}'
                '${claim.description?.trim().isNotEmpty==true?' — ${claim.description}':''}')),
          const SizedBox(height:8),
          const Text('لن يؤثر الطلب المرفوض في الرصيد المعتمد، '
            'وأي تعارض في المجموعة يلغي المعاملة بالكامل.'),
        ],
      ))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(
          key:const Key('fin14_confirm_batch_decision'),
          onPressed:()=>Navigator.pop(ctx,true),
          child:Text(accept?'أوافق على المحدد فقط':'أرفض المحدد فقط')),
      ],
    ));
    if(!mounted||confirmed!=true)return;
    setState(()=>_batchActing=true);
    try{
      final receipt=await widget.gateway.decidePreviousClaimsBatch(
        selected.map((claim)=>claim.id).toList(growable:false),accept:accept);
      if(!mounted)return;
      if(receipt.selectedCount!=selected.length){
        throw const Fin08ApiError('لم تتطابق نتيجة المجموعة مع الاختيار.',code:'invalid_response');
      }
      setState((){_selectedClaimIds.clear();_batchMode=false;});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
        'سجل الخادم قرار ${receipt.selectedCount} عملية محددة. '
        '${receipt.postedCount} قيود جديدة معتمدة بعد اكتمال الشروط.')));
      await _load();
    }catch(e){
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
        e is Fin08ApiError?e.message:
        'لم نؤكد حفظ المجموعة. لم نغير أي رصيد محلياً؛ أعد قراءة الطلبات.')));
    }finally{
      if(mounted)setState(()=>_batchActing=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c=Theme.of(context).colorScheme;
    return Scaffold(
      appBar:AppBar(title:const Text('الديون والدفعات السابقة')),
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
            const SizedBox(height:10),
            OutlinedButton.icon(
              key:const Key('fin14_batch_toggle'),
              onPressed:(_loading||_batchActing)?null:(){
                setState((){
                  _batchMode=!_batchMode;
                  _selectedClaimIds.clear();
                });
              },
              icon:Icon(_batchMode?Icons.close:Icons.checklist_outlined),
              label:Text(_batchMode?'إلغاء تحديد العمليات':'تحديد عمليات للموافقة الجماعية'),
            ),
            if(_batchMode) ...[
              const Text('اختر حتى 50 عملية. لا تشمل القائمة سوى الطلبات '
                'التي لم تتخذ قراراً بشأنها.'),
              const SizedBox(height:8),
              Wrap(spacing:8,runSpacing:8,children:[
                FilledButton(
                  key:const Key('fin14_batch_accept'),
                  onPressed:(_selectedClaimIds.isEmpty||_batchActing)?null:()=>_decideBatch(true),
                  child:Text('موافقة على ${_selectedClaimIds.length}')),
                OutlinedButton(
                  key:const Key('fin14_batch_reject'),
                  onPressed:(_selectedClaimIds.isEmpty||_batchActing)?null:()=>_decideBatch(false),
                  child:Text('رفض ${_selectedClaimIds.length}')),
              ]),
            ],
            const SizedBox(height:16),
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
                  if(_batchMode && claim.canReview)
                    CheckboxListTile(
                      key:Key('fin14_select_${claim.id}'),
                      value:_selectedClaimIds.contains(claim.id),
                      title:const Text('تحديد هذه العملية'),
                      controlAffinity:ListTileControlAffinity.leading,
                      onChanged:_batchActing?null:(checked){
                        setState((){
                          if(checked==true && _selectedClaimIds.length<50){
                            _selectedClaimIds.add(claim.id);
                          } else if(checked==false){
                            _selectedClaimIds.remove(claim.id);
                          }
                        });
                      },
                    ),
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
                  if(claim.canReview && !_batchMode) ...[
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