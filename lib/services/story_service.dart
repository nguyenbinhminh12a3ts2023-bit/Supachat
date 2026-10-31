import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../constants/music_tracks.dart';
import '../models/story_model.dart';

/// Dịch vụ quản lý Tin 24h (Story)
class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static List<StoryModel> cachedStories = [];

  String? get currentUserId => _auth.currentUser?.uid;

  /// Đếm số tin người dùng hiện tại đã đăng trong vòng 24 giờ qua (Giới hạn tối đa 5 tin/ngày)
  Future<int> getTodayStoriesCount(String userId) async {
    final oneDayAgo = DateTime.now().subtract(const Duration(hours: 24));
    final localCount = cachedStories.where((s) => s.userId == userId && s.createdAt.isAfter(oneDayAgo)).length;
    if (localCount > 0) return localCount;

    try {
      final snap = await _firestore
          .collection('stories')
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 4));
      
      final count = snap.docs.where((doc) {
        final data = doc.data();
        final ts = data['createdAt'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();
        return dt != null && dt.isAfter(oneDayAgo);
      }).length;
      return count;
    } catch (_) {
      return localCount;
    }
  }

  /// Luồng lấy toàn bộ tin còn hạn (chưa hết 24h)
  Stream<List<StoryModel>> getActiveStoriesStream() async* {
    final now = DateTime.now();
    final activeCached = cachedStories.where((story) => story.expiresAt.isAfter(now)).toList();
    if (activeCached.isNotEmpty) {
      yield activeCached;
    }

    try {
      yield* _firestore
          .collection('stories')
          .snapshots()
          .map((snapshot) {
        final current = DateTime.now();
        final list = snapshot.docs
            .map((doc) => StoryModel.fromFirestore(doc))
            .where((story) => story.expiresAt.isAfter(current))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        for (var s in list) {
          final idx = cachedStories.indexWhere((c) => c.id == s.id);
          if (idx >= 0) {
            cachedStories[idx] = s;
          } else {
            cachedStories.add(s);
          }
        }
        return list;
      });
    } catch (_) {
      yield activeCached;
    }
  }

  /// Luồng lấy toàn bộ tin trong Kho lưu trữ của người dùng (kể cả tin đã hết hạn)
  Stream<List<StoryModel>> getArchivedStoriesStream(String userId) async* {
    final myStories = cachedStories.where((s) => s.userId == userId).toList();
    myStories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (myStories.isNotEmpty) {
      yield myStories;
    }

    try {
      yield* _firestore
          .collection('stories')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs.map((doc) => StoryModel.fromFirestore(doc)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    } catch (_) {
      yield myStories;
    }
  }

  /// Tạo Story mới 24h (Tối đa 5 tin/ngày)
  Future<String> createStory({
    String? imageUrl,
    required String caption,
    String backgroundColor = '#6C5CE7',
    MusicTrack? musicTrack,
    List<String> stickers = const [],
    List<double> stickerPositionsX = const [],
    List<double> stickerPositionsY = const [],
    double textPositionX = 0.0,
    double textPositionY = 0.0,
    int musicStartTime = 0,
    String textStyle = 'normal',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Người dùng chưa đăng nhập');

    // Kiểm tra giới hạn 5 tin/ngày
    final todayCount = await getTodayStoriesCount(user.uid);
    if (todayCount >= 5) {
      throw Exception('Bạn đã đăng đủ 5 tin trong ngày hôm nay! Hãy quay lại vào ngày mai nhé.');
    }

    String userName = user.displayName ?? 'Thành viên SupaChat';
    String? userAvatar = user.photoURL;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get().timeout(const Duration(seconds: 2));
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          userName = data['displayName'] as String? ?? userName;
          userAvatar = data['photoUrl'] as String? ?? userAvatar;
        }
      }
    } catch (_) {}

    final now = DateTime.now();
    final newId = 'story_${now.millisecondsSinceEpoch}_${user.uid.substring(0, 5)}';

    final story = StoryModel(
      id: newId,
      userId: user.uid,
      userName: userName,
      userAvatar: userAvatar,
      imageUrl: imageUrl,
      caption: caption.trim(),
      backgroundColor: backgroundColor,
      musicTrackTitle: musicTrack?.title,
      musicTrackArtist: musicTrack?.artist,
      musicTrackUrl: musicTrack?.audioUrl,
      stickers: stickers,
      stickerPositionsX: stickerPositionsX,
      stickerPositionsY: stickerPositionsY,
      textPositionX: textPositionX,
      textPositionY: textPositionY,
      musicStartTime: musicStartTime,
      textStyle: textStyle,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
      viewers: [],
    );

    cachedStories.insert(0, story);

    try {
      await _firestore
          .collection('stories')
          .doc(newId)
          .set(story.toMap(useServerTimestamp: true))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Lưu ý ghi story: $e');
    }

    return newId;
  }

  /// Đánh dấu đã xem story
  Future<void> markStoryAsViewed(String storyId, String userId) async {
    if (userId.isEmpty) return;
    try {
      await _firestore.collection('stories').doc(storyId).update({
        'viewers': FieldValue.arrayUnion([userId]),
      });
    } catch (_) {}
  }

  /// Xóa story
  Future<void> deleteStory(String storyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    cachedStories.removeWhere((s) => s.id == storyId);

    try {
      final doc = await _firestore.collection('stories').doc(storyId).get();
      if (!doc.exists) return;

      if (doc.data()?['userId'] == user.uid) {
        await _firestore.collection('stories').doc(storyId).delete();
      }
    } catch (_) {}
  }
}
