import 'dart:convert';
import 'package:falora/ai_config.dart';
import 'package:falora/bulletin/bulletin_models.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:http/http.dart' as http;

class BulletinException implements Exception {
  BulletinException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BulletinService {
  BulletinService._();
  static final instance = BulletinService._();
  Future<Map<String, dynamic>> call(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final h = await BackendAuthClient.authHeaders(),
        u = Uri.parse('$apiBaseUrl$path');
    final r = method == 'GET'
        ? await http.get(u, headers: h)
        : await http.post(u, headers: h, body: jsonEncode(body ?? {}));
    Map<String, dynamic> d;
    try {
      d = r.body.isEmpty ? {} : Map<String, dynamic>.from(jsonDecode(r.body));
    } catch (_) {
      throw BulletinException('Sunucudan geçersiz yanıt alındı.');
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw BulletinException('${d['error'] ?? 'İşlem tamamlanamadı.'}');
    }
    return d;
  }

  Future<BulletinPage> feed(String category, {String? cursor}) async {
    final u = Uri(
      path: '/bulletin/feed',
      queryParameters: {'category': category, 'cursor': ?cursor},
    );
    final d = await call('GET', u.toString());
    return BulletinPage(
      ((d['items'] as List?) ?? [])
          .map((x) => BulletinPost.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
      d['nextCursor']?.toString(),
    );
  }

  Future<BulletinDetail> detail(String id, {String? cursor}) async {
    final u = Uri(
      path: '/bulletin/posts/$id',
      queryParameters: {'commentCursor': ?cursor},
    );
    final d = await call('GET', u.toString());
    return BulletinDetail(
      BulletinPost.fromJson(Map<String, dynamic>.from(d['post'])),
      ((d['comments'] as List?) ?? [])
          .map((x) => BulletinComment.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
      d['nextCommentCursor']?.toString(),
    );
  }

  Future<Map<String, dynamic>> like(String id) =>
      call('POST', '/bulletin/posts/$id/like');
  Future<void> comment(String id, String body) =>
      call('POST', '/bulletin/posts/$id/comments', body: {'body': body});
  Future<void> report(String postId, String commentId, String reason) => call(
    'POST',
    '/bulletin/comments/report',
    body: {'postId': postId, 'commentId': commentId, 'reason': reason},
  );
  Future<void> block(String userId) =>
      call('POST', '/bulletin/blocks', body: {'userId': userId});
  Future<void> submitContentRequest(String text) =>
      call('POST', '/bulletin/content-requests', body: {'text': text});
  Future<BulletinPoll?> poll() async {
    final d = await call('GET', '/bulletin/polls/active');
    return d['poll'] == null
        ? null
        : BulletinPoll.fromJson(Map<String, dynamic>.from(d['poll']));
  }

  Future<Map<String, dynamic>> vote(String id, String optionId) =>
      call('POST', '/bulletin/polls/$id/vote', body: {'optionId': optionId});
}
