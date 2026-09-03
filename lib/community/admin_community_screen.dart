import 'dart:convert';
import 'package:falora/ai_config.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminCommunityScreen extends StatefulWidget {
  const AdminCommunityScreen({super.key});
  @override State<AdminCommunityScreen> createState() => _AdminCommunityState();
}

class _AdminCommunityState extends State<AdminCommunityScreen> {
  Map<String, dynamic>? overview;
  List<dynamic> topics = [], reports = [], categories = [];
  bool loading = true;

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await http.get(Uri.parse('$apiBaseUrl$path'), headers: await BackendAuthClient.authHeaders());
    final data = _decode(response);
    if (response.statusCode >= 300) throw Exception(data['error']);
    return data;
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$apiBaseUrl$path'), headers: await BackendAuthClient.authHeaders(), body: jsonEncode(body));
    final data = _decode(response);
    if (response.statusCode >= 300) throw Exception(data['error']);
  }

  Map<String, dynamic> _decode(http.Response response) {
    try { return jsonDecode(response.body) as Map<String, dynamic>; }
    on FormatException { throw Exception('Fal Meclisi backend sürümü henüz Railway üzerinde yayında değil.'); }
  }

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await Future.wait([
        _get('/admin/community/overview'), _get('/admin/community/topics?limit=50'),
        _get('/admin/community/reports?status=open&limit=50'), _get('/community/categories'),
      ]);
      if (!mounted) return;
      setState(() { overview=data[0]; topics=data[1]['items']??[]; reports=data[2]['items']??[]; categories=data[3]['items']??[]; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => loading=false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fal Meclisi Yönetimi'), actions: [
      IconButton(tooltip: 'Test üyeliği ver', icon: const Icon(Icons.key_outlined), onPressed: _grantTestAccess),
      IconButton(tooltip: 'Kategoriler', icon: const Icon(Icons.category_outlined), onPressed: _showCategories),
      IconButton(tooltip: 'Süresi dolanları temizle', icon: const Icon(Icons.cleaning_services_outlined), onPressed: () async { await _post('/admin/community/cleanup', {}); _load(); }),
    ]),
    body: FaloraBackground(child: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          _metric('Aktif konu', overview?['activeTopics']), _metric('Açık rapor', overview?['openReports']),
          _metric('Bekleyen', overview?['pendingModeration']), _metric('Kategori', overview?['totalCategories']),
        ]),
        const SizedBox(height: 20), Text('Açık Raporlar', style: Theme.of(context).textTheme.titleLarge),
        if (reports.isEmpty) const ListTile(title: Text('Açık rapor yok')),
        for (final report in reports) Card(child: ListTile(
          title: Text('${report['reason'] ?? 'Rapor'}'), subtitle: Text('${report['targetType']} • ${report['targetId']}'),
          trailing: IconButton(tooltip: 'İçeriği kaldır', icon: const Icon(Icons.delete_outline), onPressed: () => _removeReport(report)),
        )),
        const SizedBox(height: 18), Text('Son Konular', style: Theme.of(context).textTheme.titleLarge),
        for (final topic in topics) Card(child: ListTile(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminCommunityTopicScreen(topicId: '${topic['id']}'))).then((_) => _load()),
          title: Text('${topic['title'] ?? ''}'), subtitle: Text('${topic['categoryName'] ?? ''} • ${topic['authorDisplayName'] ?? ''}'),
          trailing: PopupMenuButton<String>(onSelected: (v) => _topicAction(topic, v), itemBuilder: (_) => const [
            PopupMenuItem(value:'lock',child:Text('Kilitle')), PopupMenuItem(value:'unlock',child:Text('Kilidi aç')),
            PopupMenuItem(value:'remove',child:Text('Kaldır')), PopupMenuItem(value:'restore',child:Text('Geri yükle')),
            PopupMenuDivider(), PopupMenuItem(value:'suspend',child:Text('Yazarı 7 gün uzaklaştır')),
            PopupMenuItem(value:'ban',child:Text('Yazarı Meclis’ten yasakla')),
          ]),
        )),
      ]),
    )),
  );

  Widget _metric(String label, dynamic value) => Container(width:150, padding:const EdgeInsets.all(16), decoration:faloraParchmentDecoration(), child:Column(children:[Text('${value??0}',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w800)),Text(label)]));
  Future<void> _topicAction(dynamic topic, String action) async {
    if (action == 'suspend' || action == 'ban') {
      await _post('/admin/community/users/action', {'userId':topic['userId'], 'action':action, 'days':7});
    } else {
      await _post('/admin/community/moderate', {'targetType':'topic','topicId':topic['id'],'targetId':topic['id'],'action':action});
    }
    _load();
  }
  Future<void> _removeReport(dynamic r) async { await _post('/admin/community/moderate', {'targetType':r['targetType'],'topicId':r['topicId']??r['targetId'],'targetId':r['targetId'],'reportId':r['id'],'action':'remove'}); _load(); }
  Future<void> _showCategories() async { await showModalBottomSheet<void>(context: context, isScrollControlled:true, builder: (context) => SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[Text('Kategoriler',style:Theme.of(context).textTheme.headlineSmall),for(final x in categories)SwitchListTile(value:x['enabled']==true,title:Text('${x['name']}'),subtitle:Text('${x['retentionMode']=='permanent'?'Kalıcı':'${x['retentionDays']??15} gün'}'),onChanged:(v)async{await _post('/admin/community/categories/${x['id']}',{'enabled':v});if(context.mounted)Navigator.pop(context);_load();})]))); }
  Future<void> _grantTestAccess() async {
    final controller = TextEditingController(text: 'prserdar.cakir@gmail.com');
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title:const Text('Test üyeliği ver'),content:TextField(controller:controller,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Kullanıcı e-postası')),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('30 gün ver'))]));
    if(ok==true){await _post('/admin/community/test-entitlement',{'email':controller.text.trim(),'days':30});if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('30 günlük test üyeliği verildi.')));}
  }
}

class AdminCommunityTopicScreen extends StatefulWidget {
  const AdminCommunityTopicScreen({super.key, required this.topicId});
  final String topicId;
  @override State<AdminCommunityTopicScreen> createState() => _AdminCommunityTopicState();
}

class _AdminCommunityTopicState extends State<AdminCommunityTopicScreen> {
  Map<String,dynamic>? topic;
  List<dynamic> replies=[];
  bool loading=true;
  Future<Map<String,dynamic>> _request(String method,String path,[Map<String,dynamic>? body])async{
    final headers=await BackendAuthClient.authHeaders();
    final response=method=='GET'?await http.get(Uri.parse('$apiBaseUrl$path'),headers:headers):await http.post(Uri.parse('$apiBaseUrl$path'),headers:headers,body:jsonEncode(body??{}));
    Map<String,dynamic> data;try{data=jsonDecode(response.body)as Map<String,dynamic>;}on FormatException{throw Exception('Yeni backend sürümü henüz Railway üzerinde yayında değil.');}
    if(response.statusCode>=300)throw Exception(data['error']);return data;
  }
  @override void initState(){super.initState();_load();}
  Future<void>_load()async{setState(()=>loading=true);try{final data=await _request('GET','/admin/community/topics/${widget.topicId}');if(mounted)setState((){topic=Map<String,dynamic>.from(data['topic']);replies=data['replies']??[];});}finally{if(mounted)setState(()=>loading=false);}}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Konu Yönetimi'),actions:[PopupMenuButton<String>(onSelected:_topicMenu,itemBuilder:(_)=>const[
      PopupMenuItem(value:'reply',child:Text('Konuya yorum at')),PopupMenuItem(value:'remove',child:Text('Konuyu sil')),
    ])]),
    body:FaloraBackground(child:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
      Text('${topic?['title']??''}',style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:8),Text('${topic?['body']??''}'),const Divider(height:32),
      Row(children:[Text('Yorumlar',style:Theme.of(context).textTheme.titleLarge),const Spacer(),TextButton.icon(onPressed:_writeReply,icon:const Icon(Icons.add_comment_outlined),label:const Text('Yorum at'))]),
      if(replies.isEmpty)const ListTile(title:Text('Henüz yorum yok')),
      for(final reply in replies)Card(child:ListTile(
        title:Row(children:[Expanded(child:Text('${reply['authorDisplayName']??'Kullanıcı'}')),if(reply['pinned']==true)const Icon(Icons.push_pin,size:18),if(reply['moderatorApproved']==true)const Padding(padding:EdgeInsets.only(left:6),child:Icon(Icons.verified,color:Colors.green,size:19))]),
        subtitle:Text('${reply['body']??''}'),
        trailing:PopupMenuButton<String>(onSelected:(action)=>_replyAction(reply,action),itemBuilder:(_)=>[
          const PopupMenuItem(value:'remove',child:Text('Yorumu sil')),
          PopupMenuItem(value:reply['pinned']==true?'unpin':'pin',child:Text(reply['pinned']==true?'Sabitlemeyi kaldır':'Yorumu sabitle')),
          PopupMenuItem(value:reply['moderatorApproved']==true?'unapprove':'approve',child:Text(reply['moderatorApproved']==true?'Onayı kaldır':'Moderatör onayı ver')),
        ]),
      )),
    ])),
  );
  Future<void>_topicMenu(String action)async{if(action=='reply'){await _writeReply();return;}await _request('POST','/admin/community/moderate',{'targetType':'topic','topicId':widget.topicId,'targetId':widget.topicId,'action':'remove'});if(mounted)Navigator.pop(context);}
  Future<void>_writeReply()async{final controller=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Moderatör yorumu'),content:TextField(controller:controller,maxLength:2000,maxLines:6),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Yayınla'))]));if(ok==true&&controller.text.trim().isNotEmpty){await _request('POST','/admin/community/topics/${widget.topicId}/replies',{'body':controller.text.trim()});_load();}}
  Future<void>_replyAction(dynamic reply,String action)async{await _request('POST','/admin/community/topics/${widget.topicId}/replies/${reply['id']}/action',{'action':action});_load();}
}
