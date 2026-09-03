import 'package:falora/community/community_models.dart';
import 'package:falora/community/community_service.dart';
import 'package:falora/config/app_links_config.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/theme/falora_design_tokens.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:falora/picked_image.dart';

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
            const SizedBox(height: 24),
            Text(
              'TOMBİK TEYZE',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bugün ne yapmak istersin?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _Pillar(
              icon: Icons.auto_awesome,
              title: 'Kişisel Fal',
              subtitle: 'Kendi fal deneyimini oluştur',
              button: 'Fala Başla',
              onTap: onOpenFortune,
            ),
            const SizedBox(height: 18),
            _Pillar(
              icon: Icons.forum_rounded,
              title: 'Fal Meclisi',
              subtitle: 'Sor, öğren ve yorumcularla buluş',
              button: 'Meclise Gir',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CommunityHomeScreen()),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Pillar extends StatelessWidget {
  const _Pillar({
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
    padding: const EdgeInsets.all(24),
    decoration: faloraParchmentDecoration(),
    child: Column(
      children: [
        Icon(icon, size: 48, color: faloraBronze),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(
            c,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
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

class CommunityHomeScreen extends StatefulWidget {
  const CommunityHomeScreen({super.key});
  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeState();
}

class _CommunityHomeState extends State<CommunityHomeScreen> {
  final _search = TextEditingController();
  List<CommunityCategory> cats = [];
  List<CommunityTopic> topics = [];
  String? selected, cursor;
  bool loading = true, more = false;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset)
      setState(() {
        loading = true;
        cursor = null;
      });
    else
      setState(() => more = true);
    try {
      if (cats.isEmpty) cats = await CommunityService.instance.categories();
      final p = await CommunityService.instance.topics(
        categoryId: selected,
        search: _search.text.trim(),
        cursor: reset ? null : cursor,
      );
      if (!mounted) return;
      setState(() {
        topics = reset ? p.items : [...topics, ...p.items];
        cursor = p.nextCursor;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted)
        setState(() {
          loading = false;
          more = false;
        });
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fal Meclisi'),
          Text(
            'Sorular, yorumlar ve deneyimler',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Tombik Teyze+',
          onPressed: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const CommunityPaywallScreen()),
          ),
          icon: const Icon(Icons.workspace_premium_outlined),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: loading ? null : _create,
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Konu aç'),
    ),
    body: FaloraBackground(
      child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: faloraParchmentDecoration(),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mecliste ne konuşuluyor?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: faloraInkHeading,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Bir konu ara veya ilgilendiğin kategoriye göz at.',
                    style: TextStyle(color: faloraInkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(reset: true),
              decoration: InputDecoration(
                hintText: 'Konularda ara',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () => _load(reset: true),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Kategoriler',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 9),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('Tümü'),
                    selected: selected == null,
                    onSelected: (_) {
                      selected = null;
                      _load(reset: true);
                    },
                  ),
                  for (final x in cats)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(x.name),
                        selected: selected == x.id,
                        onSelected: (_) {
                          selected = x.id;
                          _load(reset: true);
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (topics.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: faloraParchmentDecoration(),
                child: const Column(
                  children: [
                    Icon(Icons.forum_outlined, size: 40, color: faloraBronze),
                    SizedBox(height: 10),
                    Text(
                      'Bu kategoride henüz konu yok',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'İlk konuyu açarak sohbeti başlatabilirsin.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              for (final x in topics)
                _TopicCard(
                  topic: x,
                  onTap: () =>
                      Navigator.push(
                        c,
                        MaterialPageRoute(
                          builder: (_) => CommunityTopicScreen(id: x.id),
                        ),
                      ).then((_) {
                        _load(reset: true);
                      }),
                ),
            if (cursor != null)
              TextButton(
                onPressed: more ? null : () => _load(),
                child: Text(more ? 'Yükleniyor…' : 'Daha fazla göster'),
              ),
          ],
        ),
      ),
    ),
  );
  Future<void> _create() async {
    final premium = await CommunityService.instance.entitlement();
    if (!mounted) return;
    if (!premium) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CommunityPaywallScreen()),
      );
      return;
    }
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityCreateTopicScreen(categories: cats),
      ),
    );
    if (changed == true) _load(reset: true);
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.onTap});
  final CommunityTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: faloraBronze.withValues(alpha: .14),
              child: Text(
                topic.authorDisplayName.isEmpty
                    ? '?'
                    : topic.authorDisplayName.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: faloraBronzeDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _ForumBadge(text: topic.categoryName),
                      if (topic.resolved)
                        const _ForumBadge(
                          text: 'Çözüldü',
                          icon: Icons.check_circle_outline,
                          color: Color(0xFF47755C),
                        ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    topic.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: faloraInkHeading,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    topic.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: faloraInkSoft, height: 1.35),
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          topic.authorDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.chat_bubble_outline, size: 15),
                      const SizedBox(width: 4),
                      Text(topic.replyCount.toString()),
                      const SizedBox(width: 10),
                      const Icon(Icons.visibility_outlined, size: 15),
                      const SizedBox(width: 4),
                      Text(topic.viewCount.toString()),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('dd MMM').format(topic.createdAt),
                        style: const TextStyle(color: faloraInkSoft),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: faloraBronze),
          ],
        ),
      ),
    ),
  );
}

class _ForumBadge extends StatelessWidget {
  const _ForumBadge({
    required this.text,
    this.icon,
    this.color = faloraBronzeDark,
  });
  final String text;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class CommunityTopicScreen extends StatefulWidget {
  const CommunityTopicScreen({super.key, required this.id});
  final String id;
  @override
  State<CommunityTopicScreen> createState() => _TopicState();
}

class _TopicState extends State<CommunityTopicScreen> {
  TopicDetail? d;
  Object? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final x = await CommunityService.instance.detail(widget.id);
      if (mounted) setState(() => d = x);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Text('Konu'),
      actions: [
        PopupMenuButton<String>(
          onSelected: (v) => _report(v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'Spam', child: Text('Spam olarak bildir')),
            PopupMenuItem(
              value: 'Uygunsuz içerik',
              child: Text('Uygunsuz içerik bildir'),
            ),
          ],
        ),
      ],
    ),
    body: FaloraBackground(
      child: d == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Text('$error'),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  d!.topic.categoryName,
                  style: const TextStyle(
                    color: faloraBronze,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  d!.topic.title,
                  style: Theme.of(c).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${d!.topic.authorDisplayName} • ${DateFormat('dd.MM.yyyy HH:mm').format(d!.topic.createdAt)}',
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _ForumBadge(text: 'Seviye ${d!.topic.authorMemberLevel}', icon: Icons.workspace_premium_outlined),
                  _ForumBadge(text: d!.topic.authorMemberMonths == 0 ? 'Yeni üye' : '${d!.topic.authorMemberMonths} aydır burada', icon: Icons.calendar_month_outlined),
                  _ForumBadge(text: '${d!.topic.viewCount} görüntülenme', icon: Icons.visibility_outlined),
                  _ForumBadge(text: '${d!.topic.replyCount} yorum', icon: Icons.chat_bubble_outline),
                ]),
                const Divider(height: 30),
                Text(d!.topic.body, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 12),
                Row(children: [
                  OutlinedButton.icon(onPressed:()=>_vote(d!.topic.viewerVote==1?0:1),icon:Icon(d!.topic.viewerVote==1?Icons.thumb_up:Icons.thumb_up_outlined),label:Text('${d!.topic.likeCount}')),
                  const Spacer(),
                  OutlinedButton.icon(onPressed:()=>_vote(d!.topic.viewerVote==-1?0:-1),icon:Icon(d!.topic.viewerVote==-1?Icons.thumb_down:Icons.thumb_down_outlined),label:Text('${d!.topic.dislikeCount}')),
                ]),
                const Divider(height: 34),
                if (d!.repliesLocked)
                  _Locked(
                    onUnlock: () =>
                        Navigator.push(
                          c,
                          MaterialPageRoute(
                            builder: (_) => const CommunityPaywallScreen(),
                          ),
                        ).then((_) {
                          _load();
                        }),
                  )
                else ...[
                  Row(
                    children: [
                      Text('Cevaplar', style: Theme.of(c).textTheme.titleLarge),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _reply,
                        icon: const Icon(Icons.reply),
                        label: const Text('Cevapla'),
                      ),
                    ],
                  ),
                  for (final r in d!.replies)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.authorDisplayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (r.authorRole == 'verified_reader')
                                  const Chip(label: Text('Yorumcu ✓')),
                                if (r.isAcceptedSolution)
                                  const Chip(label: Text('✓ Çözüm')),
                              ],
                            ),
                            Text(r.body),
                            const SizedBox(height: 7),
                            Text('Seviye ${r.authorMemberLevel} • ${r.authorMemberMonths == 0 ? 'Yeni üye' : '${r.authorMemberMonths} aydır burada'}',style:Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
    ),
  );
  Future<void> _reply() async {
    final x = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cevap yaz'),
        content: TextField(controller: x, maxLength: 2000, maxLines: 6),
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
    if (ok == true && x.text.trim().isNotEmpty) {
      await CommunityService.instance.reply(widget.id, x.text);
      _load();
    }
  }

  Future<void> _vote(int value) async {
    try {
      await CommunityService.instance.vote(widget.id, value);
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _report(String reason) async {
    await CommunityService.instance.report(
      targetType: 'topic',
      targetId: widget.id,
      topicId: widget.id,
      reason: reason,
    );
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bildirimin alındı.')));
  }
}

class _Locked extends StatelessWidget {
  const _Locked({required this.onUnlock});
  final VoidCallback onUnlock;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(22),
    decoration: faloraParchmentDecoration(),
    child: Column(
      children: [
        const Icon(Icons.lock_outline, size: 38, color: faloraBronze),
        const SizedBox(height: 10),
        const Text(
          'Bu konudaki cevapları görmek için Tombik Teyze+ üyesi ol.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: onUnlock,
          child: const Text("Tombik Teyze+'a Geç"),
        ),
      ],
    ),
  );
}

class CommunityCreateTopicScreen extends StatefulWidget {
  const CommunityCreateTopicScreen({super.key, required this.categories});
  final List<CommunityCategory> categories;
  @override
  State<CommunityCreateTopicScreen> createState() => _CreateTopicState();
}

class _CreateTopicState extends State<CommunityCreateTopicScreen> {
  final title = TextEditingController();
  final body = TextEditingController();
  final images = <PickedImage>[];
  List<CommunityCategory> categories = [];
  String? categoryId;
  bool loadingCategories = true;
  bool saving = false;
  String? categoryError;

  @override
  void initState() {
    super.initState();
    categories = List.of(widget.categories);
    _loadCategories();
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (categories.isNotEmpty) {
      setState(() => loadingCategories = false);
      return;
    }
    try {
      final result = await CommunityService.instance.categories();
      if (!mounted) return;
      setState(() {
        categories = result;
        loadingCategories = false;
        categoryError = result.isEmpty
            ? 'Henüz aktif kategori bulunmuyor.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadingCategories = false;
        categoryError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yeni konu')),
    body: FaloraBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: faloraParchmentDecoration(),
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0x1A936F3D),
                  child: Icon(Icons.edit_note_rounded, color: faloraBronze),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meclise bir konu bırak',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Başlığı kısa tut, ayrıntıları açıklama alanına yaz.',
                        style: TextStyle(color: faloraInkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          if (loadingCategories)
            Container(
              height: 56,
              alignment: Alignment.center,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (categoryError != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(categoryError!)),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        loadingCategories = true;
                        categoryError = null;
                      });
                      _loadCategories();
                    },
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: categoryId,
              isExpanded: true,
              hint: const Text('Konu kategorisini seç'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: saving
                  ? null
                  : (value) => setState(() => categoryId = value),
            ),
          const SizedBox(height: 18),
          const Text('Başlık', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          TextField(
            controller: title,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Örn. Bu kart dizilimini nasıl yorumlarsınız?',
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Açıklama', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          TextField(
            controller: body,
            maxLength: 4000,
            minLines: 7,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'Sorunu, seçtiğin kartları veya merak ettiğin ayrıntıları anlat...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 4),
          _ImagePickerButton(images: images, onPick: _pick),
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Seçilen görseller: ' + images.map((x) => x.name).join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: faloraInkSoft, fontSize: 12),
              ),
            ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(saving ? 'Yayınlanıyor…' : 'Konuyu yayınla'),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _pick() async {
    if (images.length >= 3) return;
    final files = await ImagePicker().pickMultiImage(
      imageQuality: 95,
      limit: 3 - images.length,
    );
    for (final file in files) {
      images.add(PickedImage(name: file.name, bytes: await file.readAsBytes()));
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (loadingCategories) return;
    if (categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir kategori seçmelisin.')),
      );
      return;
    }
    if (title.text.trim().length < 5 || body.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Başlık ve açıklamayı biraz daha ayrıntılı yaz.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final id = await CommunityService.instance.createTopic(
        title: title.text,
        body: body.text,
        categoryId: categoryId!,
      );
      await CommunityService.instance.attachImages(id, images);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _ImagePickerButton extends StatelessWidget {
  const _ImagePickerButton({required this.images, required this.onPick});
  final List<PickedImage> images;
  final VoidCallback onPick;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: images.length >= 3 ? null : onPick,
    icon: const Icon(Icons.add_photo_alternate_outlined),
    label: Text(
      images.isEmpty
          ? 'Görsel ekle (isteğe bağlı, en fazla 3)'
          : images.length.toString() + '/3 görsel seçildi',
    ),
  );
}

class CommunityPaywallScreen extends StatefulWidget {
  const CommunityPaywallScreen({super.key});
  @override
  State<CommunityPaywallScreen> createState() => _PaywallState();
}

class _PaywallState extends State<CommunityPaywallScreen> {
  String? price;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    CommunityService.instance.subscriptionPrice().then((x) {
      if (mounted) setState(() => price = x);
    });
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Tombik Teyze+')),
    body: FaloraBackground(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.workspace_premium, size: 64, color: faloraBronze),
          Text(
            'Tombik Teyze+',
            textAlign: TextAlign.center,
            style: Theme.of(
              c,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          for (final x in [
            'Konu aç',
            'Tüm cevapları gör',
            'Yorumcuların cevaplarını gör',
            'Topluluğa cevap yaz',
            'Kart ve bakla görsellerini paylaş',
            'Çözümleri görüntüle ve etkileşimde bulun',
          ])
            ListTile(
              leading: const Icon(Icons.check_circle, color: faloraBronze),
              title: Text(x),
            ),
          const SizedBox(height: 12),
          if (price != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '$price / ay',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          FilledButton(
            onPressed: busy ? null : () => _buy(false),
            child: Text(busy ? 'İşleniyor…' : 'Abone Ol'),
          ),
          TextButton(
            onPressed: busy ? null : () => _buy(true),
            child: const Text('Satın alımları geri yükle'),
          ),
          const Text(
            'Ödeme Apple ID hesabınıza yansıtılır. Abonelik, dönem bitiminden en az 24 saat önce iptal edilmezse otomatik yenilenir. Aboneliği App Store hesap ayarlarından yönetebilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => launchUrl(Uri.parse(termsOfServiceUrl)),
                child: const Text('Kullanım Koşulları'),
              ),
              TextButton(
                onPressed: () => launchUrl(Uri.parse(privacyPolicyUrl)),
                child: const Text('Gizlilik Politikası'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Future<void> _buy(bool restore) async {
    setState(() => busy = true);
    try {
      final ok = restore
          ? await CommunityService.instance.restore()
          : await CommunityService.instance.subscribe();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Üyeliğin aktif.' : 'Aktif abonelik bulunamadı.'),
        ),
      );
      if (ok) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
