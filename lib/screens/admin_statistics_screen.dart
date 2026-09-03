import 'package:falora/services/statistics_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';

enum _StatsSection { users, fortunes, ads, activity }

class _StatsRange {
  const _StatsRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

class AdminStatisticsScreen extends StatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  late DateTime _start;
  late DateTime _end;
  StatisticsSnapshot? _data;
  StatisticsSnapshot? _userData;
  StatisticsSnapshot? _fortuneData;
  StatisticsSnapshot? _adData;
  StatisticsSnapshot? _activityData;
  final Map<_StatsSection, _StatsRange> _ranges = {};
  final Set<_StatsSection> _sectionLoading = {};
  String? _userPlatform;
  String? _fortuneTypeFilter;
  bool _loading = true;
  String? _error;
  late Future<int> _liveUsersFuture;

  @override
  void initState() {
    super.initState();
    _liveUsersFuture = StatisticsService.instance.loadLiveUsers();
    _today();
  }

  void _refreshLiveUsers() {
    setState(() {
      _liveUsersFuture = StatisticsService.instance.loadLiveUsers();
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    // Model alanları geliştirme sırasında değiştiğinde hot-reload eski snapshot'ı
    // bellekte tutabilir. Bir sonraki frame'de temiz veri yükle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshAllSections();
    });
  }

  DateTime get _now => DateTime.now();
  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  void _today() {
    _start = _day(_now);
    _end = _start;
    for (final section in _StatsSection.values) {
      _ranges[section] = _StatsRange(_start, _end);
    }
    _load();
  }

  Future<void> _pickRange(_StatsSection section) async {
    final current = _ranges[section]!;
    final start = await showDatePicker(
      context: context,
      locale: const Locale('tr', 'TR'),
      helpText: 'Başlangıç tarihini seçin',
      cancelText: 'İptal',
      confirmText: 'İleri',
      firstDate: DateTime(2024),
      lastDate: _day(_now),
      initialDate: current.start,
    );
    if (start == null || !mounted) return;

    final initialEnd = current.end.isBefore(start) ? start : current.end;
    final end = await showDatePicker(
      context: context,
      locale: const Locale('tr', 'TR'),
      helpText: 'Bitiş tarihini seçin',
      cancelText: 'İptal',
      confirmText: 'Uygula',
      firstDate: start,
      lastDate: _day(_now),
      initialDate: initialEnd,
    );
    if (end == null) return;
    _setSectionRange(section, _day(start), _day(end));
  }

  void _setSectionRange(_StatsSection section, DateTime start, DateTime end) {
    setState(() {
      _ranges[section] = _StatsRange(start, end);
      _sectionLoading.add(section);
    });
    _loadSection(section);
  }

  Future<void> _loadSection(_StatsSection section) async {
    final range = _ranges[section]!;
    try {
      final service = StatisticsService.instance;
      final endExclusive = range.end.add(const Duration(days: 1));
      final base = _data!;
      if (!mounted) return;
      switch (section) {
        case _StatsSection.users:
          final value = await service.loadUsers(
            range.start,
            endExclusive,
            platform: _userPlatform,
          );
          if (mounted) {
            setState(
              () => _userData = _copySnapshot(
                base,
                totalUsers: value.total,
                newUsers: value.registeredInRange,
              ),
            );
          }
        case _StatsSection.fortunes:
          final value = await service.loadFortunes(range.start, endExclusive);
          if (mounted) {
            setState(
              () =>
                  _fortuneData = _copySnapshot(base, fortunes: value.fortunes),
            );
          }
        case _StatsSection.ads:
          final value = await service.loadAds(range.start, endExclusive);
          if (mounted) {
            setState(
              () => _adData = _copySnapshot(
                base,
                adViews: value.views,
                adViewers: value.viewers,
                compensationGrants: value.compensationGrants,
                compensationUsers: value.compensationUsers,
                rewardTokenAds: value.rewardTokenAds,
                unlockAds: value.unlockAds,
                failedAds: value.failedAds,
                cancelledAds: value.cancelledAds,
                legacyUnknownAds: value.legacyUnknownAds,
                shownAds: value.shownAds,
                impressionAds: value.impressionAds,
                clickedAds: value.clickedAds,
              ),
            );
          }
        case _StatsSection.activity:
          final value = await service.loadActivity(range.start, endExclusive);
          if (mounted) {
            setState(
              () => _activityData = _copySnapshot(
                base,
                hours: value.hours,
                activeUsers: value.users,
                activeDays: value.days,
              ),
            );
          }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bu bölüm yenilenemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _sectionLoading.remove(section));
    }
  }

  Future<void> _refreshAllSections() async {
    if (_data == null) {
      await _load();
      return;
    }
    await Future.wait(_StatsSection.values.map(_loadSection));
  }

  StatisticsSnapshot _copySnapshot(
    StatisticsSnapshot base, {
    Map<String, int>? fortunes,
    int? adViews,
    int? adViewers,
    int? compensationGrants,
    int? compensationUsers,
    int? rewardTokenAds,
    int? unlockAds,
    int? failedAds,
    int? cancelledAds,
    int? legacyUnknownAds,
    int? shownAds,
    int? impressionAds,
    int? clickedAds,
    List<int>? hours,
    int? activeUsers,
    Map<DateTime, int>? activeDays,
    int? totalUsers,
    int? newUsers,
  }) => StatisticsSnapshot(
    fortunes: fortunes ?? base.fortunes,
    rewardedAds: adViews ?? base.rewardedAds,
    rewardedAdViewers: adViewers ?? base.rewardedAdViewers,
    compensationGrants: compensationGrants ?? base.compensationGrants,
    compensationUsers: compensationUsers ?? base.compensationUsers,
    rewardTokenAds: rewardTokenAds ?? base.rewardTokenAds,
    unlockAds: unlockAds ?? base.unlockAds,
    failedAds: failedAds ?? base.failedAds,
    cancelledAds: cancelledAds ?? base.cancelledAds,
    legacyUnknownAds: legacyUnknownAds ?? base.legacyUnknownAds,
    shownAds: shownAds ?? base.shownAds,
    impressionAds: impressionAds ?? base.impressionAds,
    clickedAds: clickedAds ?? base.clickedAds,
    hourlyActiveUsers: hours ?? base.hourlyActiveUsers,
    activeUsers: activeUsers ?? base.activeUsers,
    dailyActiveUsers: activeDays ?? base.dailyActiveUsers,
    totalRegisteredUsers: totalUsers ?? base.totalRegisteredUsers,
    newRegisteredUsers: newUsers ?? base.newRegisteredUsers,
  );

  void _setUserPlatform(String? platform) {
    if (_userPlatform == platform) return;
    setState(() {
      _userPlatform = platform;
      _sectionLoading.add(_StatsSection.users);
    });
    _loadSection(_StatsSection.users);
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final value = await StatisticsService.instance.load(
        _start,
        _end.add(const Duration(days: 1)),
      );
      if (mounted) {
        setState(() {
          _data = value;
          _userData = value;
          _fortuneData = value;
          _adData = value;
          _activityData = value;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'İstatistikler yüklenemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İstatistikler')),
      body: FaloraBackground(
        child: RefreshIndicator(
          onRefresh: _refreshAllSections,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_isTodaySelected) ...[
                FutureBuilder<int>(
                  future: _liveUsersFuture,
                  builder: (_, snap) {
                    if (snap.hasError) {
                      return _LiveUnavailableCard(onRetry: _refreshLiveUsers);
                    }
                    return _LiveCard(
                      count: snap.data,
                      loading: snap.connectionState == ConnectionState.waiting,
                      onRefresh: _refreshLiveUsers,
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                _ErrorCard(message: _error!, retry: _refreshAllSections)
              else
                ..._safeContent(),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isTodaySelected {
    final range = _ranges[_StatsSection.activity];
    return range?.start == _day(_now) && range?.end == _day(_now);
  }

  List<Widget> _safeContent() {
    try {
      final data = _data;
      if (data == null) return const [_EmptyText('Veri hazırlanıyor…')];
      return _content(data);
    } catch (e) {
      // Bir veri biçimi değişikliği tüm ekranı Flutter'ın kırmızı hata
      // widget'ına çevirmesin; kullanıcı yenileyebilsin.
      return [
        _ErrorCard(
          message: 'İstatistik görünümü yenilenmeli: $e',
          retry: _refreshAllSections,
        ),
      ];
    }
  }

  Widget _sectionFilters(_StatsSection section) {
    final range = _ranges[section]!;
    final today = _day(_now);
    final loading = _sectionLoading.contains(section);
    void selectDays(int days) => _setSectionRange(
      section,
      today.subtract(Duration(days: days - 1)),
      today,
    );
    final yesterday = today.subtract(const Duration(days: 1));
    var selected = 4;
    if (range.start == today && range.end == today) {
      selected = 0;
    } else if (range.start == yesterday && range.end == yesterday) {
      selected = 1;
    } else if (range.start == today.subtract(const Duration(days: 6)) &&
        range.end == today) {
      selected = 2;
    } else if (range.start == today.subtract(const Duration(days: 29)) &&
        range.end == today) {
      selected = 3;
    }
    return _ModernFilterBar(
      selectedIndex: selected,
      labels: const ['Bugün', 'Dün', '7 gün', '30 gün'],
      onSelected: (index) {
        switch (index) {
          case 0:
            selectDays(1);
          case 1:
            _setSectionRange(section, yesterday, yesterday);
          case 2:
            selectDays(7);
          case 3:
            selectDays(30);
        }
      },
      dateLabel: '${_date(range.start)} – ${_date(range.end)}',
      onDateTap: loading ? null : () => _pickRange(section),
      loading: loading,
      middle: section == _StatsSection.users
          ? DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _userPlatform ?? 'all',
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tüm cihazlar')),
                  DropdownMenuItem(value: 'android', child: Text('Android')),
                  DropdownMenuItem(value: 'ios', child: Text('iPhone')),
                ],
                onChanged: loading
                    ? null
                    : (value) =>
                          _setUserPlatform(value == 'all' ? null : value),
              ),
            )
          : section == _StatsSection.fortunes
          ? DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _fortuneFilterValue,
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('Tüm fal türleri'),
                  ),
                  ..._fortuneFilterKeys.map(
                    (key) => DropdownMenuItem(
                      value: key,
                      child: Text(
                        _pretty(key),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: loading
                    ? null
                    : (value) => setState(
                        () =>
                            _fortuneTypeFilter = value == 'all' ? null : value,
                      ),
              ),
            )
          : null,
    );
  }

  List<String> get _fortuneFilterKeys {
    final keys = (_fortuneData?.fortunes.keys ?? const <String>[]).toList();
    keys.sort((a, b) => _pretty(a).compareTo(_pretty(b)));
    return keys;
  }

  String get _fortuneFilterValue {
    final selected = _fortuneTypeFilter;
    return selected != null && _fortuneFilterKeys.contains(selected)
        ? selected
        : 'all';
  }

  List<Widget> _content(StatisticsSnapshot data) {
    final users = _userData ?? data;
    final fortunes = _fortuneData ?? data;
    final ads = _adData ?? data;
    final activity = _activityData ?? data;
    final sorted =
        fortunes.fortunes.entries
            .where(
              (entry) =>
                  _fortuneTypeFilter == null || entry.key == _fortuneTypeFilter,
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return [
      Row(
        children: [
          Expanded(
            child: _MetricCard(
              icon: Icons.auto_awesome,
              label: 'Toplam fal',
              value: '${fortunes.totalFortunes}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              icon: Icons.play_circle_outline,
              label: 'Reklam izleyen kişi',
              value: '${ads.rewardedAdViewers}',
              detail: '${ads.rewardedAds} toplam izlenme',
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _Section(
        title: 'Kullanıcı kayıtları',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionFilters(_StatsSection.users),
            const SizedBox(height: 14),
            if (users.totalRegisteredUsers < 0)
              const _InlineNotice(
                'Kullanıcı sayımı için admin yetkisi henüz etkin değil. '
                'Diğer istatistikler etkilenmeden gösteriliyor.',
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _CompactMetric(
                      label: 'Toplam kayıtlı kullanıcı',
                      value: users.totalRegisteredUsers,
                      icon: Icons.groups_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CompactMetric(
                      label: 'Bu aralıkta yeni kayıt',
                      value: users.newRegisteredUsers,
                      icon: Icons.person_add_alt_1_rounded,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _Section(
        title: 'Fal türleri',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionFilters(_StatsSection.fortunes),
            const SizedBox(height: 10),
            if (sorted.isEmpty)
              const _EmptyText('Bu tarih aralığında fal kaydı yok.')
            else
              ...sorted.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(child: Text(_pretty(e.key))),
                      Text(
                        '${e.value}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _Section(
        title: 'Reklam istatistikleri',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionFilters(_StatsSection.ads),
            const SizedBox(height: 12),
            Text(
              '${ads.rewardedAdViewers} benzersiz kişi',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text('${ads.rewardedAds} toplam reklam izleme'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CompactMetric(
                    label: 'Jeton reklamı',
                    value: ads.rewardTokenAds,
                    icon: Icons.monetization_on_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CompactMetric(
                    label: 'Evet/Hayır reklamı',
                    value: ads.unlockAds,
                    icon: Icons.lock_open_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CompactMetric(
                    label: 'Telafi alan kişi',
                    value: ads.compensationUsers,
                    icon: Icons.card_giftcard_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CompactMetric(
                    label: 'Toplam telafi işlemi',
                    value: ads.compensationGrants,
                    icon: Icons.toll_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${ads.cancelledAds} yarıda kapatıldı · ${ads.failedAds} başarısız',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              '${ads.shownAds} gösterim · ${ads.impressionAds} impression · ${ads.clickedAds} tıklama',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (ads.legacyUnknownAds > 0)
              Text(
                '${ads.legacyUnknownAds} eski kayıt belirsiz olduğu için gerçek izlenmeye eklenmedi.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF806D55)),
              ),
            const SizedBox(height: 8),
            const Text(
              'Telafi sayımı yalnızca bu özelliğin yayınlandığı sürümden sonraki kayıtları kapsar.',
              style: TextStyle(fontSize: 12, color: Color(0xFF806D55)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _Section(
        title: 'Aktif kullanıcılar ve saatler',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionFilters(_StatsSection.activity),
            const SizedBox(height: 12),
            Text(
              '${activity.activeUsers} benzersiz aktif kullanıcı',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (activity.dailyActiveUsers.length > 1) ...[
              const SizedBox(height: 10),
              _DailyActiveList(
                values: activity.dailyActiveUsers,
                dateLabel: _date,
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              'Saatlik dağılım',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _HourlyChart(values: activity.hourlyActiveUsers),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  String _pretty(String value) {
    const names = {
      'coffee': 'Kahve Falı',
      'tarot': 'Tarot',
      'water': 'Su Falı',
      'playingCards': 'İskambil',
      'bakla': 'Bakla Falı',
      'relationship': 'İlişki Falı',
    };
    return names[value] ?? value;
  }
}

class _ModernFilterBar extends StatelessWidget {
  const _ModernFilterBar({
    required this.selectedIndex,
    required this.labels,
    required this.onSelected,
    required this.dateLabel,
    required this.onDateTap,
    required this.loading,
    this.middle,
  });

  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onSelected;
  final String dateLabel;
  final VoidCallback? onDateTap;
  final bool loading;
  final Widget? middle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: faloraParchmentInset.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: faloraBronze.withValues(alpha: 0.16)),
    ),
    child: Row(
      children: [
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: selectedIndex,
              items: [
                for (var i = 0; i < labels.length; i++)
                  DropdownMenuItem(value: i, child: Text(labels[i])),
                if (selectedIndex == 4)
                  const DropdownMenuItem(value: 4, child: Text('Özel aralık')),
              ],
              onChanged: loading
                  ? null
                  : (value) {
                      if (value != null && value < labels.length) {
                        onSelected(value);
                      }
                    },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: middle ?? const SizedBox.shrink()),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDateTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(
                  children: [
                    if (loading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: faloraBronzeDark,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: faloraInkSoft,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: faloraBronze,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.count,
    required this.loading,
    required this.onRefresh,
  });
  final int? count;
  final bool loading;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF264D3B),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFF62E6A1),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CANLI',
                  style: TextStyle(
                    color: Color(0xFF9DECC2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Şu an uygulaması açık kullanıcı',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Text(
            loading ? '…' : '${count ?? 0}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: loading ? null : onRefresh,
            tooltip: 'Canlı sayısını yenile',
            color: Colors.white,
            icon: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    ),
  );
}

class _LiveUnavailableCard extends StatelessWidget {
  const _LiveUnavailableCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Colors.black54),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Canlı kullanıcı bilgisi şu anda alınamıyor.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Yenile')),
        ],
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: faloraBronzeDark),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          Text(label, style: const TextStyle(color: Colors.black54)),
          if (detail != null)
            Text(
              detail!,
              style: const TextStyle(color: Colors.black45, fontSize: 11),
            ),
        ],
      ),
    ),
  );
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: faloraBronze.withValues(alpha: 0.22)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: faloraBronzeDark, size: 22),
        const SizedBox(height: 8),
        Text(
          '$value',
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
    ),
  );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: faloraParchmentRaised,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: faloraBronze.withValues(alpha: 0.3)),
    ),
    child: Text(message, style: const TextStyle(color: Colors.black54)),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    ),
  );
}

class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.values});
  final List<int> values;
  @override
  Widget build(BuildContext context) {
    final max = values.fold<int>(0, (a, b) => a > b ? a : b);
    if (max == 0) {
      return const _EmptyText('Bu aralıkta henüz aktiflik verisi yok.');
    }
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          24,
          (i) => Expanded(
            child: Tooltip(
              message:
                  '${i.toString().padLeft(2, '0')}:00 • ${values[i]} aktif',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    values[i] == 0 ? '' : '${values[i]}',
                    style: const TextStyle(fontSize: 8),
                  ),
                  Container(
                    height: 120 * values[i] / max + 2,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: faloraBronzeDark,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    i % 3 == 0 ? i.toString().padLeft(2, '0') : '',
                    style: const TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyActiveList extends StatelessWidget {
  const _DailyActiveList({required this.values, required this.dateLabel});

  final Map<DateTime, int> values;
  final String Function(DateTime) dateLabel;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(child: Text(dateLabel(entry.key))),
                Text(
                  '${entry.value} aktif',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: const TextStyle(color: Colors.black54)),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(message),
          TextButton(onPressed: retry, child: const Text('Tekrar dene')),
        ],
      ),
    ),
  );
}
