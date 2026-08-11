import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `problem_reports` kaydı.
class ProblemReport {
  const ProblemReport({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.displayName,
    required this.description,
    required this.status,
    required this.createdAt,
    this.platform = '',
    this.imageInfo = const [],
    this.updatedAt,
    this.resolvedAt,
    this.resolvedByAdminUid = '',
    this.adminNote = '',
  });

  final String id;
  final String userId;
  final String userEmail;
  final String displayName;
  final String description;
  final String status;
  final String platform;
  final List<Map<String, String>> imageInfo;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final String resolvedByAdminUid;
  final String adminNote;

  bool get isOpen => status == 'open';
  bool get hasImage =>
      imageInfo.any((img) => (img['base64'] ?? '').trim().isNotEmpty);

  factory ProblemReport.fromFirestore(String id, Map<String, dynamic> data) {
    final imageRaw = data['imageInfo'];
    final imageInfo = <Map<String, String>>[];
    if (imageRaw is List) {
      for (final item in imageRaw) {
        if (item is Map) {
          imageInfo.add(
            item.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
          );
        }
      }
    }

    return ProblemReport(
      id: id,
      userId: data['userId']?.toString() ?? '',
      userEmail: data['userEmail']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      status: data['status']?.toString() ?? 'open',
      platform: data['platform']?.toString() ?? '',
      imageInfo: imageInfo,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: data['updatedAt'] != null ? _parseDate(data['updatedAt']) : null,
      resolvedAt:
          data['resolvedAt'] != null ? _parseDate(data['resolvedAt']) : null,
      resolvedByAdminUid: data['resolvedByAdminUid']?.toString() ?? '',
      adminNote: data['adminNote']?.toString() ?? '',
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
