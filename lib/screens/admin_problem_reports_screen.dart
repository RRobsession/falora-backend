import 'dart:convert';

import 'package:falora/models/problem_report.dart';
import 'package:falora/services/problem_report_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String _formatAdminDate(DateTime dt) {
  final d = dt.toLocal();
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  final hour = d.hour.toString().padLeft(2, '0');
  final minute = d.minute.toString().padLeft(2, '0');
  return '$day.$month.${d.year} $hour:$minute';
}

/// Admin: kullanıcı sorun bildirimleri.
class AdminProblemReportsScreen extends StatefulWidget {
  const AdminProblemReportsScreen({super.key});

  @override
  State<AdminProblemReportsScreen> createState() =>
      _AdminProblemReportsScreenState();
}

class _AdminProblemReportsScreenState extends State<AdminProblemReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Çözülenler 1 günden eskiyse arka planda silinsin.
    ProblemReportService.instance.purgeExpiredResolvedReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sorun Bildirimleri'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Açık'),
            Tab(text: 'Çözülenler'),
          ],
        ),
      ),
      body: FaloraBackground(
        child: TabBarView(
          controller: _tabController,
          children: [
            _AdminReportsTab(
              stream: ProblemReportService.instance.watchOpenForAdmin(),
              emptyMessage: 'Açık sorun bildirimi yok.',
              showResolve: true,
            ),
            _AdminReportsTab(
              stream: ProblemReportService.instance.watchResolvedForAdmin(),
              emptyMessage: 'Çözülen sorun bildirimi yok.',
              showResolve: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminReportsTab extends StatelessWidget {
  const _AdminReportsTab({
    required this.stream,
    required this.emptyMessage,
    required this.showResolve,
  });

  final Stream<List<ProblemReport>> stream;
  final String emptyMessage;
  final bool showResolve;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProblemReport>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'Yüklenemedi: ${snap.error}',
              style: const TextStyle(color: faloraTextSecondary),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return Center(
            child: Text(
              emptyMessage,
              style: const TextStyle(color: faloraTextSecondary),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) => _AdminReportCard(
            key: ValueKey(items[i].id),
            report: items[i],
            showResolve: showResolve,
          ),
        );
      },
    );
  }
}

class _AdminReportCard extends StatefulWidget {
  const _AdminReportCard({
    super.key,
    required this.report,
    required this.showResolve,
  });

  final ProblemReport report;
  final bool showResolve;

  @override
  State<_AdminReportCard> createState() => _AdminReportCardState();
}

class _AdminReportCardState extends State<_AdminReportCard> {
  bool _resolving = false;
  bool _expanded = false;

  Future<void> _resolve() async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (adminUid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çözüldü olarak işaretle?'),
        content: const Text(
          'Bu sorun bildirimi çözülenler listesine taşınacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çözüldü'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _resolving = true);
    try {
      await ProblemReportService.instance.markResolved(
        reportId: widget.report.id,
        adminUid: adminUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sorun çözüldü olarak işaretlendi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncellenemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label kopyalandı')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final preview = report.description.length > 120
        ? '${report.description.substring(0, 120)}…'
        : report.description;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: faloraParchmentCard,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.displayName.isNotEmpty
                        ? report.displayName
                        : '(İsimsiz)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  _formatAdminDate(report.createdAt),
                  style: const TextStyle(
                    color: faloraTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _InfoRow(
              label: 'E-posta',
              value: report.userEmail.isEmpty ? '—' : report.userEmail,
              onCopy: report.userEmail.isEmpty
                  ? null
                  : () => _copy('E-posta', report.userEmail),
            ),
            _InfoRow(
              label: 'UID',
              value: report.userId,
              onCopy: () => _copy('UID', report.userId),
            ),
            if (report.platform.isNotEmpty)
              _InfoRow(label: 'Platform', value: report.platform),
            const SizedBox(height: 10),
            Text(
              _expanded ? report.description : preview,
              style: const TextStyle(height: 1.35),
            ),
            if (report.description.length > 120)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Daralt' : 'Devamını oku'),
              ),
            if (report.hasImage) ...[
              const SizedBox(height: 8),
              const Text(
                'Ekran görüntüsü',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final img in report.imageInfo)
                    if ((img['base64'] ?? '').isNotEmpty)
                      _ReportImageThumb(
                        name: img['name'] ?? 'görsel',
                        base64: img['base64']!,
                      ),
                ],
              ),
            ],
            if (report.adminNote.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Not: ${report.adminNote}',
                style: const TextStyle(color: faloraTextSecondary),
              ),
            ],
            if (widget.showResolve) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: _resolving ? null : _resolve,
                  child: _resolving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Çözüldü'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                color: faloraTextSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Kopyala',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}

class _ReportImageThumb extends StatelessWidget {
  const _ReportImageThumb({required this.name, required this.base64});

  final String name;
  final String base64;

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(base64);
      return InkWell(
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (ctx) => Dialog(
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          );
        },
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(fontSize: 10)),
          ],
        ),
      );
    } catch (_) {
      return Text(name);
    }
  }
}
