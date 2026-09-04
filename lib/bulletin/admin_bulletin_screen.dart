import 'dart:convert';
import 'package:falora/ai_config.dart';
import 'package:falora/picked_image.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:falora/utils/upload_image_prepare.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AdminBulletinScreen extends StatefulWidget {
  const AdminBulletinScreen({super.key});
  @override
  State<AdminBulletinScreen> createState() => _AdminBulletinState();
}

class _AdminBulletinState extends State<AdminBulletinScreen> {
  Map<String, dynamic> overview = {};
  List<dynamic> posts = [],
      polls = [],
      comments = [],
      bans = [],
      contentRequests = [];
  bool loading = true;
  Future<Map<String, dynamic>> _call(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final h = await BackendAuthClient.authHeaders(),
        u = Uri.parse('$apiBaseUrl$path');
    final r = method == 'GET'
        ? await http.get(u, headers: h)
        : await http.post(u, headers: h, body: jsonEncode(body ?? {}));
    final d = r.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(r.body));
    if (r.statusCode >= 300) throw Exception(d['error']);
    return d;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final r = await Future.wait([
        _call('GET', '/admin/bulletin/overview'),
        _call('GET', '/admin/bulletin/posts'),
        _call('GET', '/admin/bulletin/polls'),
        _call('GET', '/admin/bulletin/comments'),
        _call('GET', '/admin/bulletin/bans'),
        _call('GET', '/admin/bulletin/content-requests'),
      ]);
      if (mounted) {
        setState(() {
          overview = r[0];
          posts = r[1]['items'] ?? [];
          polls = r[2]['items'] ?? [];
          comments = r[3]['items'] ?? [];
          bans = r[4]['items'] ?? [];
          contentRequests = r[5]['items'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Tombik Teyze Bülteni'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'İçerikler'),
            Tab(text: 'Anketler'),
            Tab(text: 'Banlar'),
            Tab(text: 'Talepler'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Yeni içerik'),
      ),
      body: FaloraBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _postsTab(c),
                  _pollsTab(c),
                  _bansTab(c),
                  _contentRequestsTab(c),
                ],
              ),
      ),
    ),
  );
  Widget _postsTab(BuildContext c) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _stat('Bugün', '${overview['publishedToday'] ?? 0}'),
          _stat('Aktif Günlük', '${overview['activeDaily'] ?? 0}'),
          _stat('Falsal Bilgiler', '${overview['knowledge'] ?? 0}'),
          _stat('İlişki', '${overview['relationship'] ?? 0}'),
        ],
      ),
      const SizedBox(height: 14),
      if (posts.isEmpty)
        const ListTile(title: Text('Henüz Bülten içeriği yok'))
      else
        ...posts
            .where((p) => (p['categoryIds'] as List? ?? []).contains('daily'))
            .map(_adminPostCard),
      if (posts.any(
        (p) => !(p['categoryIds'] as List? ?? []).contains('daily'),
      )) ...[
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(
            'Diğer içerikler',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        ...posts
            .where((p) => !(p['categoryIds'] as List? ?? []).contains('daily'))
            .map(_adminPostCard),
      ],
    ],
  );

  Widget _adminPostCard(dynamic p) {
    final postComments = comments
        .where(
          (x) => x['postId'] == p['id'] && x['moderationStatus'] != 'removed',
        )
        .take(5)
        .toList();
    final publishedAt = p['publishedAt'] is num
        ? DateFormat('dd.MM.yyyy HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(
              (p['publishedAt'] as num).toInt(),
            ),
          )
        : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.auto_awesome)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p['authorDisplayName'] ?? 'Tombik Teyze'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${p['status']} • $publishedAt',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'İçerik işlemleri',
                  onSelected: (a) => _postAction(p, a),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    PopupMenuItem(
                      value: p['status'] == 'published'
                          ? 'unpublish'
                          : 'publish',
                      child: Text(
                        p['status'] == 'published'
                            ? 'Yayından kaldır'
                            : 'Yayınla',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('İçeriği kaldır'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (p['mediaType'] == 'image' && p['imageUrl'] != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network('${p['imageUrl']}', fit: BoxFit.cover),
            ),
          if (p['mediaType'] == 'youtube' && p['youtubeThumbnailUrl'] != null)
            Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    '${p['youtubeThumbnailUrl']}',
                    fit: BoxFit.cover,
                  ),
                ),
                const CircleAvatar(
                  radius: 26,
                  child: Icon(Icons.play_arrow, size: 34),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p['title'] ?? ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                if ('${p['summary'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    '${p['summary']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
                if ('${p['body'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text('${p['body']}', style: const TextStyle(height: 1.45)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.favorite_border, size: 19),
                    const SizedBox(width: 5),
                    Text('${p['likeCount'] ?? 0} beğeni'),
                    const SizedBox(width: 18),
                    const Icon(Icons.chat_bubble_outline, size: 18),
                    const SizedBox(width: 5),
                    Text('${p['commentCount'] ?? 0} yorum'),
                  ],
                ),
                if (postComments.isNotEmpty) ...[
                  const Divider(height: 26),
                  for (final x in postComments) _adminInlineComment(x),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminInlineComment(dynamic x) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 14,
          child: Icon(Icons.person_outline, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${x['displayName'] ?? 'Kullanıcı'}  ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: '${x['body'] ?? ''}'),
              ],
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Yorum işlemleri',
          padding: EdgeInsets.zero,
          iconSize: 20,
          onSelected: (action) => _commentAction(x, action),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'remove', child: Text('Yorumu sil')),
            PopupMenuItem(value: 'ban', child: Text('Kullanıcıyı engelle')),
          ],
        ),
      ],
    ),
  );
  Widget _pollsTab(BuildContext c) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      FilledButton.icon(
        onPressed: _newPoll,
        icon: const Icon(Icons.add_chart),
        label: const Text('Yeni ilişki anketi'),
      ),
      const SizedBox(height: 10),
      for (final p in polls)
        Card(
          child: ExpansionTile(
            title: Text('${p['question']}'),
            subtitle: Text('${p['status']} • ${p['totalVotes'] ?? 0} oy'),
            children: [
              for (final o in (p['options'] as List? ?? []))
                ListTile(
                  title: Text('${o['text']}'),
                  subtitle: Text('${o['voteCount'] ?? 0} oy'),
                  trailing: IconButton(
                    tooltip: 'Kazanan konu olarak onayla',
                    icon: const Icon(Icons.emoji_events_outlined),
                    onPressed: () => _confirmWinner(p, o),
                  ),
                ),
              OverflowBar(
                children: [
                  TextButton(
                    onPressed: () => _pollAction(p, 'close'),
                    child: const Text('Kapat'),
                  ),
                  TextButton(
                    onPressed: () => _pollAction(p, 'archive'),
                    child: const Text('Arşivle'),
                  ),
                ],
              ),
            ],
          ),
        ),
    ],
  );
  Widget _bansTab(BuildContext c) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      if (bans.isEmpty) const ListTile(title: Text('Bülten banı yok')),
      for (final b in bans)
        Card(
          child: ListTile(
            title: Text('${b['userId']}'),
            subtitle: Text('${b['reason'] ?? ''}'),
            trailing: TextButton(
              onPressed: () async {
                await _call(
                  'POST',
                  '/admin/bulletin/bans/${b['userId']}/unban',
                );
                _load();
              },
              child: const Text('Banı kaldır'),
            ),
          ),
        ),
    ],
  );
  Widget _contentRequestsTab(BuildContext c) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      if (contentRequests.isEmpty)
        const ListTile(title: Text('Henüz içerik talebi yok')),
      for (final item in contentRequests)
        Card(
          child: ListTile(
            title: Text('${item['displayName'] ?? 'Bülten Okuru'}'),
            subtitle: Text(
              '${item['text'] ?? ''}\nDurum: ${item['status'] ?? 'open'}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                await _call(
                  'POST',
                  '/admin/bulletin/content-requests/${item['id']}/action',
                  {'action': action},
                );
                _load();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'poll_candidate',
                  child: Text('Anket adayı yap'),
                ),
                PopupMenuItem(value: 'dismiss', child: Text('Kapat')),
              ],
            ),
          ),
        ),
    ],
  );
  Widget _stat(String a, String b) => Chip(
    avatar: const Icon(Icons.auto_awesome, size: 16),
    label: Text('$a: $b'),
  );
  Future<void> _postAction(dynamic p, String a) async {
    if (a == 'edit') {
      _edit(p);
      return;
    }
    try {
      await _call('POST', '/admin/bulletin/posts/${p['id']}/action', {
        'action': a,
      });
      if (a == 'remove' && mounted) {
        setState(() => posts.removeWhere((item) => item['id'] == p['id']));
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem tamamlanamadı: $e')),
      );
    }
  }

  Future<void> _pollAction(dynamic p, String a) async {
    await _call('POST', '/admin/bulletin/polls/${p['id']}/action', {
      'action': a,
    });
    _load();
  }

  Future<void> _confirmWinner(dynamic p, dynamic option) async {
    await _call('POST', '/admin/bulletin/polls/${p['id']}/action', {
      'action': 'confirm',
      'optionId': option['id'],
    });
    _load();
  }

  Future<void> _commentAction(dynamic x, String action) async {
    try {
      await _call('POST', '/admin/bulletin/comments/action', {
        'postId': x['postId'],
        'commentId': x['id'],
        'action': action,
      });
      if (action == 'remove' && mounted) {
        setState(() {
          comments.removeWhere(
            (item) =>
                item['id'] == x['id'] && item['postId'] == x['postId'],
          );
          dynamic post;
          for (final item in posts) {
            if (item is Map && item['id'] == x['postId']) {
              post = item;
              break;
            }
          }
          if (post != null) {
            final count = (post['commentCount'] as num?)?.toInt() ?? 0;
            post['commentCount'] = count > 0 ? count - 1 : 0;
          }
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'remove'
                  ? 'Yorum kaldırıldı.'
                  : 'Kullanıcı Bülten’den engellendi.',
            ),
          ),
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem tamamlanamadı: $e')),
      );
    }
  }

  Future<void> _edit([dynamic source]) async {
    final title = TextEditingController(text: '${source?['title'] ?? ''}'),
        summary = TextEditingController(text: '${source?['summary'] ?? ''}'),
        body = TextEditingController(text: '${source?['body'] ?? ''}'),
        youtube = TextEditingController(text: '${source?['youtubeUrl'] ?? ''}');
    var cats = Set<String>.from(
      (source?['categoryIds'] as List? ?? []).map((x) => '$x'),
    );
    if (cats.isEmpty) cats = {'daily'};
    var author = '${source?['authorId'] ?? 'tombik_teyze'}',
        media = '${source?['mediaType'] ?? 'none'}',
        status = '${source?['status'] ?? 'draft'}';
    var scheduledFor = source?['scheduledFor'] is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (source['scheduledFor'] as num).toInt(),
          )
        : DateTime.now().add(const Duration(hours: 1));
    PickedImage? image;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            source == null ? 'Yeni Bülten içeriği' : 'İçeriği düzenle',
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    maxLength: 140,
                    decoration: const InputDecoration(labelText: 'Başlık'),
                  ),
                  TextField(
                    controller: summary,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Kısa özet (isteğe bağlı)',
                    ),
                  ),
                  TextField(
                    controller: body,
                    maxLength: 12000,
                    minLines: 5,
                    maxLines: 12,
                    decoration: const InputDecoration(labelText: 'Ana içerik'),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kategoriler',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  CheckboxListTile(
                    value: cats.contains('daily'),
                    title: const Text('Günlük'),
                    onChanged: (v) => setLocal(
                      () =>
                          v == true ? cats.add('daily') : cats.remove('daily'),
                    ),
                  ),
                  CheckboxListTile(
                    value: cats.contains('knowledge'),
                    title: const Text('Falsal Bilgiler'),
                    onChanged: (v) => setLocal(
                      () => v == true
                          ? cats.add('knowledge')
                          : cats.remove('knowledge'),
                    ),
                  ),
                  CheckboxListTile(
                    value: cats.contains('relationship'),
                    title: const Text('İlişki Tavsiyeleri'),
                    onChanged: (v) => setLocal(
                      () => v == true
                          ? cats.add('relationship')
                          : cats.remove('relationship'),
                    ),
                  ),
                  DropdownButtonFormField(
                    initialValue: author,
                    decoration: const InputDecoration(labelText: 'Yayıncı'),
                    items: const [
                      DropdownMenuItem(
                        value: 'tombik_teyze',
                        child: Text('Tombik Teyze ✓'),
                      ),
                      DropdownMenuItem(
                        value: 'serdar',
                        child: Text('Serdar Çakır ✓'),
                      ),
                      DropdownMenuItem(
                        value: 'hatice',
                        child: Text('Hatice ✓'),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => author = v!),
                  ),
                  DropdownButtonFormField(
                    initialValue: media,
                    decoration: const InputDecoration(labelText: 'Medya'),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('Yazı')),
                      DropdownMenuItem(value: 'image', child: Text('Görsel')),
                      DropdownMenuItem(
                        value: 'youtube',
                        child: Text('YouTube Video'),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => media = v!),
                  ),
                  if (media == 'youtube')
                    TextField(
                      controller: youtube,
                      decoration: const InputDecoration(
                        labelText: 'YouTube bağlantısı',
                      ),
                    ),
                  if (media == 'image')
                    ListTile(
                      title: Text(
                        image?.name ?? 'Optimize edilecek görseli seç',
                      ),
                      trailing: const Icon(Icons.image),
                      onTap: () async {
                        final x = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                        );
                        if (x != null) {
                          final bytes = await x.readAsBytes();
                          image = await prepareImageWithOptions(
                            PickedImage(name: x.name, bytes: bytes),
                            const ImagePrepareOptions(
                              maxEdge: 1440,
                              jpegQuality: 80,
                              skipBelowBytes: 120 * 1024,
                            ),
                          );
                          setLocal(() {});
                        }
                      },
                    ),
                  DropdownButtonFormField(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Durum'),
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('Taslak')),
                      DropdownMenuItem(
                        value: 'published',
                        child: Text('Yayınla'),
                      ),
                      DropdownMenuItem(
                        value: 'scheduled',
                        child: Text('İleri tarihe planla'),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => status = v!),
                  ),
                  if (status == 'scheduled')
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: const Text('Yayın tarihi ve saati'),
                      subtitle: Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(scheduledFor),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          initialDate: scheduledFor,
                        );
                        if (date == null || !context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(scheduledFor),
                        );
                        if (time != null) {
                          setLocal(
                            () => scheduledFor = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    if (cats.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('En az bir kategori seç.')),
        );
      }
      return;
    }
    final result = await _call(
      'POST',
      source == null
          ? '/admin/bulletin/posts'
          : '/admin/bulletin/posts/${source['id']}',
      {
        'title': title.text,
        'summary': summary.text,
        'body': body.text,
        'categoryIds': cats.toList(),
        'authorId': author,
        'mediaType': media,
        'youtubeUrl': youtube.text,
        'status': status,
        if (status == 'scheduled')
          'scheduledFor': scheduledFor.millisecondsSinceEpoch,
      },
    );
    if (image != null) {
      final encoded = await encodeImageForFirestorePayload(image!);
      await _call(
        'POST',
        '/admin/bulletin/posts/${result['id'] ?? source['id']}/image',
        {'image': encoded},
      );
    }
    _load();
  }

  Future<void> _newPoll() async {
    final q = TextEditingController(), options = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yeni ilişki anketi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: q,
              decoration: const InputDecoration(labelText: 'Soru'),
            ),
            TextField(
              controller: options,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Seçenekler (her satıra bir seçenek)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Yayınla'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _call('POST', '/admin/bulletin/polls', {
        'question': q.text,
        'options': options.text
            .split('\n')
            .where((x) => x.trim().isNotEmpty)
            .toList(),
        'durationHours': 72,
      });
      _load();
    }
  }
}
