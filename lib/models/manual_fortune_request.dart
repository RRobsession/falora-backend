import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:falora/models/fortune_models.dart';



/// Firestore `manual_fortune_requests` kaydı.

class ManualFortuneRequest {

  const ManualFortuneRequest({

    required this.id,

    required this.userId,

    required this.userEmail,

    required this.fortuneType,

    required this.readerId,

    required this.readerName,

    required this.priceTRY,

    required this.productId,

    required this.questionLimit,

    required this.requiresIntention,

    required this.status,

    required this.name,

    required this.age,

    required this.zodiac,

    required this.intention,

    required this.questions,

    required this.createdAt,

    this.imageInfo = const [],

    this.answerImageInfo = const {},

    this.answeredAt,

    this.answerText = '',

    this.answeredByAdminUid,

    this.updatedAt,

    this.purchaseToken = '',

    this.paymentStatus = '',

  });



  final String id;

  final String userId;

  final String userEmail;

  final String fortuneType;

  final String readerId;

  final String readerName;

  final int priceTRY;

  final String productId;

  final int questionLimit;

  final bool requiresIntention;

  final String status;

  final String name;

  final int age;

  final String zodiac;

  final String intention;

  final List<String> questions;

  final List<Map<String, String>> imageInfo;

  final Map<String, String> answerImageInfo;

  final DateTime createdAt;

  final DateTime? answeredAt;

  final String answerText;

  final String? answeredByAdminUid;

  final DateTime? updatedAt;

  final String purchaseToken;

  final String paymentStatus;



  bool get isAnswered => status == 'answered' && answerText.trim().isNotEmpty;



  FortuneCategory get category {

    return FortuneCategory.values.firstWhere(

      (c) => c.name == fortuneType,

      orElse: () => FortuneCategory.tarot,

    );

  }



  FortuneReading toFortuneReading() {

    final niyetLine = intention.trim().isEmpty

        ? ''

        : '\nNiyet: $intention';

    final summary = '${category.label} — $readerName (Özel)\n'

        '$name, $age, $zodiac$niyetLine';

    return FortuneReading(

      id: id,

      category: category,

      status: isAnswered ? FortuneStatus.hazir : FortuneStatus.hazirlaniyor,

      createdAt: createdAt,

      summary: summary,

      result: answerText,

      firestoreStatus: status,

      isManualPremium: true,

      manualReaderName: readerName,

    );

  }



  factory ManualFortuneRequest.fromFirestore(

    String id,

    Map<String, dynamic> data,

  ) {

    final questionsRaw = data['questions'];

    final questions = questionsRaw is List

        ? questionsRaw.map((e) => e.toString()).toList()

        : <String>[];



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



    final answerImgRaw = data['answerImageInfo'];

    final answerImageInfo = <String, String>{};

    if (answerImgRaw is Map) {

      answerImgRaw.forEach((k, v) {

        answerImageInfo[k.toString()] = v?.toString() ?? '';

      });

    }



    return ManualFortuneRequest(

      id: id,

      userId: data['userId'] as String? ?? '',

      userEmail: data['userEmail'] as String? ?? '',

      fortuneType: data['fortuneType'] as String? ?? 'tarot',

      readerId: data['readerId'] as String? ?? '',

      readerName: data['readerName'] as String? ?? '',

      priceTRY: (data['priceTRY'] as num?)?.toInt() ?? 0,

      productId: (data['productId'] as String?) ??

          (data['priceProductId'] as String? ?? ''),

      questionLimit: (data['questionLimit'] as num?)?.toInt() ??

          questions.length,

      requiresIntention: data['requiresIntention'] as bool? ?? true,

      status: data['status'] as String? ?? 'pending',

      name: data['name'] as String? ?? '',

      age: (data['age'] as num?)?.toInt() ?? 0,

      zodiac: data['zodiac'] as String? ?? '',

      intention: data['intention'] as String? ?? '',

      questions: questions,

      imageInfo: imageInfo,

      answerImageInfo: answerImageInfo,

      createdAt: _parseTs(data['createdAt']),

      answeredAt: data['answeredAt'] != null ? _parseTs(data['answeredAt']) : null,

      answerText: data['answerText'] as String? ?? '',

      answeredByAdminUid: data['answeredByAdminUid'] as String?,

      updatedAt: data['updatedAt'] != null ? _parseTs(data['updatedAt']) : null,

      purchaseToken: data['purchaseToken'] as String? ?? '',

      paymentStatus: data['paymentStatus'] as String? ?? '',

    );

  }



  static DateTime _parseTs(dynamic value) {

    if (value is Timestamp) return value.toDate();

    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();

    return DateTime.now();

  }

}

