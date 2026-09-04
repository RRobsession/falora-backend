import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:flutter/material.dart';

class SupportMessageBubble extends StatelessWidget {
  const SupportMessageBubble({
    super.key,
    required this.message,
    required this.viewerIsAdmin,
  });

  final Map<String, dynamic> message;
  final bool viewerIsAdmin;

  String _timeLabel(dynamic value) {
    final DateTime? date = switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      _ => null,
    };
    if (date == null) return 'Şimdi';
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final fromAdmin = message['senderRole'] == 'admin';
    final isMine = viewerIsAdmin ? fromAdmin : !fromAdmin;
    final label = fromAdmin ? 'Destek ekibi' : (isMine ? 'Sen' : 'Kullanıcı');
    final foreground = isMine ? faloraParchmentRaised : faloraInk;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
        decoration: BoxDecoration(
          color: isMine ? faloraBronze : faloraParchmentInset,
          border: isMine
              ? null
              : Border.all(color: faloraGoldMuted.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(isMine ? 17 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 17),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  fromAdmin
                      ? Icons.support_agent_rounded
                      : Icons.person_outline_rounded,
                  size: 14,
                  color: foreground.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${message['text'] ?? ''}',
              style: TextStyle(color: foreground, height: 1.35),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _timeLabel(message['createdAt']),
                style: TextStyle(
                  color: foreground.withValues(alpha: 0.72),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
