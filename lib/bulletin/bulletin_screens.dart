import 'package:falora/bulletin/bulletin_models.dart';
import 'package:falora/bulletin/bulletin_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class IosProductGatewayScreen extends StatelessWidget {
  const IosProductGatewayScreen({super.key, required this.onOpenFortune});
  final VoidCallback onOpenFortune;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: FaloraBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 36),
            Text(
              'Tombik Teyze',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bugün hangi dünyaya adım atmak istersin?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _GatewayCard(
              icon: Icons.auto_awesome,
              title: 'Kişisel Fal',
              subtitle: 'Kişisel fal deneyimine başla',
              button: 'Fala Başla',
              onTap: onOpenFortune,
            ),
            const SizedBox(height: 18),
            _GatewayCard(
              icon: Icons.auto_stories_rounded,
              title: 'Tombik Teyze Bülteni',
              subtitle: 'Günlük içerikler, fal bilgileri ve ilişki tavsiyeleri',
              button: 'Bülteni Aç',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BulletinHomeScreen()),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GatewayCard extends StatelessWidget {
  const _GatewayCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.button,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle, button;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(25),
    decoration: faloraParchmentDecoration(),
    child: Column(
      children: [
        Icon(icon, size: 48, color: faloraBronze),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(
            c,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Text(subtitle, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: onTap, child: Text(button)),
        ),
      ],
    ),
  );
}

class BulletinHomeScreen extends StatefulWidget {
  const BulletinHomeScreen({super.key});
  @override
  State<BulletinHomeScreen> createState() => _BulletinHomeState();
}

class _BulletinHomeState extends State<BulletinHomeScreen> {
  String category = 'daily';
  List<BulletinPost> posts = [];
  String? cursor;
  bool loading = true, more = false;
  BulletinPoll? poll;
  @override
  void initState() {
    super.initState();
    _load(true);
  }

  Future<void> _load(bool reset) async {
    setState(() {
      if (reset) {
        loading = true;
      } else {
        more = true;
      }
    });
    try {
      final page = await BulletinService.instance.feed(
        category,
        cursor: reset ? null : cursor,
      );
      BulletinPoll? nextPoll;
      if (category == 'relationship') {
        nextPoll = await BulletinService.instance.poll();
      }
      if (!mounted) return;
      setState(() {
        posts = reset ? page.items : [...posts, ...page.items];
        cursor = page.cursor;
        poll = nextPoll;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          more = false;
        });
      }
    }
  }

  void _select(String value) {
    if (value == category) return;
    setState(() => category = value);
    _load(true);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tombik Teyze Bülteni'),
          Text(
            'Günlük içerikler ve seçilmiş yazılar',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    ),
    body: FaloraBackground(
      child: RefreshIndicator(
        onRefresh: () => _load(true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          children: [
            _Categories(selected: category, onSelect: _select),
            const SizedBox(height: 14),
            if (category == 'daily') const _DailyNotice(),
            if (poll != null) ...[
              _PollCard(poll: poll!, onVoted: () => _load(true)),
              const SizedBox(height: 12),
            ],
            if (loading)
              const Padding(
                padding: EdgeInsets.all(50),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (posts.isEmpty)
              _Empty(category: category)
            else
              for (final post in posts)
                _PostCard(
                  post: post,
                  onOpen: () => Navigator.push(
                    c,
                    MaterialPageRoute(
                      builder: (_) => BulletinDetailScreen(id: post.id),
                    ),
                  ).then((_) => _load(true)),
                ),
            if (cursor != null)
              TextButton(
                onPressed: more ? null : () => _load(false),
                child: Text(more ? 'Yükleniyor…' : 'Daha fazla göster'),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Categories extends StatelessWidget {
  const _Categories({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: faloraParchmentCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: faloraBronze.withValues(alpha: .35)),
    ),
    child: Row(
      children: [
        _tab('daily', 'Günlük', Icons.today),
        _tab('knowledge', 'Falsal Bilgiler', Icons.school_outlined),
        _tab('relationship', 'İlişki Tavsiyeleri', Icons.favorite_border),
      ],
    ),
  );
  Widget _tab(String id, String label, IconData icon) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onSelect(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
        decoration: BoxDecoration(
          color: selected == id ? faloraBronze : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 21,
              color: selected == id ? Colors.white : faloraBronzeDark,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected == id ? Colors.white : faloraInkHeading,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DailyNotice extends StatelessWidget {
  const _DailyNotice();
  @override
  Widget build(BuildContext c) => const Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(Icons.schedule, size: 17, color: faloraBronzeDark),
        SizedBox(width: 7),
        Expanded(
          child: Text(
            'Bugüne özel içerikler gece yarısında Günlük akışından ayrılır.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.category});
  final String category;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(34),
    decoration: faloraParchmentDecoration(),
    child: Column(
      children: [
        const Icon(Icons.auto_stories_outlined, size: 44, color: faloraBronze),
        const SizedBox(height: 10),
        Text(
          category == 'daily'
              ? 'Bugün için henüz yayın yok'
              : 'Bu bölümde henüz içerik yok',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          'Yeni içerikler yayınlandığında burada görünecek.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _PostCard extends StatefulWidget {
  const _PostCard({required this.post, required this.onOpen});
  final BulletinPost post;
  final VoidCallback onOpen;
  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  late BulletinPost post = widget.post;
  List<BulletinComment> comments = const [];
  String? commentCursor;
  bool loadingComments = true, liking = false;
  YoutubePlayerController? player;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void didUpdateWidget(covariant _PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      post = widget.post;
      comments = const [];
      _loadComments();
    }
  }

  @override
  void dispose() {
    player?.close();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final detail = await BulletinService.instance.detail(post.id);
      if (mounted) {
        setState(() {
          post = detail.post;
          comments = detail.comments;
          commentCursor = detail.cursor;
          loadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loadingComments = false);
    }
  }

  Future<void> _like() async {
    if (liking || !post.allowLikes) return;
    final old = post;
    setState(() {
      liking = true;
      post = BulletinPost.fromJson(
        _postToJson(old)
          ..['liked'] = !old.liked
          ..['likeCount'] = old.likeCount + (old.liked ? -1 : 1),
      );
    });
    try {
      final result = await BulletinService.instance.like(post.id);
      if (mounted) {
        setState(
          () => post = BulletinPost.fromJson(
            _postToJson(post)
              ..['liked'] = result['liked']
              ..['likeCount'] = result['likeCount'],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => post = old);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => liking = false);
    }
  }

  Future<void> _comment() async {
    final controller = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Yorum yaz'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 1500,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Yorumunu paylaş…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Yayınla'),
          ),
        ],
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (send != true || text.length < 2) return;
    if (_quickReject(text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yorum uygunsuz ifade içeriyor.')),
        );
      }
      return;
    }
    await BulletinService.instance.comment(post.id, text);
    await _loadComments();
  }

  void _play() {
    final id = post.youtubeVideoId;
    if (id == null) return;
    setState(
      () => player = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: true,
        ),
      ),
    );
  }

  Future<void> _share() => SharePlus.instance.share(
    ShareParams(subject: post.title, text: '${post.title}\n\n${post.body}'),
  );

  @override
  Widget build(BuildContext c) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: faloraBronze.withValues(alpha: .15),
                child: const Icon(Icons.auto_awesome, color: faloraBronzeDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.authorDisplayName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (post.authorVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.verified,
                              size: 17,
                              color: Color(0xFF47755C),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${_categoryNames(post.categoryIds)} • ${DateFormat('dd.MM • HH:mm').format(post.publishedAt)}',
                      style: Theme.of(c).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (post.mediaType == 'image' && post.imageUrl != null)
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.network(
              post.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        if (post.mediaType == 'youtube' && post.youtubeVideoId != null)
          player == null
              ? _YoutubeThumb(post: post, onTap: _play)
              : YoutubePlayer(controller: player!, aspectRatio: 16 / 9),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.title,
                style: Theme.of(
                  c,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (post.summary.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  post.summary,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              if (post.body.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(post.body, style: const TextStyle(height: 1.45)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Beğen',
                    onPressed: post.allowLikes ? _like : null,
                    icon: Icon(
                      post.liked ? Icons.favorite : Icons.favorite_border,
                      color: post.liked ? Colors.redAccent : faloraBronzeDark,
                    ),
                  ),
                  Text('${post.likeCount} beğeni'),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: post.allowComments ? _comment : null,
                    icon: const Icon(Icons.chat_bubble_outline, size: 20),
                    label: Text('${post.commentCount} yorum'),
                  ),
                  const Spacer(),
                  if (post.allowShare)
                    IconButton(
                      tooltip: 'Paylaş',
                      onPressed: _share,
                      icon: const Icon(Icons.ios_share),
                    ),
                ],
              ),
              const Divider(),
              if (loadingComments)
                const LinearProgressIndicator(minHeight: 2)
              else if (comments.isEmpty)
                InkWell(
                  onTap: post.allowComments ? _comment : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('Henüz yorum yok. İlk yorumu sen yaz.'),
                  ),
                )
              else ...[
                for (final comment in comments.take(3))
                  _CommentCard(
                    postId: post.id,
                    comment: comment,
                    onChanged: _loadComments,
                  ),
                if (comments.length > 3 || commentCursor != null)
                  TextButton(
                    onPressed: widget.onOpen,
                    child: Text('Tüm ${post.commentCount} yorumu gör'),
                  ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

String _categoryNames(List<String> ids) => ids
    .map(
      (x) => x == 'daily'
          ? 'Günlük'
          : x == 'knowledge'
          ? 'Falsal Bilgiler'
          : 'İlişki Tavsiyeleri',
    )
    .join(' • ');

class _YoutubeThumb extends StatelessWidget {
  const _YoutubeThumb({required this.post, required this.onTap});
  final BulletinPost post;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          post.youtubeThumbnailUrl ??
              'https://i.ytimg.com/vi/${post.youtubeVideoId}/hqdefault.jpg',
          fit: BoxFit.cover,
        ),
        Container(color: Colors.black26),
        Center(
          child: IconButton.filled(
            onPressed: onTap,
            iconSize: 42,
            icon: const Icon(Icons.play_arrow),
          ),
        ),
      ],
    ),
  );
}

class BulletinDetailScreen extends StatefulWidget {
  const BulletinDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<BulletinDetailScreen> createState() => _BulletinDetailState();
}

class _BulletinDetailState extends State<BulletinDetailScreen> {
  BulletinDetail? detail;
  bool loading = true, liking = false;
  YoutubePlayerController? player;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    player?.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await BulletinService.instance.detail(widget.id);
      if (mounted) {
        setState(() {
          detail = d;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _play() {
    final id = detail!.post.youtubeVideoId;
    if (id == null) return;
    setState(
      () => player = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: true,
        ),
      ),
    );
  }

  Future<void> _like() async {
    if (liking || detail == null) return;
    final old = detail!.post;
    final optimistic = _postToJson(old)
      ..['liked'] = !old.liked
      ..['likeCount'] = old.likeCount + (old.liked ? -1 : 1);
    setState(() {
      liking = true;
      detail = BulletinDetail(
        BulletinPost.fromJson(optimistic),
        detail!.comments,
        detail!.cursor,
      );
    });
    try {
      final r = await BulletinService.instance.like(widget.id);
      if (!mounted) return;
      final json = _postToJson(old)
        ..['liked'] = r['liked']
        ..['likeCount'] = r['likeCount'];
      setState(
        () => detail = BulletinDetail(
          BulletinPost.fromJson(json),
          detail!.comments,
          detail!.cursor,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => detail = BulletinDetail(old, detail!.comments, detail!.cursor),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => liking = false);
    }
  }

  Future<void> _comment() async {
    final x = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yorum yaz'),
        content: TextField(
          controller: x,
          maxLength: 1500,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Saygılı ve yapıcı bir yorum yaz…',
          ),
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
    if (ok == true && x.text.trim().length > 1) {
      if (_quickReject(x.text)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yorum uygunsuz ifade içeriyor.')),
          );
        }
        return;
      }
      await BulletinService.instance.comment(widget.id, x.text.trim());
      await _load();
    }
  }

  Future<void> _share() async {
    final p = detail!.post;
    await SharePlus.instance.share(
      ShareParams(
        subject: p.title,
        text: '${p.title}\n\n${p.summary.isNotEmpty ? p.summary : p.body}',
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Bülten')),
    body: FaloraBackground(
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
          ? const Center(child: Text('İçerik bulunamadı'))
          : ListView(
              padding: const EdgeInsets.all(15),
              children: [
                _Header(post: detail!.post),
                const SizedBox(height: 14),
                Text(
                  detail!.post.title,
                  style: Theme.of(c).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                if (detail!.post.mediaType == 'image' &&
                    detail!.post.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(detail!.post.imageUrl!),
                  ),
                if (detail!.post.mediaType == 'youtube' &&
                    detail!.post.youtubeVideoId != null) ...[
                  const SizedBox(height: 8),
                  player == null
                      ? _YoutubeThumb(post: detail!.post, onTap: _play)
                      : YoutubePlayer(controller: player!, aspectRatio: 16 / 9),
                ],
                const SizedBox(height: 16),
                Text(
                  detail!.post.body,
                  style: const TextStyle(height: 1.55, fontSize: 16),
                ),
                const Divider(height: 34),
                Row(
                  children: [
                    if (detail!.post.allowLikes)
                      TextButton.icon(
                        onPressed: _like,
                        icon: Icon(
                          detail!.post.liked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: detail!.post.liked ? Colors.redAccent : null,
                        ),
                        label: Text('${detail!.post.likeCount} Beğeni'),
                      ),
                    if (detail!.post.allowComments)
                      TextButton.icon(
                        onPressed: _comment,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text('${detail!.post.commentCount} Yorum'),
                      ),
                    const Spacer(),
                    if (detail!.post.allowShare)
                      IconButton(
                        tooltip: 'Paylaş',
                        onPressed: _share,
                        icon: const Icon(Icons.ios_share),
                      ),
                  ],
                ),
                Text(
                  'Yorumlar',
                  style: Theme.of(
                    c,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (detail!.comments.isEmpty)
                  const Text('Henüz yorum yok. İlk yorumu sen yazabilirsin.')
                else
                  for (final x in detail!.comments)
                    _CommentCard(
                      postId: widget.id,
                      comment: x,
                      onChanged: _load,
                    ),
                if (detail!.cursor != null)
                  TextButton(
                    onPressed: _moreComments,
                    child: const Text('Daha fazla yorum'),
                  ),
              ],
            ),
    ),
  );
  Future<void> _moreComments() async {
    final d = await BulletinService.instance.detail(
      widget.id,
      cursor: detail!.cursor,
    );
    if (mounted) {
      setState(
        () => detail = BulletinDetail(d.post, [
          ...detail!.comments,
          ...d.comments,
        ], d.cursor),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.post});
  final BulletinPost post;
  @override
  Widget build(BuildContext c) => Row(
    children: [
      const CircleAvatar(child: Icon(Icons.auto_awesome)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  post.authorDisplayName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (post.authorVerified)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.verified,
                      size: 17,
                      color: Color(0xFF47755C),
                    ),
                  ),
              ],
            ),
            Text(
              '${_categoryNames(post.categoryIds)} • ${DateFormat('dd.MM.yyyy HH:mm').format(post.publishedAt)}',
            ),
          ],
        ),
      ),
    ],
  );
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.postId,
    required this.comment,
    required this.onChanged,
  });
  final String postId;
  final BulletinComment comment;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => _action(c, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'report', child: Text('Yorumu bildir')),
                  PopupMenuItem(
                    value: 'block',
                    child: Text('Kullanıcıyı engelle'),
                  ),
                ],
              ),
            ],
          ),
          Text(comment.body),
          const SizedBox(height: 5),
          Text(
            DateFormat('dd.MM.yyyy HH:mm').format(comment.createdAt),
            style: Theme.of(c).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
  Future<void> _action(BuildContext c, String action) async {
    if (action == 'block') {
      await BulletinService.instance.block(comment.userId);
      onChanged();
      return;
    }
    final reason = await showModalBottomSheet<String>(
      context: c,
      builder: (x) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in [
              'Küfür / Hakaret',
              'Taciz',
              'Spam',
              'Uygunsuz İçerik',
              'Kişisel Bilgi',
              'Diğer',
            ])
              ListTile(title: Text(r), onTap: () => Navigator.pop(x, r)),
          ],
        ),
      ),
    );
    if (reason != null) {
      await BulletinService.instance.report(postId, comment.id, reason);
      if (c.mounted) {
        ScaffoldMessenger.of(
          c,
        ).showSnackBar(const SnackBar(content: Text('Şikâyet alındı.')));
      }
    }
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll, required this.onVoted});
  final BulletinPoll poll;
  final VoidCallback onVoted;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(16),
    decoration: faloraParchmentDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.how_to_vote, color: faloraBronzeDark),
            SizedBox(width: 8),
            Text(
              'Sıradaki ilişki konusu',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(poll.question, style: Theme.of(c).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final o in poll.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: OutlinedButton(
              onPressed: poll.userOptionId == null
                  ? () async {
                      await BulletinService.instance.vote(poll.id, o.id);
                      onVoted();
                    }
                  : null,
              child: Row(
                children: [
                  Expanded(child: Text(o.text)),
                  if (poll.userOptionId != null) Text('${o.voteCount}'),
                ],
              ),
            ),
          ),
        Text('${poll.totalVotes} oy', style: Theme.of(c).textTheme.bodySmall),
      ],
    ),
  );
}

bool _quickReject(String text) {
  final n = text.toLowerCase().replaceAll(RegExp(r'[^a-zçğıöşü]'), '');
  return ['orospu', 'siktir', 'amina', 'amına', 'yarrak'].any(n.contains);
}

Map<String, dynamic> _postToJson(BulletinPost p) => {
  'id': p.id,
  'title': p.title,
  'body': p.body,
  'summary': p.summary,
  'categoryIds': p.categoryIds,
  'authorDisplayName': p.authorDisplayName,
  'authorAvatarUrl': p.authorAvatarUrl,
  'authorVerified': p.authorVerified,
  'mediaType': p.mediaType,
  'imageUrl': p.imageUrl,
  'youtubeVideoId': p.youtubeVideoId,
  'youtubeThumbnailUrl': p.youtubeThumbnailUrl,
  'publishedAt': p.publishedAt.millisecondsSinceEpoch,
  'likeCount': p.likeCount,
  'commentCount': p.commentCount,
  'liked': p.liked,
  'allowComments': p.allowComments,
  'allowLikes': p.allowLikes,
  'allowShare': p.allowShare,
};
