class CommunityCategory {
  const CommunityCategory({required this.id, required this.name, this.description = '', this.icon = 'forum'});
  final String id, name, description, icon;
  factory CommunityCategory.fromJson(Map<String, dynamic> json) => CommunityCategory(
    id: '${json['id']}', name: '${json['name'] ?? ''}',
    description: '${json['description'] ?? ''}', icon: '${json['icon'] ?? 'forum'}',
  );
}

class CommunityTopic {
  const CommunityTopic({required this.id, required this.title, required this.body,
    required this.categoryName, required this.authorDisplayName, required this.createdAt,
    this.replyCount = 0, this.viewCount = 0, this.likeCount = 0, this.dislikeCount = 0,
    this.viewerVote = 0, this.authorJoinedAt, this.authorMemberLevel = 1,
    this.resolved = false, this.acceptedAnswerId,
    this.imageUrls = const []});
  final String id, title, body, categoryName, authorDisplayName;
  final DateTime createdAt;
  final int replyCount, viewCount, likeCount, dislikeCount, viewerVote;
  final DateTime? authorJoinedAt;
  final int authorMemberLevel;
  final bool resolved;
  final String? acceptedAnswerId;
  final List<String> imageUrls;
  factory CommunityTopic.fromJson(Map<String, dynamic> json) => CommunityTopic(
    id: '${json['id']}', title: '${json['title'] ?? ''}', body: '${json['body'] ?? ''}',
    categoryName: '${json['categoryName'] ?? ''}',
    authorDisplayName: '${json['authorDisplayName'] ?? 'Meclis Üyesi'}',
    createdAt: DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as num?)?.toInt() ?? 0),
    replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
    viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    dislikeCount: (json['dislikeCount'] as num?)?.toInt() ?? 0,
    viewerVote: (json['viewerVote'] as num?)?.toInt() ?? 0,
    authorJoinedAt: (json['authorJoinedAt'] as num?) == null ? null : DateTime.fromMillisecondsSinceEpoch((json['authorJoinedAt'] as num).toInt()),
    authorMemberLevel: (json['authorMemberLevel'] as num?)?.toInt() ?? 1,
    resolved: json['resolved'] == true, acceptedAnswerId: json['acceptedAnswerId']?.toString(),
    imageUrls: ((json['imageUrls'] as List?) ?? []).map((x) => x.toString()).toList(),
  );
}

class CommunityReply {
  const CommunityReply({required this.id, required this.authorDisplayName, required this.body,
    required this.createdAt, this.authorRole = 'member', this.authorJoinedAt,
    this.authorMemberLevel = 1, this.isAcceptedSolution = false});
  final String id, authorDisplayName, body, authorRole;
  final DateTime createdAt;
  final DateTime? authorJoinedAt;
  final int authorMemberLevel;
  final bool isAcceptedSolution;
  factory CommunityReply.fromJson(Map<String, dynamic> json) => CommunityReply(
    id: '${json['id']}', authorDisplayName: '${json['authorDisplayName'] ?? 'Meclis Üyesi'}',
    body: '${json['body'] ?? ''}',
    createdAt: DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as num?)?.toInt() ?? 0),
    authorRole: '${json['authorRole'] ?? 'member'}',
    authorJoinedAt: (json['authorJoinedAt'] as num?) == null ? null : DateTime.fromMillisecondsSinceEpoch((json['authorJoinedAt'] as num).toInt()),
    authorMemberLevel: (json['authorMemberLevel'] as num?)?.toInt() ?? 1,
    isAcceptedSolution: json['isAcceptedSolution'] == true,
  );
}

class TopicPage { const TopicPage(this.items, this.nextCursor); final List<CommunityTopic> items; final String? nextCursor; }
class TopicDetail { const TopicDetail({required this.topic, required this.replies, required this.repliesLocked, required this.isPremium}); final CommunityTopic topic; final List<CommunityReply> replies; final bool repliesLocked, isPremium; }
