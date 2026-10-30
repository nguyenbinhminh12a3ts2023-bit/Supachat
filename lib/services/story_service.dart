import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/music_tracks.dart';
import '../models/story_model.dart';

/// Dịch vụ quản lý Tin 24h (Story)
class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Luồng lấy toàn bộ tin còn hạn (chưa hết 24h)
  Stream<List<StoryModel>> getActiveStoriesStream() {
    return _firestore
        .collection('stories')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final list = snapshot.docs
          .map((doc) => StoryModel.fromFirestore(doc))
          .where((story) => story.expiresAt.isAfter(now))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Tạo Story mới 24h
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

    String userName = user.displayName ?? 'Thành viên SupaChat';
    String? userAvatar = user.photoURL;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get().timeout(const Duration(seconds: 3));
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          userName = data['displayName'] as String? ?? userName;
          userAvatar = data['photoUrl'] as String? ?? userAvatar;
        }
      }
    } catch (_) {}

    final now = DateTime.now();
    final story = StoryModel(
      id: '',
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

    final docRef = await _firestore
        .collection('stories')
        .add(story.toMap(useServerTimestamp: true))
        .timeout(const Duration(seconds: 40));
    return docRef.id;
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

    final doc = await _firestore.collection('stories').doc(storyId).get();
    if (!doc.exists) return;

    if (doc.data()?['userId'] == user.uid) {
      await _firestore.collection('stories').doc(storyId).delete();
    }
  }
}

