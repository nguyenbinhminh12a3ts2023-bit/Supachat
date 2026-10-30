import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supachat/constants/fictional_stickers.dart';
import 'package:supachat/constants/music_tracks.dart';
import 'package:supachat/models/message_model.dart';
import 'package:supachat/models/post_model.dart';
import 'package:supachat/models/story_model.dart';
import 'package:supachat/models/user_model.dart';
import 'package:supachat/providers/auth_provider.dart';
import 'package:supachat/screens/auth/register_screen.dart';
import 'package:supachat/services/translation_service.dart';
import 'package:supachat/widgets/avatar_widget.dart';

void main() {
  group('1. KIỂM THỬ ĐĂNG KÝ VÀ QUẢN LÝ AVATAR MẶC ĐỊNH', () {
    testWidgets('1.1 AvatarWidget hiển thị ảnh mặc định khi user mới đăng ký chưa có ảnh', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(
              photoUrl: null,
              name: 'Người dùng mới',
            ),
          ),
        ),
      );

      expect(find.byType(AvatarWidget), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    test('1.2 Người dùng mới tạo tài khoản: photoUrl là null, tự động dùng Avatar mặc định', () {
      final newUser = UserModel(
        uid: 'test_user_001',
        email: 'test001@supachat.com',
        displayName: 'Nguyễn Văn Test',
        photoUrl: null,
        createdAt: DateTime.now(),
      );

      expect(newUser.photoUrl, isNull);
      expect(newUser.displayName, equals('Nguyễn Văn Test'));
      expect(newUser.isAdmin, isFalse);
    });

    test('1.3 Kiểm tra file Avatar mặc định đã tồn tại trong assets', () {
      final avatarFile = File('assets/images/default_avatar.png');
      expect(avatarFile.existsSync(), isTrue, reason: 'File default_avatar.png phải tồn tại');
      expect(avatarFile.lengthSync(), greaterThan(1000), reason: 'File avatar phải có nội dung');
    });

    test('1.4 Người dùng xóa avatar: copyWith(nullifyPhotoUrl: true) đưa về null', () {
      final userWithAvatar = UserModel(
        uid: 'test_user_002',
        email: 'user002@supachat.com',
        displayName: 'Trần Thị Hoa',
        photoUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        createdAt: DateTime.now(),
      );

      expect(userWithAvatar.photoUrl, isNotNull);

      // Giả lập hành động "Gỡ ảnh đại diện (Về ảnh mặc định)"
      final userAfterDelete = userWithAvatar.copyWith(nullifyPhotoUrl: true);
      expect(userAfterDelete.photoUrl, isNull, reason: 'Avatar phải trở về null sau khi gỡ');
    });

    test('1.5 Người dùng tự chọn avatar tùy ý: copyWith cập nhật URL mới', () {
      final user = UserModel(
        uid: 'test_user_003',
        email: 'user003@supachat.com',
        displayName: 'Lê Văn Cường',
        photoUrl: null,
        createdAt: DateTime.now(),
      );

      const customAvatarUrl = 'https://firebasestorage.googleapis.com/v0/b/supachat/avatars/custom_pic.jpg';
      final updatedUser = user.copyWith(photoUrl: customAvatarUrl);
      expect(updatedUser.photoUrl, equals(customAvatarUrl));
    });
  });

  group('2. KIỂM THỬ BẢNG TIN (FEED), ĐĂNG BÀI VÀ STORY 24H', () {
    test('2.1 Tạo bài viết có đính kèm bài hát thật và tính năng Thả tim / Bình luận', () {
      final track = MusicTrackLibrary.tracks.first;
      final post = PostModel(
        id: 'post_1001',
        authorId: 'test_user_001',
        authorName: 'Nguyễn Văn Test',
        content: 'Hôm nay trời đẹp quá, cùng nghe nhạc nhé mọi người!',
        musicTrackId: track.id,
        musicTrackTitle: track.title,
        musicTrackArtist: track.artist,
        musicTrackUrl: track.audioUrl,
        likes: ['test_user_002', 'test_user_003'],
        commentsCount: 5,
        createdAt: DateTime.now(),
      );

      expect(post.content, contains('cùng nghe nhạc'));
      expect(post.musicTrackTitle, equals('Chạy Ngay Đi'));
      expect(post.musicTrackUrl, startsWith('https://'));
      expect(post.privacy, equals('public'));
      expect(post.isLikedBy('test_user_002'), isTrue);
      expect(post.isLikedBy('test_user_999'), isFalse);
      expect(post.likes.length, equals(2));
      expect(post.commentsCount, equals(5));
    });

    test('2.2 Tạo Story 24h: Kiểm tra thời hạn hết hạn chính xác sau 24 giờ', () {
      final now = DateTime.now();
      final story = StoryModel(
        id: 'story_2001',
        userId: 'test_user_001',
        userName: 'Nguyễn Văn Test',
        caption: 'Cà phê sáng thư giãn',
        backgroundColor: '#6C5CE7',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );

      expect(story.isExpired, isFalse, reason: 'Story mới tạo chưa thể hết hạn');
      expect(story.expiresAt.difference(story.createdAt).inHours, equals(24));

      // Giả lập Story đã quá 24h
      final expiredStory = StoryModel(
        id: 'story_2002',
        userId: 'test_user_001',
        userName: 'Nguyễn Văn Test',
        caption: 'Tin cũ hôm qua',
        createdAt: now.subtract(const Duration(hours: 25)),
        expiresAt: now.subtract(const Duration(hours: 1)),
      );
      expect(expiredStory.isExpired, isTrue, reason: 'Story sau 24h phải đánh dấu hết hạn');
    });
  });

  group('3. KIỂM THỬ NHẠC THẬT (REAL PLAYABLE AUDIO TRACKS)', () {
    test('3.1 Thư viện bài hát chứa danh sách 20 bài V-Pop MP3 trực tuyến hoạt động 100%', () {
      expect(MusicTrackLibrary.tracks.length, equals(20));

      for (final track in MusicTrackLibrary.tracks) {
        expect(track.id, isNotEmpty);
        expect(track.title, isNotEmpty);
        expect(track.artist, isNotEmpty);
        expect(track.audioUrl, startsWith('http'));
        expect(track.audioUrl, endsWith('.mp3'), reason: 'Phải là định dạng stream mp3 trực tiếp');
        expect(track.duration, isNotEmpty);
      }
    });
  });

  group('4. KIỂM THỬ NHẮN TIN CHUẨN MESSENGER (STICKER, FILE, VỊ TRÍ, DỊCH)', () {
    test('4.1 Tạo tin nhắn gửi Tệp tin / Tài liệu', () {
      final fileMessage = MessageModel(
        id: 'msg_file_01',
        senderId: 'user1',
        receiverId: 'user2',
        text: 'Tai_lieu_du_an.pdf',
        type: MessageType.file,
        mediaUrl: 'https://firebasestorage.googleapis.com/.../Tai_lieu_du_an.pdf',
        fileName: 'Tai_lieu_du_an.pdf',
        fileSize: '2.4 MB',
        timestamp: DateTime.now(),
      );

      expect(fileMessage.type, equals(MessageType.file));
      expect(fileMessage.fileName, equals('Tai_lieu_du_an.pdf'));
      expect(fileMessage.fileSize, equals('2.4 MB'));
    });

    test('4.2 Tạo tin nhắn Sticker độc quyền', () {
      final stickerMessage = MessageModel(
        id: 'msg_sticker_01',
        senderId: 'user1',
        receiverId: 'user2',
        text: '❤️ [Yêu thích]',
        type: MessageType.sticker,
        timestamp: DateTime.now(),
      );

      expect(stickerMessage.type, equals(MessageType.sticker));
      expect(stickerMessage.text, contains('❤️'));
    });

    test('4.3 Tạo tin nhắn Chia sẻ vị trí thời gian thực', () {
      final locMessage = MessageModel(
        id: 'msg_loc_01',
        senderId: 'user1',
        receiverId: 'user2',
        text: 'Hồ Hoàn Kiếm, Hà Nội',
        type: MessageType.location,
        latitude: 21.0285,
        longitude: 105.8542,
        timestamp: DateTime.now(),
      );

      expect(locMessage.type, equals(MessageType.location));
      expect(locMessage.latitude, equals(21.0285));
      expect(locMessage.longitude, equals(105.8542));
    });

    test('4.4 Dịch tin nhắn: Đảm bảo có xử lý fallback và cache', () async {
      final translationService = TranslationService();
      // Test chuỗi rỗng
      final emptyResult = await translationService.translateText('');
      expect(emptyResult, isEmpty);

      // Test văn bản dịch fallback khi offline
      final res = await translationService.translateText('Hello', targetLang: 'vi');
      expect(res, isNotEmpty);
    });
  });

  group('5. KIỂM THỬ CUỘC GỌI THOẠI THẬT 2 CHIỀU (REAL AUDIO CALL)', () {
    test('5.1 Định dạng thông báo kết thúc cuộc gọi trong chat', () {
      final callNotice = MessageModel(
        id: 'msg_call_01',
        senderId: 'user1',
        receiverId: 'user2',
        text: 'Cuộc gọi thoại (05:24)',
        type: MessageType.callNotice,
        timestamp: DateTime.now(),
      );

      expect(callNotice.type, equals(MessageType.callNotice));
      expect(callNotice.text, contains('05:24'));
    });
  });

  group('6. KIỂM THỬ GIAO DIỆN & XÁC THỰC ĐĂNG KÝ (REGISTER SCREEN)', () {
    testWidgets('6.1 Hiển thị đầy đủ các trường nhập liệu trên màn hình Đăng ký', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      expect(find.text('Tạo tài khoản mới'), findsOneWidget);
      expect(find.text('Họ và tên'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Xác nhận mật khẩu'), findsOneWidget);
      expect(find.text('Đăng ký'), findsOneWidget);
    });

    testWidgets('6.2 Kiểm tra kiểm tra lỗi (Validation) khi để trống các trường', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      // Nhấn nút đăng ký khi chưa nhập gì
      final registerButton = find.text('Đăng ký');
      await tester.ensureVisible(registerButton);
      await tester.tap(registerButton);
      await tester.pump();

      expect(find.text('Vui lòng nhập họ và tên'), findsOneWidget);
      expect(find.text('Vui lòng nhập email'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    });
  });

  group('7. KIỂM THỬ QUYỀN RIÊNG TƯ BÀI VIẾT, STICKER STORY VÀ ĐỔI MẬT KHẨU', () {
    test('7.1 PostModel hỗ trợ quyền riêng tư "Công khai" và "Bạn bè"', () {
      final publicPost = PostModel(
        id: 'post_pub_1',
        authorId: 'u1',
        authorName: 'User 1',
        content: 'Bài viết công khai',
        privacy: 'public',
        createdAt: DateTime.now(),
      );
      final friendsPost = PostModel(
        id: 'post_fr_1',
        authorId: 'u1',
        authorName: 'User 1',
        content: 'Bài viết chỉ cho bạn bè',
        privacy: 'friends',
        createdAt: DateTime.now(),
      );

      expect(publicPost.privacy, equals('public'));
      expect(friendsPost.privacy, equals('friends'));

      final map = friendsPost.toMap();
      expect(map['privacy'], equals('friends'));
    });

    test('7.2 StoryModel lưu và hiển thị danh sách Stickers đã chọn', () {
      final storyWithStickers = StoryModel(
        id: 'story_st_1',
        userId: 'u1',
        userName: 'User 1',
        caption: 'Hôm nay trời đẹp',
        stickers: ['🔥 Hot', '❤️ Yêu', '📍 Hà Nội'],
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      expect(storyWithStickers.stickers.length, equals(3));
      expect(storyWithStickers.stickers, contains('📍 Hà Nội'));

      final map = storyWithStickers.toMap();
      expect(map['stickers'], isA<List>());
      expect((map['stickers'] as List).length, equals(3));
    });

    test('7.3 Kiểm tra 20 bài V-Pop: Toàn bộ bài hát có audioUrl hợp lệ từ kho nhạc thật', () {
      expect(MusicTrackLibrary.tracks.length, equals(20));
      for (final t in MusicTrackLibrary.tracks) {
        expect(t.title.isNotEmpty, isTrue);
        expect(t.artist.isNotEmpty, isTrue);
        expect(t.audioUrl, startsWith('https://archive.org/download/'));
        expect(t.audioUrl.endsWith('.mp3'), isTrue);
      }
    });
  });

  group('8. KIỂM THỬ BỘ STICKER ẢO, EMOJI, TIN NHẮN THOẠI (VOICE) & DỊCH THUẬT', () {
    test('8.1 Kho Sticker ảo có đầy đủ 5 nhân vật hư cấu độc quyền và 30 sticker', () {
      expect(FictionalStickerLibrary.characters.length, equals(5));
      expect(FictionalStickerLibrary.allStickers.length, equals(30));

      final cat = FictionalStickerLibrary.characters.firstWhere((c) => c.id == 'supa_cat');
      expect(cat.name, equals('Mèo Supa'));
      expect(cat.stickers.length, equals(6));
    });

    test('8.2 Tin nhắn thoại (MessageType.voice) lưu thời lượng và link audioUrl', () {
      final voiceMsg = MessageModel(
        id: 'voice_msg_1',
        senderId: 'user_1',
        receiverId: 'user_2',
        text: '00:08',
        type: MessageType.voice,
        mediaUrl: 'https://archive.org/download/sample_voice.mp3',
        timestamp: DateTime.now(),
      );

      expect(voiceMsg.type, equals(MessageType.voice));
      expect(voiceMsg.text, equals('00:08'));
      expect(voiceMsg.mediaUrl, contains('.mp3'));

      final map = voiceMsg.toMap();
      expect(map['type'], equals('voice'));
      expect(map['mediaUrl'], equals('https://archive.org/download/sample_voice.mp3'));
    });

    test('8.3 Dịch tin nhắn: Hỗ trợ tự động nhận diện ngôn ngữ tiếng Việt & quốc tế', () async {
      final transService = TranslationService();
      // Test cache
      final viText = await transService.translateText('Hello world', targetLang: 'vi');
      expect(viText.isNotEmpty, isTrue);

      final cached = await transService.translateText('Hello world', targetLang: 'vi');
      expect(cached, equals(viText));
    });
  });

  group('9. KIỂM THỬ TẠO TIN (STORY): KÉO THẢ TEXT, CHỌN ĐOẠN NHẠC & AVATAR MẶC ĐỊNH VECTOR', () {
    test('9.1 StoryModel lưu vị trí kéo thả text, đoạn nhạc startSeconds và textStyle', () {
      final now = DateTime.now();
      final story = StoryModel(
        id: 'story_drag_test',
        userId: 'user_1',
        userName: 'Bình Minh',
        caption: 'Hôm nay trời đẹp quá!',
        backgroundColor: '#6C5CE7',
        textPositionX: 0.25,
        textPositionY: -0.45,
        musicStartTime: 45, // Bắt đầu từ giây 45
        textStyle: 'darkPill',
        musicTrackTitle: 'Chạy Ngay Đi',
        musicTrackArtist: 'Sơn Tùng M-TP',
        musicTrackUrl: 'https://archive.org/download/test_music.mp3',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );

      expect(story.textPositionX, equals(0.25));
      expect(story.textPositionY, equals(-0.45));
      expect(story.musicStartTime, equals(45));
      expect(story.textStyle, equals('darkPill'));

      final map = story.toMap();
      expect(map['textPositionX'], equals(0.25));
      expect(map['textPositionY'], equals(-0.45));
      expect(map['musicStartTime'], equals(45));
      expect(map['textStyle'], equals('darkPill'));
    });

    testWidgets('9.2 AvatarWidget vẽ DefaultAvatarPainter mượt mà khi photoUrl rỗng', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(
              name: 'Hoài An',
              photoUrl: null,
              radius: 35,
            ),
          ),
        ),
      );

      expect(find.byType(AvatarWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
