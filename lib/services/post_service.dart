import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../constants/music_tracks.dart';
import '../models/post_model.dart';
import 'firestore_helper.dart';

/// Dịch vụ quản lý Bài viết (Post) & Bình luận (Comment)
class PostService {
  FirebaseFirestore get _firestore => AppFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static List<PostModel> cachedPosts = [];

  String? get currentUserId => _auth.currentUser?.uid;

  /// Luồng lấy danh sách bài viết thời gian thực (Mới nhất lên đầu)
  Stream<List<PostModel>> getPostsStream() async* {
    if (cachedPosts.isNotEmpty) {
      yield cachedPosts;
    }
    try {
      yield* _firestore
          .collection('posts')
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        cachedPosts = list;
        return list;
      });
    } catch (e) {
      debugPrint('Lưu ý getPostsStream: $e');
      yield cachedPosts;
    }
  }

  /// Đồng bộ cập nhật ảnh đại diện tác giả bài viết
  Future<void> syncPostAuthorAvatar(String postId, String newAvatar) async {
    try {
      await _firestore.collection('posts').doc(postId).update({'authorAvatar': newAvatar});
    } catch (_) {}
  }

  /// Đăng bài viết mới lên bảng tin
  Future<String> createPost({
    required String content,
    String? imageUrl,
    MusicTrack? musicTrack,
    String privacy = 'public',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Người dùng chưa đăng nhập');

    // Lấy thông tin người dùng từ Firestore users để avatar/tên chuẩn xác nhất
    String authorName = user.displayName ?? user.email?.split('@').first ?? 'Thành viên SupaChat';
    String? authorAvatar = user.photoURL;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get().timeout(const Duration(seconds: 4));
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          authorName = data['displayName'] as String? ?? authorName;
          authorAvatar = data['photoUrl'] as String? ?? authorAvatar;
        }
      }
    } catch (_) {}

    final now = DateTime.now();
    final newId = 'post_${now.millisecondsSinceEpoch}_${user.uid.substring(0, 5)}';

    final post = PostModel(
      id: newId,
      authorId: user.uid,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content.trim(),
      imageUrl: imageUrl,
      musicTrackId: musicTrack?.id,
      musicTrackTitle: musicTrack?.title,
      musicTrackArtist: musicTrack?.artist,
      musicTrackUrl: musicTrack?.audioUrl,
      likes: const [],
      commentsCount: 0,
      privacy: privacy,
      createdAt: now,
    );

    // Thêm ngay bài viết vào bộ nhớ tạm để hiển thị ngay lập tức không cần đợi
    cachedPosts = [post, ...cachedPosts.where((p) => p.id != newId)];

    // Lưu lên Firestore với timeout an toàn 6 giây
    try {
      await _firestore
          .collection('posts')
          .doc(newId)
          .set(post.toMap(useServerTimestamp: true))
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('Lưu ý đồng bộ Firestore post: $e');
    }

    return newId;
  }

  /// Thả tim / Bỏ tim bài viết
  Future<void> toggleLikePost(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final doc = await postRef.get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final likes = List<String>.from(data['likes'] as List? ?? []);

    if (likes.contains(userId)) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([userId]),
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([userId]),
      });
      // Tạo thông báo cho chủ bài viết
      final authorId = data['authorId'] as String?;
      if (authorId != null && authorId != userId) {
        final myName = _auth.currentUser?.displayName ?? 'Một người dùng';
        try {
          await _firestore.collection('users').doc(authorId).collection('notifications').add({
            'type': 'like_post',
            'title': 'Lượt thích bài viết',
            'body': '$myName đã thả tim bài viết của bạn.',
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        } catch (_) {}
      }
    }
  }

  /// Xóa bài viết (Chỉ chủ bài viết mới được xóa)
  Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final doc = await postRef.get();
    if (!doc.exists) return;

    final authorId = doc.data()?['authorId'] as String?;
    if (authorId == user.uid) {
      await postRef.delete();
    }
  }

  /// Thêm bình luận vào bài viết
  Future<void> addComment({
    required String postId,
    required String content,
  }) async {
    final user = _auth.currentUser;
    if (user == null || content.trim().isEmpty) return;

    String authorName = user.displayName ?? 'Thành viên';
    String? authorAvatar = user.photoURL;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          authorName = data['displayName'] as String? ?? authorName;
          authorAvatar = data['photoUrl'] as String? ?? authorAvatar;
        }
      }
    } catch (_) {}

    final comment = CommentModel(
      id: '',
      postId: postId,
      authorId: user.uid,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content.trim(),
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc();

    batch.set(commentRef, comment.toMap(useServerTimestamp: true));
    batch.update(_firestore.collection('posts').doc(postId), {
      'commentsCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Luồng lấy danh sách bình luận của bài viết
  Stream<List<CommentModel>> getCommentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CommentModel.fromFirestore(doc)).toList();
    });
  }
}

