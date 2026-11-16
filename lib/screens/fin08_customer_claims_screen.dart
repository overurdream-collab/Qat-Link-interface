import 'package:flutter/material.dart';

import '../services/fin08_api_client.dart';
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
    if (_submitting.contains(claim.id) || !claim.canReview) return;
    final confirmed = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(accept?'الموافقة على هذا الدين؟':'رفض هذا الدين؟'),
      content:Text('مطالبة من ${claim.merchantName} بمبلغ '
        '${FinanceDisplay.amount(claim.amount)} '
        '${FinanceDisplay.currencyCode(claim.currency)}. '
        'يُسجّل قرارك لهذا الطلب وحده. '
        'لا يُعتمد الدين قبل قبول العلاقة وترحيل الحركة لدى الخادم.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(
          key:const Key('fin08_confirm_claim_decision'),
          onPressed:()=>Navigator.pop(ctx,true),
          child:Text(accept?'أوافق على الدين':'أرفض الدين'),
        ),
      ],
    ));
    if (!mounted || confirmed != true) return;
    setState(() => _submitting.add(claim.id));
    try {
      final result = await widget.gateway.decidePreviousClaim(claim.id,accept:accept);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
        result.ledgerPosted ? 'أكد الخادم اعتماد هذا الدين بعد اكتمال الموافقتين.' :
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
            Text('مطالبات سجّلها التجار قبل انضمامك',
              style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),
            const SizedBox(height:6),
            Text('كل طلب مستقل ويظل غير معتمد حتى تكتمل موافقتك '
                'على الدين والعلاقة. لا توجد موافقة جماعية تلقائية.',
                style:TextStyle(color:c.onSurfaceVariant)),
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
                  Text(claim.merchantName,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800)),
                  const SizedBox(height:5),
                  Text('${FinanceDisplay.amount(claim.amount)} ${FinanceDisplay.currencyCode(claim.currency)}',
                    style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
                  if(claim.description!=null && claim.description!.isNotEmpty)
                    Text(claim.description!,style:TextStyle(color:c.onSurfaceVariant)),
                  const SizedBox(height:5),
                  Text(claim.stage.label,style:TextStyle(
                    color:claim.stage==Fin08Stage.approved?c.primary:c.onSurfaceVariant,
                    fontWeight:FontWeight.w700)),
                  if(claim.canReview) ...[
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