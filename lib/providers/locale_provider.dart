import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider quản lý ngôn ngữ toàn ứng dụng SupaChat (Việt, Anh, Nhật, Hàn)
class LocaleProvider with ChangeNotifier {
  static const String _prefKey = 'supachat_language_code';
  String _languageCode = 'vi';

  String get languageCode => _languageCode;
  bool get isVietnamese => _languageCode == 'vi';
  bool get isEnglish => _languageCode == 'en';

  LocaleProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && saved.isNotEmpty) {
        _languageCode = saved;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLanguage(String code) async {
    _languageCode = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (_) {}
  }

  String get languageName {
    switch (_languageCode) {
      case 'en':
        return 'English';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'vi':
      default:
        return 'Tiếng Việt';
    }
  }

  /// Tra cứu văn bản theo ngôn ngữ hiện tại
  String t(String vi, [String? en, String? ja, String? ko]) {
    switch (_languageCode) {
      case 'en':
        return en ?? vi;
      case 'ja':
        return ja ?? en ?? vi;
      case 'ko':
        return ko ?? en ?? vi;
      case 'vi':
      default:
        return vi;
    }
  }
}
