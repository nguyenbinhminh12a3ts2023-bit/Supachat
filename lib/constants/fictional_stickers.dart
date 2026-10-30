import 'package:flutter/material.dart';

/// Model Sticker Nhân vật hư cấu độc quyền SupaChat
class FictionalSticker {
  final String id;
  final String characterName;
  final String emoji;
  final String title;
  final String subtitle;
  final Color badgeColor;

  const FictionalSticker({
    required this.id,
    required this.characterName,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.badgeColor,
  });
}

/// Model Bộ sưu tập Nhân vật hư cấu
class FictionalCharacter {
  final String id;
  final String name;
  final String icon;
  final String description;
  final Color themeColor;
  final List<FictionalSticker> stickers;

  const FictionalCharacter({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.themeColor,
    required this.stickers,
  });
}

/// Kho Sticker 5 Nhân Vật Hư Cấu Độc Quyền SupaChat
class FictionalStickerLibrary {
  static const List<FictionalCharacter> characters = [
    // 1. Mèo Supa (Supa Cat)
    FictionalCharacter(
      id: 'supa_cat',
      name: 'Mèo Supa',
      icon: '🐱',
      description: 'Linh vật vũ trụ SupaChat siêu đáng yêu',
      themeColor: Color(0xFF6C5CE7),
      stickers: [
        FictionalSticker(
          id: 'cat_01',
          characterName: 'Mèo Supa',
          emoji: '😺',
          title: 'Chào bạn nhé!',
          subtitle: 'Hello Supa',
          badgeColor: Color(0xFF6C5CE7),
        ),
        FictionalSticker(
          id: 'cat_02',
          characterName: 'Mèo Supa',
          emoji: '😻',
          title: 'Bắn tim nè!',
          subtitle: 'Love you so much',
          badgeColor: Color(0xFFFF7675),
        ),
        FictionalSticker(
          id: 'cat_03',
          characterName: 'Mèo Supa',
          emoji: '😿',
          title: 'Khóc ròng luôn...',
          subtitle: 'Huhu đau lòng quá',
          badgeColor: Color(0xFF74B9FF),
        ),
        FictionalSticker(
          id: 'cat_04',
          characterName: 'Mèo Supa',
          emoji: '😼',
          title: 'Tuyệt vời số 1!',
          subtitle: 'Chuẩn không cần chỉnh',
          badgeColor: Color(0xFF00B894),
        ),
        FictionalSticker(
          id: 'cat_05',
          characterName: 'Mèo Supa',
          emoji: '😽',
          title: 'Ngủ khò khò...',
          subtitle: 'Đi ngủ đây, bái bai',
          badgeColor: Color(0xFFA29BFE),
        ),
        FictionalSticker(
          id: 'cat_06',
          characterName: 'Mèo Supa',
          emoji: '😾',
          title: 'Hờn dỗi rồi!',
          subtitle: 'Không thèm nói chuyện nữa',
          badgeColor: Color(0xFFE17055),
        ),
      ],
    ),

    // 2. Cáo Neon (Neon Fox)
    FictionalCharacter(
      id: 'neon_fox',
      name: 'Cáo Neon',
      icon: '🦊',
      description: 'Sành điệu, thông minh và yêu âm nhạc',
      themeColor: Color(0xFFFD79A8),
      stickers: [
        FictionalSticker(
          id: 'fox_01',
          characterName: 'Cáo Neon',
          emoji: '🎧',
          title: 'Chill thôi nào!',
          subtitle: 'V-Pop xập xình',
          badgeColor: Color(0xFFFD79A8),
        ),
        FictionalSticker(
          id: 'fox_02',
          characterName: 'Cáo Neon',
          emoji: '🥳',
          title: 'Đi quẩy không?',
          subtitle: 'Tối nay lên đồ',
          badgeColor: Color(0xFFFDCB6E),
        ),
        FictionalSticker(
          id: 'fox_03',
          characterName: 'Cáo Neon',
          emoji: '🤐',
          title: 'Cạn lời luôn...',
          subtitle: 'Không biết nói gì thêm',
          badgeColor: Color(0xFF636E72),
        ),
        FictionalSticker(
          id: 'fox_04',
          characterName: 'Cáo Neon',
          emoji: '☕',
          title: 'Húp trà hóng drama',
          subtitle: 'Biến căng quá',
          badgeColor: Color(0xFFE17055),
        ),
        FictionalSticker(
          id: 'fox_05',
          characterName: 'Cáo Neon',
          emoji: '👑',
          title: 'Đỉnh của chóp!',
          subtitle: 'Số 1 không ai bằng',
          badgeColor: Color(0xFFF1C40F),
        ),
        FictionalSticker(
          id: 'fox_06',
          characterName: 'Cáo Neon',
          emoji: '💨',
          title: 'Biến mất đây!',
          subtitle: 'Lượn ngay kẻo muộn',
          badgeColor: Color(0xFF00CEC9),
        ),
      ],
    ),

    // 3. Gấu Bơ (Butter Bear)
    FictionalCharacter(
      id: 'butter_bear',
      name: 'Gấu Bơ',
      icon: '🐻',
      description: 'Chàng gấu ấm áp, hảo ngọt và thích ôm',
      themeColor: Color(0xFFF39C12),
      stickers: [
        FictionalSticker(
          id: 'bear_01',
          characterName: 'Gấu Bơ',
          emoji: '🤗',
          title: 'Ôm một cái nào!',
          subtitle: 'Ấm áp yêu thương',
          badgeColor: Color(0xFFF39C12),
        ),
        FictionalSticker(
          id: 'bear_02',
          characterName: 'Gấu Bơ',
          emoji: '🍔',
          title: 'Đang măm măm...',
          subtitle: 'Đói bụng quá rồi',
          badgeColor: Color(0xFFE67E22),
        ),
        FictionalSticker(
          id: 'bear_03',
          characterName: 'Gấu Bơ',
          emoji: '🫠',
          title: 'Tan chảy mất thôi',
          subtitle: 'Dễ thương xỉu',
          badgeColor: Color(0xFFE74C3C),
        ),
        FictionalSticker(
          id: 'bear_04',
          characterName: 'Gấu Bơ',
          emoji: '✨',
          title: 'Lung linh lấp lánh',
          subtitle: 'Tỏa sáng rực rỡ',
          badgeColor: Color(0xFFF1C40F),
        ),
        FictionalSticker(
          id: 'bear_05',
          characterName: 'Gấu Bơ',
          emoji: '🥺',
          title: 'Xin nhỗi mà...',
          subtitle: 'Đừng giận tớ nha',
          badgeColor: Color(0xFF9B59B6),
        ),
        FictionalSticker(
          id: 'bear_06',
          characterName: 'Gấu Bơ',
          emoji: '🤣',
          title: 'Cười bò ra sàn',
          subtitle: 'Hài hước quá đi',
          badgeColor: Color(0xFF2ECC71),
        ),
      ],
    ),

    // 4. Thỏ Bông (Fluffy Bunny)
    FictionalCharacter(
      id: 'fluffy_bunny',
      name: 'Thỏ Bông',
      icon: '🐰',
      description: 'Cô thỏ trắng tinh nghịch, ngập tràn năng lượng',
      themeColor: Color(0xFFE84393),
      stickers: [
        FictionalSticker(
          id: 'bunny_01',
          characterName: 'Thỏ Bông',
          emoji: '🎉',
          title: 'Yay, thành công!',
          subtitle: 'Chúc mừng bạn nhé',
          badgeColor: Color(0xFFE84393),
        ),
        FictionalSticker(
          id: 'bunny_02',
          characterName: 'Thỏ Bông',
          emoji: '🌸',
          title: 'Nhớ bạn quá đi!',
          subtitle: 'Bao giờ gặp lại?',
          badgeColor: Color(0xFFFF7675),
        ),
        FictionalSticker(
          id: 'bunny_03',
          characterName: 'Thỏ Bông',
          emoji: '🏃‍♀️',
          title: 'Chạy deadline!',
          subtitle: 'Cuống cuồng cả lên',
          badgeColor: Color(0xFF0984E3),
        ),
        FictionalSticker(
          id: 'bunny_04',
          characterName: 'Thỏ Bông',
          emoji: '😵‍💫',
          title: 'Choáng váng đầu óc',
          subtitle: 'Quá nhiều việc rồi',
          badgeColor: Color(0xFF6C5CE7),
        ),
        FictionalSticker(
          id: 'bunny_05',
          characterName: 'Thỏ Bông',
          emoji: '😘',
          title: 'Gửi ngàn nụ hôn!',
          subtitle: 'Moa moa',
          badgeColor: Color(0xFFFD79A8),
        ),
        FictionalSticker(
          id: 'bunny_06',
          characterName: 'Thỏ Bông',
          emoji: '💪',
          title: 'Cố lên bạn ơi!',
          subtitle: 'You can do it',
          badgeColor: Color(0xFF00B894),
        ),
      ],
    ),

    // 5. Rồng Con (Little Dragon)
    FictionalCharacter(
      id: 'little_dragon',
      name: 'Rồng Con',
      icon: '🐲',
      description: 'Linh thú thần kỳ mang may mắn và tài lộc',
      themeColor: Color(0xFF00CEC9),
      stickers: [
        FictionalSticker(
          id: 'dragon_01',
          characterName: 'Rồng Con',
          emoji: '🔥',
          title: 'Phun lửa nhiệt huyết!',
          subtitle: 'Cháy hết mình nào',
          badgeColor: Color(0xFFD63031),
        ),
        FictionalSticker(
          id: 'dragon_02',
          characterName: 'Rồng Con',
          emoji: '💰',
          title: 'Phú quý phát tài!',
          subtitle: 'Tài lộc dồi dào',
          badgeColor: Color(0xFFF1C40F),
        ),
        FictionalSticker(
          id: 'dragon_03',
          characterName: 'Rồng Con',
          emoji: '🚀',
          title: 'Bay cao nào!',
          subtitle: 'Vươn tới những vì sao',
          badgeColor: Color(0xFF0984E3),
        ),
        FictionalSticker(
          id: 'dragon_04',
          characterName: 'Rồng Con',
          emoji: '🪄',
          title: 'Phép thuật kỳ diệu',
          subtitle: 'Mọi điều như ý',
          badgeColor: Color(0xFF6C5CE7),
        ),
        FictionalSticker(
          id: 'dragon_05',
          characterName: 'Rồng Con',
          emoji: '👍',
          title: 'Đồng ý 100%!',
          subtitle: 'Nhất trí với bạn',
          badgeColor: Color(0xFF00CEC9),
        ),
        FictionalSticker(
          id: 'dragon_06',
          characterName: 'Rồng Con',
          emoji: '👋',
          title: 'Tạm biệt nhé!',
          subtitle: 'Hẹn sớm gặp lại',
          badgeColor: Color(0xFF636E72),
        ),
      ],
    ),
  ];

  static List<FictionalSticker> get allStickers {
    return characters.expand((c) => c.stickers).toList();
  }
}
