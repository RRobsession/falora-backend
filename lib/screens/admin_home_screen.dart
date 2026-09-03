import 'dart:math' as math;

import 'package:falora/screens/admin_angel_cards_screen.dart';
import 'package:falora/screens/admin_broadcast_notification_screen.dart';
import 'package:falora/screens/admin_daily_horoscope_screen.dart';
import 'package:falora/screens/admin_grant_tokens_screen.dart';
import 'package:falora/screens/admin_manual_fortune_screen.dart';
import 'package:falora/screens/admin_manual_reader_status_screen.dart';
import 'package:falora/screens/admin_problem_reports_screen.dart';
import 'package:falora/screens/admin_statistics_screen.dart';
import 'package:falora/screens/admin_token_sales_screen.dart';
import 'package:falora/bulletin/admin_bulletin_screen.dart';
import 'package:falora/services/manual_fortune_storage_service.dart';
import 'package:falora/services/notification_service.dart';
import 'package:falora/services/problem_report_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';

class _AdminCategory {
  const _AdminCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onOpen,
    this.badgeStream,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onOpen;
  final Stream<int>? badgeStream;
}

/// Admin giriş — ekranı dolduran bento (dikey + kare oranları).
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  VoidCallback? _notificationListener;
  late final AnimationController _enterCtrl;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();

    _notificationListener = _onPendingAdminNotification;
    NotificationService.instance.pendingOpenRequest.addListener(
      _notificationListener!,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onPendingAdminNotification();
    });
    // Admin panele girince eski çözülen sorunları temizle.
    ProblemReportService.instance.purgeExpiredResolvedReports();
  }

  @override
  void dispose() {
    if (_notificationListener != null) {
      NotificationService.instance.pendingOpenRequest.removeListener(
        _notificationListener!,
      );
    }
    _enterCtrl.dispose();
    super.dispose();
  }

  void _onPendingAdminNotification() {
    final pending = NotificationService.instance.pendingOpenRequest.value;
    if (pending?.isValid != true) return;

    final type = pending!.type;
    if (type != 'admin_manual_request' &&
        type != 'admin_problem_report' &&
        type != 'admin_token_purchase') {
      return;
    }
    NotificationService.instance.consumePendingOpenRequest();
    if (!mounted) return;

    switch (type) {
      case 'admin_manual_request':
        _openManualFortunes();
        _showAdminNotificationMessage('Serdar veya Hatice’ye yeni fal geldi.');
      case 'admin_problem_report':
        _push(const AdminProblemReportsScreen());
        _showAdminNotificationMessage('Yeni sorun bildirimi geldi.');
      case 'admin_token_purchase':
        _push(const AdminTokenSalesScreen());
        _showAdminNotificationMessage('Yeni jeton satın alımı geldi.');
    }
  }

  void _showAdminNotificationMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openManualFortunes() {
    _push(const AdminManualRequestsScreen());
  }

  @override
  Widget build(BuildContext context) {
    final cats = <_AdminCategory>[
      _AdminCategory(
        title: 'İstatistik',
        subtitle: 'Fal, reklam ve canlı kullanım',
        icon: Icons.query_stats_rounded,
        accent: const Color(0xFF356B55),
        onOpen: () => _push(const AdminStatisticsScreen()),
      ),
      _AdminCategory(
        title: 'Manuel Fal',
        subtitle: 'Bekleyen ve cevaplanan talepler',
        icon: Icons.menu_book_rounded,
        accent: faloraBronzeDark,
        onOpen: _openManualFortunes,
        badgeStream: ManualFortuneStorageService.instance
            .watchPendingForAdmin()
            .map((list) => list.length),
      ),
      _AdminCategory(
        title: 'Sorunlar',
        subtitle: 'Kullanıcı sorun bildirimleri',
        icon: Icons.report_problem_outlined,
        accent: const Color(0xFF8B3A3A),
        onOpen: () => _push(const AdminProblemReportsScreen()),
        badgeStream: ProblemReportService.instance.watchOpenForAdmin().map(
          (list) => list.length,
        ),
      ),
      _AdminCategory(
        title: 'Günlük Burç',
        subtitle: '12 burç yorumunu yayınla',
        icon: Icons.auto_awesome,
        accent: faloraGoldReadable,
        onOpen: () => _push(const AdminDailyHoroscopeScreen()),
      ),
      _AdminCategory(
        title: 'Falcılar',
        subtitle: 'Serdar & Hatice durumu',
        icon: Icons.manage_accounts_outlined,
        accent: faloraInkHeading,
        onOpen: () => _push(const AdminManualReaderStatusScreen()),
      ),
      _AdminCategory(
        title: 'Jeton',
        subtitle: 'E-posta ile yükle',
        icon: Icons.monetization_on_outlined,
        accent: faloraGoldDark,
        onOpen: () => _push(const AdminGrantTokensScreen()),
      ),
      _AdminCategory(
        title: 'Jeton Satışları',
        subtitle: 'Google Play siparişleri ve GPA kimlikleri',
        icon: Icons.receipt_long_outlined,
        accent: const Color(0xFF2E6F73),
        onOpen: () => _push(const AdminTokenSalesScreen()),
      ),
      _AdminCategory(
        title: 'Bildirim',
        subtitle: 'Herkese toplu gönder',
        icon: Icons.campaign_outlined,
        accent: faloraBronze,
        onOpen: () => _push(const AdminBroadcastNotificationScreen()),
      ),
      _AdminCategory(
        title: 'Melek Kartı',
        subtitle: 'Gruplara farklı kart bildirimi',
        icon: Icons.brightness_5_outlined,
        accent: const Color(0xFF5C6B8A),
        onOpen: () => _push(const AdminAngelCardsScreen()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış',
          ),
        ],
      ),
      body: FaloraBackground(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final maxW = wide ? 760.0 : constraints.maxWidth;
              const gap = 8.0;
              final hPad = wide ? 20.0 : 14.0;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxW,
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Uygulama Yönetimi',
                                style: FaloraTypography.titleLarge.copyWith(
                                  fontSize: wide ? 22 : 20,
                                  color: faloraInkHeading,
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () =>
                                  _push(const AdminBulletinScreen()),
                              icon: const Icon(Icons.auto_stories_outlined),
                              label: const Text('Bülten'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bir alana dokunarak devam et',
                          style: TextStyle(
                            color: faloraInkSoft.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                flex: 11,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: _BentoCard(
                                        category: cats[0],
                                        animation: _enterCtrl,
                                        index: 0,
                                      ),
                                    ),
                                    const SizedBox(width: gap),
                                    Expanded(
                                      flex: 6,
                                      child: _BentoCard(
                                        category: cats[1],
                                        animation: _enterCtrl,
                                        index: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: gap),
                              Expanded(
                                flex: 10,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: 7,
                                      child: _BentoCard(
                                        category: cats[2],
                                        animation: _enterCtrl,
                                        index: 2,
                                        horizontal: true,
                                      ),
                                    ),
                                    const SizedBox(width: gap),
                                    Expanded(
                                      flex: 4,
                                      child: _BentoCard(
                                        category: cats[3],
                                        animation: _enterCtrl,
                                        index: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: gap),
                              Expanded(
                                flex: 8,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: _BentoCard(
                                        category: cats[4],
                                        animation: _enterCtrl,
                                        index: 4,
                                      ),
                                    ),
                                    const SizedBox(width: gap),
                                    Expanded(
                                      flex: 6,
                                      child: _BentoCard(
                                        category: cats[5],
                                        animation: _enterCtrl,
                                        index: 5,
                                        horizontal: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: gap),
                              Expanded(
                                flex: 7,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 6; i < cats.length; i++) ...[
                                      if (i > 6) const SizedBox(width: gap),
                                      Expanded(
                                        child: _BentoCard(
                                          category: cats[i],
                                          animation: _enterCtrl,
                                          index: i,
                                          horizontal: cats.length == 7,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({
    required this.category,
    required this.animation,
    required this.index,
    this.horizontal = false,
  });

  final _AdminCategory category;
  final Animation<double> animation;
  final int index;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.07).clamp(0.0, 0.5);
    final end = (start + 0.42).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    Widget badge = const SizedBox.shrink();
    if (category.badgeStream != null) {
      badge = StreamBuilder<int>(
        stream: category.badgeStream,
        builder: (context, snap) {
          final count = snap.data ?? 0;
          if (count <= 0) return const SizedBox.shrink();
          return _CountBadge(count: count);
        },
      );
    }

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTap(
          onTap: category.onOpen,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  faloraParchmentRaised,
                  Color.lerp(faloraParchmentCard, category.accent, 0.08)!,
                ],
              ),
              border: Border.all(color: faloraBronze.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: horizontal
                  ? _HorizontalCardBody(category: category, badge: badge)
                  : _VerticalCardBody(category: category, badge: badge),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalCardBody extends StatelessWidget {
  const _VerticalCardBody({required this.category, required this.badge});

  final _AdminCategory category;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardHeader(title: category.title, badge: badge),
        const SizedBox(height: 4),
        Text(
          category.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.28,
            color: faloraInkSoft.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _VisualStage(icon: category.icon, accent: category.accent),
        ),
      ],
    );
  }
}

class _HorizontalCardBody extends StatelessWidget {
  const _HorizontalCardBody({required this.category, required this.badge});

  final _AdminCategory category;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(title: category.title, badge: badge),
              const SizedBox(height: 4),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    category.subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: faloraInkSoft.withValues(alpha: 0.88),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: _VisualStage(icon: category.icon, accent: category.accent),
        ),
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.badge});

  final String title;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: FaloraTypography.displayFamily,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: faloraInkHeading,
              height: 1.1,
            ),
          ),
        ),
        badge,
        const SizedBox(width: 4),
        Icon(
          Icons.north_east_rounded,
          size: 17,
          color: faloraInkMuted.withValues(alpha: 0.65),
        ),
      ],
    );
  }
}

/// Kartın kalan alanını dolduran dengeli görsel sahne.
class _VisualStage extends StatelessWidget {
  const _VisualStage({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final ring = side * 0.88;
        final iconSize = (side * 0.34).clamp(28.0, 56.0);

        return Center(
          child: SizedBox(
            width: ring,
            height: ring,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: ring,
                  height: ring,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.16),
                        accent.withValues(alpha: 0.04),
                        accent.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                Container(
                  width: ring * 0.62,
                  height: ring * 0.62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.18),
                      width: 1.2,
                    ),
                    color: faloraParchmentRaised.withValues(alpha: 0.45),
                  ),
                ),
                Container(
                  width: ring * 0.38,
                  height: ring * 0.38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(faloraParchmentRaised, accent, 0.12)!,
                        Color.lerp(faloraParchmentCard, accent, 0.22)!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: iconSize * 0.72, color: accent),
                ),
                // Küçük denge noktaları
                Positioned(
                  top: ring * 0.08,
                  right: ring * 0.14,
                  child: _Dot(color: accent, size: 6),
                ),
                Positioned(
                  bottom: ring * 0.12,
                  left: ring * 0.1,
                  child: _Dot(color: accent, size: 4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.35),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: faloraBronzeDark,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: faloraParchmentRaised,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
