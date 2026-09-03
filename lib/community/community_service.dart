import 'dart:convert';
import 'package:falora/ai_config.dart';
import 'package:falora/community/community_models.dart';
import 'package:falora/config/play_product_catalog.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:falora/services/play_billing_service.dart';
import 'package:falora/picked_image.dart';
import 'package:falora/utils/upload_image_prepare.dart';
import 'package:http/http.dart' as http;

class CommunityException implements Exception { CommunityException(this.message,{this.code}); final String message; final String? code; @override String toString()=>message; }
class CommunityService {
  CommunityService._(); static final instance=CommunityService._();
  Future<Map<String,dynamic>> _call(String method,String path,{Map<String,dynamic>? body}) async {
    final headers=await BackendAuthClient.authHeaders(); final uri=Uri.parse('$apiBaseUrl$path');
    final response=method=='GET'?await http.get(uri,headers:headers):await http.post(uri,headers:headers,body:jsonEncode(body??{}));
    Map<String,dynamic> decoded;
    try { decoded=response.body.isEmpty?<String,dynamic>{}:jsonDecode(response.body) as Map<String,dynamic>; }
    on FormatException { throw CommunityException(response.statusCode==404?'Fal Meclisi backend sürümü henüz yayında değil. Railway deploy işlemini tamamlayın.':'Sunucudan beklenmeyen bir yanıt alındı. Lütfen tekrar deneyin.',code:'invalid_server_response'); }
    if(response.statusCode<200||response.statusCode>=300)throw CommunityException('${decoded['error']??'İşlem tamamlanamadı.'}',code:decoded['code']?.toString());
    return decoded;
  }
  Future<List<CommunityCategory>> categories() async {final d=await _call('GET','/community/categories');return (d['items'] as List? ?? []).map((x)=>CommunityCategory.fromJson(Map<String,dynamic>.from(x))).toList();}
  Future<TopicPage> topics({String? categoryId,String? search,String? cursor}) async {final q=<String,String>{if(categoryId?.isNotEmpty==true)'categoryId':categoryId!,if(search?.isNotEmpty==true)'search':search!,if(cursor?.isNotEmpty==true)'cursor':cursor!};final uri=Uri(path:'/community/topics',queryParameters:q).toString();final d=await _call('GET',uri);return TopicPage(((d['items'] as List?) ?? []).map((x)=>CommunityTopic.fromJson(Map<String,dynamic>.from(x))).toList(),d['nextCursor']?.toString());}
  Future<TopicDetail> detail(String id) async {final d=await _call('GET','/community/topics/$id');return TopicDetail(topic:CommunityTopic.fromJson(Map<String,dynamic>.from(d['topic'])),replies:((d['replies'] as List?) ?? []).map((x)=>CommunityReply.fromJson(Map<String,dynamic>.from(x))).toList(),repliesLocked:d['repliesLocked']==true,isPremium:(d['entitlement'] as Map?)?['active']==true);}
  Future<String> createTopic({required String title,required String body,required String categoryId})async=>(await _call('POST','/community/topics',body:{'title':title,'body':body,'categoryId':categoryId}))['id'].toString();
  Future<void> attachImages(String topicId,List<PickedImage> source)async{if(source.isEmpty)return;final prepared=await prepareImagesForUpload(source);final encoded=<Map<String,String>>[];for(final image in prepared){encoded.add(await encodeImageForFirestorePayload(image));}await _call('POST','/community/topics/$topicId/images',body:{'images':encoded});}
  Future<void> reply(String topicId,String body)=>_call('POST','/community/topics/$topicId/replies',body:{'body':body});
  Future<void> accept(String topicId,String replyId)=>_call('POST','/community/topics/$topicId/solution',body:{'replyId':replyId});
  Future<void> report({required String targetType,required String targetId,required String topicId,required String reason})=>_call('POST','/community/reports',body:{'targetType':targetType,'targetId':targetId,'topicId':topicId,'reason':reason});
  Future<void> blockTopicAuthor(String topicId)=>_call('POST','/community/blocks',body:{'topicId':topicId});
  Future<bool> entitlement()async=>(await _call('GET','/community/entitlement'))['active']==true;
  Future<bool> subscribe()async{final result=await PlayBillingService.instance.buySubscription(iosCommunitySubscriptionProductId);final d=await _call('POST','/community/subscription/complete',body:{'purchaseId':result.purchaseId,'productId':result.productId});return d['active']==true;}
  Future<bool> restore()async{final items=await PlayBillingService.instance.restorePurchases();for(final x in items.where((x)=>x.productId==iosCommunitySubscriptionProductId)){final d=await _call('POST','/community/subscription/complete',body:{'purchaseId':x.purchaseId,'productId':x.productId});if(d['active']==true)return true;}return entitlement();}
  Future<String?> subscriptionPrice()async{final p=await PlayBillingService.instance.queryProducts({iosCommunitySubscriptionProductId});return p.isEmpty?null:p.first.price;}
}
