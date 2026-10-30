import 'package:cloud_firestore/cloud_firestore.dart';

/// Mô hình Bài viết (Post) trên Bảng tin SupaChat
class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final String? imageUrl;
  final String? musicTrackId;
  final String? musicTrackTitle;
  final String? musicTrackArtist;
  final String? musicTrackUrl;
  final List<String> likes;
  final int commentsCount;
  final String privacy; // 'public' | 'friends'
  final DateTime createdAt;

  const PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    this.imageUrl,
    this.musicTrackId,
    this.musicTrackTitle,
    this.musicTrackArtist,
    this.musicTrackUrl,
    this.likes = const [],
    this.commentsCount = 0,
    this.privacy = 'public',
    required this.createdAt,
  });

  bool isLikedBy(String userId) => likes.contains(userId);

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return PostModel(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Thành viên SupaChat',
      authorAvatar: data['authorAvatar'] as String?,
      content: data['content'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      musicTrackId: data['musicTrackId'] as String?,
      musicTrackTitle: data['musicTrackTitle'] as String?,
      musicTrackArtist: data['musicTrackArtist'] as String?,
      musicTrackUrl: data['musicTrackUrl'] as String?,
      likes: List<String>.from(data['likes'] as List? ?? []),
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      privacy: data['privacy'] as String? ?? 'public',
      createdAt: parseTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap({bool useServerTimestamp = false}) {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'imageUrl': imageUrl,
      'musicTrackId': musicTrackId,
      'musicTrackTitle': musicTrackTitle,
      'musicTrackArtist': musicTrackArtist,
      'musicTrackUrl': musicTrackUrl,
      'likes': likes,
      'commentsCount': commentsCount,
      'privacy': privacy,
      'createdAt': useServerTimestamp ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt),
    };
  }
}

/// Mô hình Bình luận bài viết (Comment)
class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return CommentModel(
      id: doc.id,
      postId: data['postId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Thành viên',
      authorAvatar: data['authorAvatar'] as String?,
      content: data['content'] as String? ?? '',
      createdAt: parseTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap({bool useServerTimestamp = false}) {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'createdAt': useServerTimestamp ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt),
    };
  }
}

