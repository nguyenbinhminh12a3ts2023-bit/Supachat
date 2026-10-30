import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../constants/music_tracks.dart';
import '../models/post_model.dart';

/// Dịch vụ quản lý Bài viết (Post) & Bình luận (Comment)
class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
    final post = PostModel(
      id: '',
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

    final docRef = await _firestore
        .collection('posts')
        .add(post.toMap(useServerTimestamp: true))
        .timeout(const Duration(seconds: 15));

    // Thêm ngay bài viết vào bộ nhớ tạm để hiển thị ngay lập tức không cần đợi
    final newLocalPost = PostModel(
      id: docRef.id,
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
    cachedPosts = [newLocalPost, ...cachedPosts.where((p) => p.id != docRef.id)];

    return docRef.id;
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

