class BulletinPost {
  const BulletinPost({
    required this.id,
    required this.title,
    required this.body,
    required this.categoryIds,
    required this.authorDisplayName,
    required this.mediaType,
    required this.publishedAt,
    this.summary = '',
    this.authorAvatarUrl = '',
    this.authorVerified = false,
    this.imageUrl,
    this.youtubeVideoId,
    this.youtubeThumbnailUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.liked = false,
    this.allowComments = true,
    this.allowLikes = true,
    this.allowShare = true,
  });
  final String id,
      title,
      body,
      summary,
      authorDisplayName,
      authorAvatarUrl,
      mediaType;
  final List<String> categoryIds;
  final bool authorVerified, liked, allowComments, allowLikes, allowShare;
  final String? imageUrl, youtubeVideoId, youtubeThumbnailUrl;
  final int likeCount, commentCount;
  final DateTime publishedAt;
  factory BulletinPost.fromJson(Map<String, dynamic> j) => BulletinPost(
    id: '${j['id']}',
    title: '${j['title'] ?? ''}',
    body: '${j['body'] ?? ''}',
    summary: '${j['summary'] ?? ''}',
    categoryIds: ((j['categoryIds'] as List?) ?? []).map((x) => '$x').toList(),
    authorDisplayName: '${j['authorDisplayName'] ?? 'Tombik Teyze'}',
    authorAvatarUrl: '${j['authorAvatarUrl'] ?? ''}',
    authorVerified: j['authorVerified'] == true,
    mediaType: '${j['mediaType'] ?? 'none'}',
    imageUrl: j['imageUrl']?.toString(),
    youtubeVideoId: j['youtubeVideoId']?.toString(),
    youtubeThumbnailUrl: j['youtubeThumbnailUrl']?.toString(),
    publishedAt: DateTime.fromMillisecondsSinceEpoch(
      (j['publishedAt'] as num?)?.toInt() ?? 0,
    ),
    likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
    commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
    liked: j['liked'] == true,
    allowComments: j['allowComments'] != false,
    allowLikes: j['allowLikes'] != false,
    allowShare: j['allowShare'] != false,
  );
}

class BulletinComment {
  const BulletinComment({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.body,
    required this.createdAt,
  });
  final String id, userId, displayName, body;
  final DateTime createdAt;
  factory BulletinComment.fromJson(Map<String, dynamic> j) => BulletinComment(
    id: '${j['id']}',
    userId: '${j['userId']}',
    displayName: '${j['displayName'] ?? 'Bülten Okuru'}',
    body: '${j['body'] ?? ''}',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (j['createdAt'] as num?)?.toInt() ?? 0,
    ),
  );
}

class BulletinPollOption {
  const BulletinPollOption({
    required this.id,
    required this.text,
    required this.voteCount,
  });
  final String id, text;
  final int voteCount;
  factory BulletinPollOption.fromJson(Map<String, dynamic> j) =>
      BulletinPollOption(
        id: '${j['id']}',
        text: '${j['text']}',
        voteCount: (j['voteCount'] as num?)?.toInt() ?? 0,
      );
}

class BulletinPoll {
  const BulletinPoll({
    required this.id,
    required this.question,
    required this.options,
    required this.totalVotes,
    this.userOptionId,
  });
  final String id, question;
  final List<BulletinPollOption> options;
  final int totalVotes;
  final String? userOptionId;
  factory BulletinPoll.fromJson(Map<String, dynamic> j) => BulletinPoll(
    id: '${j['id']}',
    question: '${j['question']}',
    options: ((j['options'] as List?) ?? [])
        .map((x) => BulletinPollOption.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    totalVotes: (j['totalVotes'] as num?)?.toInt() ?? 0,
    userOptionId: j['userOptionId']?.toString(),
  );
}

class BulletinPage {
  const BulletinPage(this.items, this.cursor);
  final List<BulletinPost> items;
  final String? cursor;
}

class BulletinDetail {
  const BulletinDetail(this.post, this.comments, this.cursor);
  final BulletinPost post;
  final List<BulletinComment> comments;
  final String? cursor;
}
