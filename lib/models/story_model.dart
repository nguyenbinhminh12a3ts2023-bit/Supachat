import 'package:cloud_firestore/cloud_firestore.dart';

/// Mô hình Tin 24h (Story) của SupaChat
class StoryModel {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? imageUrl;
  final String caption;
  final String backgroundColor; // Hex code, e.g. '#6C5CE7'
  final String? musicTrackTitle;
  final String? musicTrackArtist;
  final String? musicTrackUrl;
  final List<String> stickers;
  final List<double> stickerPositionsX;
  final List<double> stickerPositionsY;
  final double textPositionX; // Tọa độ X (-1.0 đến 1.0)
  final double textPositionY; // Tọa độ Y (-1.0 đến 1.0)
  final int musicStartTime;   // Thời điểm bắt đầu phát nhạc (giây)
  final String textStyle;     // 'normal', 'darkPill', 'lightPill'
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewers;

  const StoryModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.imageUrl,
    this.caption = '',
    this.backgroundColor = '#6C5CE7',
    this.musicTrackTitle,
    this.musicTrackArtist,
    this.musicTrackUrl,
    this.stickers = const [],
    this.stickerPositionsX = const [],
    this.stickerPositionsY = const [],
    this.textPositionX = 0.0,
    this.textPositionY = 0.0,
    this.musicStartTime = 0,
    this.textStyle = 'normal',
    required this.createdAt,
    required this.expiresAt,
    this.viewers = const [],
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory StoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime parseTime(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    final now = DateTime.now();
    final created = parseTime(data['createdAt'], now);
    final expires = parseTime(data['expiresAt'], created.add(const Duration(hours: 24)));

    return StoryModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Người dùng',
      userAvatar: data['userAvatar'] as String?,
      imageUrl: data['imageUrl'] as String?,
      caption: data['caption'] as String? ?? '',
      backgroundColor: data['backgroundColor'] as String? ?? '#6C5CE7',
      musicTrackTitle: data['musicTrackTitle'] as String?,
      musicTrackArtist: data['musicTrackArtist'] as String?,
      musicTrackUrl: data['musicTrackUrl'] as String?,
      stickers: List<String>.from(data['stickers'] as List? ?? []),
      stickerPositionsX: (data['stickerPositionsX'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      stickerPositionsY: (data['stickerPositionsY'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      textPositionX: (data['textPositionX'] as num?)?.toDouble() ?? 0.0,
      textPositionY: (data['textPositionY'] as num?)?.toDouble() ?? 0.0,
      musicStartTime: (data['musicStartTime'] as num?)?.toInt() ?? 0,
      textStyle: data['textStyle'] as String? ?? 'normal',
      createdAt: created,
      expiresAt: expires,
      viewers: List<String>.from(data['viewers'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap({bool useServerTimestamp = false}) {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'imageUrl': imageUrl,
      'caption': caption,
      'backgroundColor': backgroundColor,
      'musicTrackTitle': musicTrackTitle,
      'musicTrackArtist': musicTrackArtist,
      'musicTrackUrl': musicTrackUrl,
      'stickers': stickers,
      'stickerPositionsX': stickerPositionsX,
      'stickerPositionsY': stickerPositionsY,
      'textPositionX': textPositionX,
      'textPositionY': textPositionY,
      'musicStartTime': musicStartTime,
      'textStyle': textStyle,
      'createdAt': useServerTimestamp ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewers': viewers,
    };
  }
}

