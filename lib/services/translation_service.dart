import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Dịch vụ dịch thuật tin nhắn đa ngôn ngữ trong cuộc trò chuyện SupaChat
class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  final Map<String, String> _cache = {};

  /// Dịch một đoạn văn bản sang ngôn ngữ đích (mặc định Tiếng Việt 'vi' hoặc Tiếng Anh 'en')
  Future<String> translateText(String text, {String targetLang = 'vi'}) async {
    final clean = text.trim();
    if (clean.isEmpty) return clean;

    final cacheKey = '$clean->$targetLang';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final uri = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(clean)}&langpair=autodetect|$targetLang',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translated = data['responseData']?['translatedText'] as String?;
        if (translated != null && translated.isNotEmpty) {
          _cache[cacheKey] = translated;
          return translated;
        }
      }
    } catch (e) {
      debugPrint('Lỗi dịch thuật: $e');
    }

    // Fallback nếu gặp lỗi mạng: Trả về văn bản gốc
    return clean;
  }
}

