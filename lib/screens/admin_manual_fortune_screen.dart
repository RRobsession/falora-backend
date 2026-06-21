import 'dart:convert';



import 'package:falora/image_upload_card.dart';

import 'package:falora/models/manual_fortune_request.dart';

import 'package:falora/picked_image.dart';

import 'package:falora/services/manual_fortune_storage_service.dart';

import 'package:falora/services/notification_backend_service.dart';

import 'package:falora/theme/falora_theme.dart';

import 'package:falora/widgets/premium_ui.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

String _formatAdminDate(DateTime dt) {
  final d = dt.toLocal();
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  final hour = d.hour.toString().padLeft(2, '0');
  final minute = d.minute.toString().padLeft(2, '0');
  return '$day.$month.${d.year} $hour:$minute';
}

/// Admin girişinde manuel fal talepleri yönetilir.

class AdminManualRequestsScreen extends StatelessWidget {

  const AdminManualRequestsScreen({

    super.key,

    required this.onLogout,

  });



  final VoidCallback onLogout;



  @override

  Widget build(BuildContext context) {

    return DefaultTabController(

      length: 2,

      child: Scaffold(

        appBar: AppBar(

          title: const Text('Manuel Fal Talepleri'),

          bottom: const TabBar(

            tabs: [

              Tab(text: 'Bekleyen Talepler'),

              Tab(text: 'Cevaplananlar'),

            ],

          ),

          actions: [

            IconButton(

              onPressed: onLogout,

              icon: const Icon(Icons.logout),

              tooltip: 'Çıkış',

            ),

          ],

        ),

        body: FaloraBackground(

          child: TabBarView(

            children: [

              _AdminPendingTab(

                stream: ManualFortuneStorageService.instance.watchPendingForAdmin(),

              ),

              _AdminAnsweredTab(

                stream: ManualFortuneStorageService.instance.watchAnsweredForAdmin(),

              ),

            ],

          ),

        ),

      ),

    );

  }

}



class _AdminPendingTab extends StatelessWidget {

  const _AdminPendingTab({required this.stream});



  final Stream<List<ManualFortuneRequest>> stream;



  @override

  Widget build(BuildContext context) {

    return StreamBuilder<List<ManualFortuneRequest>>(

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

        final pending = snap.data!;

        if (pending.isEmpty) {

          return const Center(

            child: Text(

              'Bekleyen manuel fal talebi yok.',

              style: TextStyle(color: faloraTextSecondary),

            ),

          );

        }

        return ListView.builder(

          padding: const EdgeInsets.all(16),

          itemCount: pending.length,

          itemBuilder: (context, i) => _AdminPendingRequestCard(

            key: ValueKey(pending[i].id),

            request: pending[i],

          ),

        );

      },

    );

  }

}



class _AdminAnsweredTab extends StatelessWidget {

  const _AdminAnsweredTab({required this.stream});



  final Stream<List<ManualFortuneRequest>> stream;



  @override

  Widget build(BuildContext context) {

    return StreamBuilder<List<ManualFortuneRequest>>(

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

        final answered = snap.data!;

        if (answered.isEmpty) {

          return const Center(

            child: Text(

              'Henüz cevaplanmış talep yok.',

              style: TextStyle(color: faloraTextSecondary),

            ),

          );

        }

        return ListView.builder(

          padding: const EdgeInsets.all(16),

          itemCount: answered.length,

          itemBuilder: (context, i) => _AdminAnsweredRequestCard(

            key: ValueKey(answered[i].id),

            request: answered[i],

          ),

        );

      },

    );

  }

}



class _AdminPendingRequestCard extends StatefulWidget {

  const _AdminPendingRequestCard({super.key, required this.request});



  final ManualFortuneRequest request;



  @override

  State<_AdminPendingRequestCard> createState() =>

      _AdminPendingRequestCardState();

}



class _AdminPendingRequestCardState extends State<_AdminPendingRequestCard> {

  final _answerCtrl = TextEditingController();

  PickedImage? _answerImage;

  bool _submitting = false;



  @override

  void dispose() {

    _answerCtrl.dispose();

    super.dispose();

  }



  Future<void> _submit() async {

    final text = _answerCtrl.text.trim();

    if (text.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Cevap metni gerekli.')),

      );

      return;

    }



    final adminUid = FirebaseAuth.instance.currentUser?.uid;

    if (adminUid == null) return;



    setState(() => _submitting = true);

    try {

      await ManualFortuneStorageService.instance.submitAdminAnswer(

        requestId: widget.request.id,

        answerText: text,

        adminUid: adminUid,

        answerImage: _answerImage,

      );

      await NotificationBackendService.instance.notifyManualFortuneReady(

        userId: widget.request.userId,

      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Cevap gönderildi.')),

      );

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Gönderilemedi: $e')),

        );

      }

    } finally {

      if (mounted) setState(() => _submitting = false);

    }

  }



  @override

  Widget build(BuildContext context) {

    return Card(

      margin: const EdgeInsets.only(bottom: 16),

      child: Padding(

        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            _RequestSummaryHeader(request: widget.request),

            const SizedBox(height: 16),

            TextField(

              controller: _answerCtrl,

              maxLines: 8,

              decoration: const InputDecoration(

                labelText: 'Cevap yaz',

                alignLabelWithHint: true,

              ),

            ),

            const SizedBox(height: 12),

            ImageUploadCard(

              label: 'Cevap görseli (isteğe bağlı)',

              image: _answerImage,

              onChanged: (img) => setState(() => _answerImage = img),

            ),

            const SizedBox(height: 12),

            ElevatedButton(

              onPressed: _submitting ? null : _submit,

              child: _submitting

                  ? const SizedBox(

                      height: 20,

                      width: 20,

                      child: CircularProgressIndicator(strokeWidth: 2),

                    )

                  : const Text('Cevabı Gönder'),

            ),

          ],

        ),

      ),

    );

  }

}



class _AdminAnsweredRequestCard extends StatefulWidget {

  const _AdminAnsweredRequestCard({super.key, required this.request});



  final ManualFortuneRequest request;



  @override

  State<_AdminAnsweredRequestCard> createState() =>

      _AdminAnsweredRequestCardState();

}



class _AdminAnsweredRequestCardState extends State<_AdminAnsweredRequestCard> {

  final _answerCtrl = TextEditingController();

  PickedImage? _answerImage;

  bool _expanded = false;

  bool _submitting = false;



  @override

  void initState() {

    super.initState();

    _answerCtrl.text = widget.request.answerText;

  }



  @override

  void didUpdateWidget(covariant _AdminAnsweredRequestCard oldWidget) {

    super.didUpdateWidget(oldWidget);

    if (oldWidget.request.id != widget.request.id) {

      _answerCtrl.text = widget.request.answerText;

    }

  }



  @override

  void dispose() {

    _answerCtrl.dispose();

    super.dispose();

  }



  Future<void> _updateAnswer() async {

    final text = _answerCtrl.text.trim();

    if (text.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Cevap metni gerekli.')),

      );

      return;

    }



    final adminUid = FirebaseAuth.instance.currentUser?.uid;

    if (adminUid == null) return;



    setState(() => _submitting = true);

    try {

      await ManualFortuneStorageService.instance.updateAdminAnswer(

        requestId: widget.request.id,

        answerText: text,

        adminUid: adminUid,

        answerImage: _answerImage,

      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Cevap güncellendi.')),

      );

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Güncellenemedi: $e')),

        );

      }

    } finally {

      if (mounted) setState(() => _submitting = false);

    }

  }



  @override

  Widget build(BuildContext context) {

    final request = widget.request;

    return Card(

      margin: const EdgeInsets.only(bottom: 12),

      child: Column(

        children: [

          ListTile(

            title: Text(

              '${request.readerName} · ${request.category.label}',

              style: const TextStyle(fontWeight: FontWeight.w700),

            ),

            subtitle: Text(

              '${request.userEmail}\n'

              'Cevaplandı: ${request.answeredAt != null ? _formatAdminDate(request.answeredAt!) : '—'}',

              style: const TextStyle(fontSize: 12),

            ),

            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),

            onTap: () {

              setState(() => _expanded = !_expanded);

              if (!_expanded) return;

              debugPrint('ADMIN_ANSWER_DETAIL_OPEN id=${request.id}');

            },

          ),

          if (_expanded) ...[

            const Divider(height: 1),

            Padding(

              padding: const EdgeInsets.all(16),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [

                  _RequestSummaryHeader(request: request, showAnswerPreview: true),

                  if (request.answeredByAdminUid != null) ...[

                    const SizedBox(height: 8),

                    Text(

                      'Admin UID: ${request.answeredByAdminUid}',

                      style: const TextStyle(

                        color: faloraTextSecondary,

                        fontSize: 11,

                      ),

                    ),

                  ],

                  if (request.updatedAt != null) ...[

                    const SizedBox(height: 4),

                    Text(

                      'Güncellendi: ${_formatAdminDate(request.updatedAt!)}',

                      style: const TextStyle(

                        color: faloraTextSecondary,

                        fontSize: 11,

                      ),

                    ),

                  ],

                  const SizedBox(height: 16),

                  TextField(

                    controller: _answerCtrl,

                    maxLines: 8,

                    decoration: const InputDecoration(

                      labelText: 'Cevabı düzenle',

                      alignLabelWithHint: true,

                    ),

                  ),

                  const SizedBox(height: 12),

                  ImageUploadCard(

                    label: 'Yeni cevap görseli (isteğe bağlı)',

                    image: _answerImage,

                    onChanged: (img) => setState(() => _answerImage = img),

                  ),

                  const SizedBox(height: 12),

                  ElevatedButton(

                    onPressed: _submitting ? null : _updateAnswer,

                    child: _submitting

                        ? const SizedBox(

                            height: 20,

                            width: 20,

                            child: CircularProgressIndicator(strokeWidth: 2),

                          )

                        : const Text('Cevabı Güncelle'),

                  ),

                ],

              ),

            ),

          ],

        ],

      ),

    );

  }

}



class _RequestSummaryHeader extends StatelessWidget {

  const _RequestSummaryHeader({

    required this.request,

    this.showAnswerPreview = false,

  });



  final ManualFortuneRequest request;

  final bool showAnswerPreview;



  @override

  Widget build(BuildContext context) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        Text(

          '${request.readerName} · ${request.category.label}',

          style: const TextStyle(

            fontWeight: FontWeight.w800,

            fontSize: 17,

            color: faloraTextPrimary,

          ),

        ),

        if (request.tokenCost > 0) ...[

          const SizedBox(height: 4),

          Text(

            '${request.tokenCost} Jeton · ${request.questionLimit} soru',

            style: const TextStyle(

              color: faloraGold,

              fontSize: 12,

              fontWeight: FontWeight.w600,

            ),

          ),

        ] else if (request.priceTRY > 0) ...[

          const SizedBox(height: 4),

          Text(

            '${request.priceTRY} TL · ${request.questionLimit} soru',

            style: const TextStyle(

              color: faloraGold,

              fontSize: 12,

              fontWeight: FontWeight.w600,

            ),

          ),

        ],

        const SizedBox(height: 6),

        Text(

          '${request.name}, ${request.age}, ${request.zodiac}',

          style: const TextStyle(color: faloraTextSecondary),

        ),

        const SizedBox(height: 4),

        Text(

          request.userEmail,

          style: const TextStyle(color: faloraTextSecondary, fontSize: 12),

        ),

        if (request.intention.trim().isNotEmpty) ...[

          const SizedBox(height: 10),

          Text('Niyet: ${request.intention}'),

        ],

        const SizedBox(height: 12),

        for (var i = 0; i < request.questions.length; i++)

          Padding(

            padding: const EdgeInsets.only(bottom: 6),

            child: Text('Soru ${i + 1}: ${request.questions[i]}'),

          ),

        if (request.imageInfo.isNotEmpty) ...[

          const SizedBox(height: 12),

          const Text('Fotoğraflar', style: TextStyle(fontWeight: FontWeight.w600)),

          const SizedBox(height: 8),

          Wrap(

            spacing: 8,

            runSpacing: 8,

            children: [

              for (final img in request.imageInfo)

                if ((img['base64'] ?? '').isNotEmpty)

                  _ImageThumb(

                    name: img['name'] ?? 'foto',

                    base64: img['base64']!,

                  ),

            ],

          ),

        ],

        if (showAnswerPreview && request.answerText.trim().isNotEmpty) ...[

          const SizedBox(height: 16),

          const Text(

            'Mevcut Cevap',

            style: TextStyle(fontWeight: FontWeight.w700, color: faloraGold),

          ),

          const SizedBox(height: 8),

          Text(request.answerText),

        ],

        if (showAnswerPreview &&

            request.answerImageInfo['base64']?.isNotEmpty == true) ...[

          const SizedBox(height: 12),

          const Text('Cevap Görseli', style: TextStyle(fontWeight: FontWeight.w600)),

          const SizedBox(height: 8),

          _ImageThumb(

            name: request.answerImageInfo['name'] ?? 'cevap',

            base64: request.answerImageInfo['base64']!,

          ),

        ],

      ],

    );

  }

}



class _ImageThumb extends StatelessWidget {

  const _ImageThumb({required this.name, required this.base64});



  final String name;

  final String base64;



  @override

  Widget build(BuildContext context) {

    try {

      final bytes = base64Decode(base64);

      return Column(

        children: [

          ClipRRect(

            borderRadius: BorderRadius.circular(8),

            child: Image.memory(bytes, width: 88, height: 88, fit: BoxFit.cover),

          ),

          const SizedBox(height: 4),

          Text(name, style: const TextStyle(fontSize: 10)),

        ],

      );

    } catch (_) {

      return Text(name);

    }

  }

}



typedef AdminManualFortuneScreen = AdminManualRequestsScreen;


