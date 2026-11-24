import 'package:flutter/material.dart';

import '../services/fin08_api_client.dart';

/// A verified customer's relationship inbox, separate from debt claim consent.
/// No navigation to this screen is allowed before real server-side login.
class Fin08CustomerRelationshipsScreen extends StatefulWidget {
  const Fin08CustomerRelationshipsScreen({super.key,required this.gateway,
    this.onOpenLedger});
  final Fin08ClaimsGateway gateway;
  final void Function(Fin08CustomerRelationship relationship)? onOpenLedger;
  @override
  State<Fin08CustomerRelationshipsScreen> createState()=>_Fin08CustomerRelationshipsScreenState();
}

class _Fin08CustomerRelationshipsScreenState extends State<Fin08CustomerRelationshipsScreen> {
  List<Fin08CustomerRelationship> _items=const [];
  String? _cursor;
  String? _error;
  bool _loading=false;
  final Set<String> _deciding={};

  @override
  void initState(){super.initState();_load();}

  Future<void> _load({bool more=false}) async {
    if(_loading)return;
    setState((){_loading=true;_error=null;});
    try{
      final result=await widget.gateway.customerRelationships(cursor:more?_cursor:null);
      if(!mounted)return;
      setState((){
        _items=more?List.unmodifiable([..._items,...result.items]):result.items;
        _cursor=result.nextCursor;
      });
    }catch(e){if(mounted)setState(()=>_error=e is Fin08ApiError?e.message:'تعذر تحميل علاقاتك من الخادم.');}
    finally{if(mounted)setState(()=>_loading=false);}
  }

  Future<void> _decide(Fin08CustomerRelationship relation,bool accept) async {
    if(!relation.canDecide||_deciding.contains(relation.id))return;
    final choice=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(accept?'اعتماد العلاقة مع التاجر؟':'رفض علاقة التاجر؟'),
      content:Text('التاجر: ${relation.merchantName}. '
        'قرار العلاقة مستقل عن كل مطالبة دين. اعتماد العلاقة لا يوافق تلقائياً على أي دين سابق أو جديد.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(key:const Key('fin10_confirm_relationship'),
          onPressed:()=>Navigator.pop(ctx,true),child:Text(accept?'أوافق على العلاقة':'أرفض العلاقة')),
      ],
    ));
    if(choice!=true||!mounted)return;
    setState(()=>_deciding.add(relation.id));
    try{
      final response=await widget.gateway.decideRelationship(relation.id,accept:accept);
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
        response.newlyPostedDebts>0
          ?'اعتمد الخادم العلاقة، ورحّل ${response.newlyPostedDebts} من المطالبات التي وافقت عليها مسبقاً.'
          :accept?'تم اعتماد العلاقة. لم تتم موافقة تلقائية على أي دين.':'تم تسجيل رفض العلاقة.'
      )));
      await _load();
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
        e is Fin08ApiError?e.message:'لم يؤكد الخادم تسجيل قرار العلاقة.')));
    }finally{if(mounted)setState(()=>_deciding.remove(relation.id));}
  }

  @override
  Widget build(BuildContext context){
    final colors=Theme.of(context).colorScheme;
    return Scaffold(
      appBar:AppBar(title:const Text('طلبات الارتباط بالتجار')),
      body:RefreshIndicator(onRefresh:()=>_load(),child:ListView(
        padding:const EdgeInsets.all(16),children:[
          const Text('الموافقة على العلاقة لا تعني الموافقة على ديون التاجر. '
            'راجع كل مطالبة مالية بصورة مستقلة.'),
          const SizedBox(height:16),
          if(_items.isEmpty && _loading)
            const Center(child:CircularProgressIndicator()),
          if(_error!=null)...[
            Text(_error!,key:const Key('fin10_relation_error'),style:TextStyle(color:colors.error)),
            TextButton(onPressed:_loading?null:()=>_load(),child:const Text('إعادة المحاولة')),
          ],
          if(_items.isEmpty && !_loading && _error==null)
            const Text('لا توجد طلبات ارتباط موثقة بانتظار مراجعتك.'),
          for(final item in _items) Card(
            key:Key('fin10_relationship_${item.id}'),
            margin:const EdgeInsets.only(bottom:10),
            child:Padding(padding:const EdgeInsets.all(14),child:Column(
              crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                Text(item.merchantName,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
                Text(switch(item.status){
                  'pending'=>'بانتظار موافقتك على العلاقة',
                  'approved'=>'العلاقة معتمدة',
                  'rejected'=>'العلاقة مرفوضة',
                  _=>'حالة غير معروفة'
                },style:TextStyle(color:colors.onSurfaceVariant)),
                if(item.canDecide)...[
                  const SizedBox(height:10),
                  Row(children:[
                    Expanded(child:FilledButton(key:Key('fin10_accept_${item.id}'),
                      onPressed:_deciding.contains(item.id)?null:()=>_decide(item,true),
                      child:const Text('قبول الارتباط'))),
                    const SizedBox(width:8),
                    Expanded(child:OutlinedButton(key:Key('fin10_reject_${item.id}'),
                      onPressed:_deciding.contains(item.id)?null:()=>_decide(item,false),
                      child:const Text('رفض الارتباط'))),
                  ]),
                ],
                if(item.status=='approved' && widget.onOpenLedger!=null)...[
                  const SizedBox(height:10),
                  OutlinedButton.icon(
                    key:Key('fin13_open_ledger_${item.id}'),
                    onPressed:()=>widget.onOpenLedger!(item),
                    icon:const Icon(Icons.menu_book_outlined),
                    label:const Text('فتح الدفتر')),
                ],
              ],
            )),
          ),
          if(_cursor!=null && !_loading)TextButton(
            key:const Key('fin10_more_relations'),onPressed:()=>_load(more:true),
            child:const Text('عرض علاقات أقدم')),
          if(_loading && _items.isNotEmpty)
            const Center(child:Padding(padding:EdgeInsets.all(8),child:CircularProgressIndicator())),
        ],
      )),
    );
  }
}