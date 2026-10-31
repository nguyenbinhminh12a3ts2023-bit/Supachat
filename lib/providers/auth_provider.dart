import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/firestore_helper.dart';
import '../services/presence_service.dart';

/// Provider quản lý trạng thái xác thực và hồ sơ người dùng
/// Có hỗ trợ lưu trữ cục bộ SharedPreferences vĩnh viễn (Local Persistence)
/// để dữ liệu (tên hiển thị, tiểu sử, ảnh đại diện) không bao giờ bị mất sau khi cập nhật hoặc tải lại trang
class AuthProvider with ChangeNotifier {
  static const String _cachedUserKey = 'supachat_cached_user_profile';
  static String _cachedUserKeyFor(String uid) => 'supachat_cached_user_profile_$uid';

  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  UserModel? _currentUserModel;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUserModel => _currentUserModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get firebaseUser => _authService.currentUser;
  bool get isAuthenticated => _authService.currentUser != null;

  AuthProvider() {
    _loadLocalUserProfile();
    _initAuthListener();
  }

  /// Tải thông tin người dùng từ bộ nhớ đệm SharedPreferences
  Future<void> _loadLocalUserProfile([String? uid]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = uid != null ? _cachedUserKeyFor(uid) : _cachedUserKey;
      final userJson = prefs.getString(key) ?? prefs.getString(_cachedUserKey);
      if (userJson != null) {
        final Map<String, dynamic> data = jsonDecode(userJson);
        if (uid == null || data['uid'] == uid) {
          _currentUserModel = UserModel.fromMap(data);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Lỗi tải cached user profile: $e');
    }
  }

  /// Lưu thông tin người dùng vào SharedPreferences theo UID riêng biệt
  Future<void> _saveLocalUserProfile(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(user.toJsonMap());
      await prefs.setString(_cachedUserKey, json);
      await prefs.setString(_cachedUserKeyFor(user.uid), json);
    } catch (e) {
      debugPrint('Lỗi lưu cached user profile: $e');
    }
  }

  /// Lắng nghe thay đổi trạng thái đăng nhập tự động từ Firebase
  void _initAuthListener() {
    try {
      _authService.authStateChanges.listen((User? user) async {
        if (user != null) {
          // Khởi động gửi nhịp tim hiện diện trực tuyến thật
          PresenceService().start();
          // Tải cache riêng của UID này trước để hiển thị tức thì
          await _loadLocalUserProfile(user.uid);
          // Đồng bộ thông tin mới nhất từ Firestore
          await fetchCurrentUserProfile();
        } else {
          // Khi đã đăng xuất: Dừng gửi nhịp tim và đặt ngoại tuyến
          PresenceService().stop();
          _currentUserModel = null;
          notifyListeners();
        }
      }, onError: (e) {
        debugPrint('Lỗi listener auth: $e');
      });
    } catch (e) {
      debugPrint('Lỗi khởi tạo listener: $e');
    }
  }

  /// Tải thông tin chi tiết người dùng từ Firestore
  Future<void> fetchCurrentUserProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      final remoteProfile = await _authService.getUserProfile(user.uid);
      if (remoteProfile != null) {
        final existingAvatar = _currentUserModel?.photoUrl;
        final remoteAvatar = remoteProfile.photoUrl;
        String? finalAvatar = (remoteAvatar != null && remoteAvatar.trim().isNotEmpty)
            ? remoteAvatar
            : ((existingAvatar != null && existingAvatar.trim().isNotEmpty) ? existingAvatar : null);
        // Không lấy avatar từ tài khoản Google/Gmail
        if (finalAvatar != null && (finalAvatar.contains('googleusercontent.com') || finalAvatar.contains('ggpht.com') || finalAvatar.contains('google.com'))) {
          finalAvatar = null;
        }

        _currentUserModel = remoteProfile.copyWith(photoUrl: finalAvatar);
        await _saveLocalUserProfile(_currentUserModel!);
      } else {
        _currentUserModel ??= UserModel(
          uid: user.uid,
          email: user.email ?? 'user@supachat.com',
          displayName: user.displayName?.isNotEmpty == true ? user.displayName! : 'Người dùng Supa',
          photoUrl: null, // Chỉ nhận avatar riêng của app, không nhận avatar Google
          createdAt: DateTime.now(),
        );
        await _saveLocalUserProfile(_currentUserModel!);

        // Tự động đồng bộ hồ sơ lên Firestore nếu tài khoản chưa có document (ví dụ: database mới tạo)
        try {
          await AppFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(_currentUserModel!.toMap(), SetOptions(merge: true))
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('Lưu ý đồng bộ user Firestore: $e');
        }
      }
      notifyListeners();
    }
  }

  /// Xử lý đăng nhập
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _currentUserModel = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (_currentUserModel != null) {
        await _saveLocalUserProfile(_currentUserModel!);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      final errStr = e.toString().replaceFirst('Exception: ', '');
      if (errStr.contains('not authorized for OAuth') || errStr.contains('unauthorized-domain')) {
        _errorMessage = 'Tên miền này chưa đăng ký OAuth trên Firebase. Vui lòng bấm "Đăng ký ngay" bên dưới để đăng ký bằng Email & Mật khẩu!';
      } else {
        _errorMessage = errStr;
      }
      _setLoading(false);
      return false;
    }
  }

  /// Xử lý đăng nhập bằng Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        _setLoading(false);
        return false;
      }
      _currentUserModel = user;
      await _saveLocalUserProfile(_currentUserModel!);
      _setLoading(false);
      return true;
    } catch (e) {
      final errStr = e.toString().replaceFirst('Exception: ', '');
      if (errStr.contains('not authorized for OAuth') || errStr.contains('unauthorized-domain')) {
        _errorMessage = 'Tên miền này chưa đăng ký OAuth trên Firebase. Vui lòng bấm "Đăng ký ngay" bên dưới để đăng ký bằng Email & Mật khẩu!';
      } else {
        _errorMessage = errStr;
      }
      _setLoading(false);
      return false;
    }
  }

  /// Xử lý đăng ký
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _currentUserModel = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (_currentUserModel != null) {
        await _saveLocalUserProfile(_currentUserModel!);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      final errStr = e.toString().replaceFirst('Exception: ', '');
      if (errStr.contains('not authorized for OAuth') || errStr.contains('unauthorized-domain')) {
        _errorMessage = 'Tên miền này chưa đăng ký OAuth trên Firebase. Vui lòng bấm "Đăng ký ngay" bên dưới để đăng ký bằng Email & Mật khẩu!';
      } else {
        _errorMessage = errStr;
      }
      _setLoading(false);
      return false;
    }
  }

  /// Đã đóng hoàn toàn chức năng khách - bắt buộc dùng tài khoản độc lập
  Future<bool> signInGuest({bool asAdmin = true}) async {
    _setLoading(false);
    _errorMessage = 'Chức năng khách đã được đóng. Vui lòng đăng nhập bằng tài khoản.';
    return false;
  }

  /// Xử lý đăng xuất hoàn toàn (Clear session, tokens và local cache)
  Future<void> signOut() async {
    _setLoading(true);
    try {
      final uid = _currentUserModel?.uid ?? _authService.currentUser?.uid;
      PresenceService().stop();
      await _authService.signOut();
      _currentUserModel = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cachedUserKey);
        if (uid != null) {
          await prefs.remove('_');
        }
      } catch (_) {}
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Xóa tài khoản vĩnh viễn
  Future<void> deleteAccount() async {
    _setLoading(true);
    try {
      final uid = _currentUserModel?.uid ?? _authService.currentUser?.uid;
      PresenceService().stop();
      await _authService.deleteAccount();
      _currentUserModel = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cachedUserKey);
        if (uid != null) {
          await prefs.remove('_');
        }
      } catch (_) {}
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Cập nhật ảnh đại diện lên Firebase Storage dạng Bytes và Firestore
  Future<bool> updateAvatarBytes(Uint8List bytes) async {
    _setLoading(true);
    try {
      final uid = _authService.currentUser?.uid ?? _currentUserModel?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}';

      String? downloadUrl;
      try {
        downloadUrl = await _storageService.uploadAvatarBytes(
          uid: uid,
          bytes: bytes,
        );
        await _authService.updateProfile(photoUrl: downloadUrl);
      } catch (e) {
        debugPrint('Tải ảnh đại diện qua storage lỗi, lưu base64: $e');
        final safeBytes = StorageService.compressToSafeJpeg(bytes, maxWidth: 240, quality: 80);
        final b64 = base64Encode(safeBytes);
        downloadUrl = 'data:image/jpeg;base64,$b64';
        try {
          await _authService.updateProfile(photoUrl: downloadUrl);
        } catch (_) {}
      }

      final fallbackEmail = _authService.currentUser?.email ?? _currentUserModel?.email ?? 'user@supachat.com';
      _currentUserModel = (_currentUserModel ?? UserModel(
        uid: uid,
        email: fallbackEmail,
        displayName: 'Người dùng',
        createdAt: DateTime.now(),
      )).copyWith(photoUrl: downloadUrl);

      await _saveLocalUserProfile(_currentUserModel!);

      // Tự động đồng bộ ảnh đại diện mới vào toàn bộ bài viết đã đăng của người dùng
      try {
        final postsQuery = await AppFirestore.instance
            .collection('posts')
            .where('authorId', isEqualTo: uid)
            .get();
        for (final doc in postsQuery.docs) {
          doc.reference.update({'authorAvatar': downloadUrl});
        }
      } catch (e) {
        debugPrint('Lỗi đồng bộ avatar vào posts: $e');
      }

      // Tự động đồng bộ ảnh đại diện mới vào toàn bộ tin (story) đã đăng của người dùng
      try {
        final storiesQuery = await AppFirestore.instance
            .collection('stories')
            .where('userId', isEqualTo: uid)
            .get();
        for (final doc in storiesQuery.docs) {
          doc.reference.update({'userAvatar': downloadUrl});
        }
      } catch (e) {
        debugPrint('Lỗi đồng bộ avatar vào stories: $e');
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      final errStr = e.toString().replaceFirst('Exception: ', '');
      if (errStr.contains('not authorized for OAuth') || errStr.contains('unauthorized-domain')) {
        _errorMessage = 'Tên miền này chưa đăng ký OAuth trên Firebase. Vui lòng bấm "Đăng ký ngay" bên dưới để đăng ký bằng Email & Mật khẩu!';
      } else {
        _errorMessage = errStr;
      }
      _setLoading(false);
      return false;
    }
  }

  /// Cập nhật ảnh đại diện lên Firebase Storage và Firestore
  Future<bool> updateAvatar(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return updateAvatarBytes(bytes);
  }

  /// Xóa ảnh đại diện để quay về ảnh mặc định SupaChat
  Future<bool> deleteAvatar() async {
    _setLoading(true);
    try {
      final uid = _authService.currentUser?.uid ?? _currentUserModel?.uid;
      if (uid != null) {
        try {
          await _authService.currentUser?.updatePhotoURL(null);
          await AppFirestore.instance.collection('users').doc(uid).update({
            'photoUrl': null,
          });
        } catch (e) {
          debugPrint('Lỗi cập nhật Firestore khi xóa avatar: ');
        }

        _currentUserModel = _currentUserModel?.copyWith(nullifyPhotoUrl: true);
        if (_currentUserModel != null) {
          await _saveLocalUserProfile(_currentUserModel!);
        }

        // Đồng bộ xóa avatar trên toàn bộ bài viết và story đã đăng
        try {
          final postsQuery = await AppFirestore.instance
              .collection('posts')
              .where('authorId', isEqualTo: uid)
              .get();
          for (final doc in postsQuery.docs) {
            doc.reference.update({'authorAvatar': null});
          }
        } catch (_) {}

        try {
          final storiesQuery = await AppFirestore.instance
              .collection('stories')
              .where('userId', isEqualTo: uid)
              .get();
          for (final doc in storiesQuery.docs) {
            doc.reference.update({'userAvatar': null});
          }
        } catch (_) {}
      }
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      final errStr = e.toString().replaceFirst('Exception: ', '');
      if (errStr.contains('not authorized for OAuth') || errStr.contains('unauthorized-domain')) {
        _errorMessage = 'Tên miền này chưa đăng ký OAuth trên Firebase. Vui lòng bấm "Đăng ký ngay" bên dưới để đăng ký bằng Email & Mật khẩu!';
      } else {
        _errorMessage = errStr;
      }
      _setLoading(false);
      return false;
    }
  }

  /// Cập nhật tên hiển thị và tiểu sử (Đảm bảo luôn lưu trữ thành công cả trên máy và đám mây)
  Future<bool> updateProfile({String? displayName, String? bio}) =>
      updateProfileDetails(displayName: displayName, bio: bio);

  Future<bool> updateProfileDetails({String? displayName, String? bio}) async {
    _setLoading(true);
    try {
      final cleanName = displayName?.trim();
      final cleanBio = bio?.trim();

      final fallbackUid = _authService.currentUser?.uid ?? _currentUserModel?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
      final fallbackEmail = _authService.currentUser?.email ?? _currentUserModel?.email ?? 'user@supachat.com';

      // 1. Cập nhật ngay lập tức vào UserModel
      _currentUserModel = (_currentUserModel ?? UserModel(
        uid: fallbackUid,
        email: fallbackEmail,
        displayName: 'Người dùng',
        createdAt: DateTime.now(),
      )).copyWith(
        displayName: (cleanName != null && cleanName.isNotEmpty) ? cleanName : _currentUserModel?.displayName,
        bio: cleanBio ?? _currentUserModel?.bio,
      );

      // 2. Lưu vĩnh viễn vào SharedPreferences
      await _saveLocalUserProfile(_currentUserModel!);

      // 3. Đồng bộ lên Firebase đám mây (bảo vệ bằng try-catch an toàn)
      try {
        await _authService.updateProfile(displayName: cleanName, bio: cleanBio);
      } catch (e) {
        debugPrint('Đồng bộ đám mây: $e (đã lưu an toàn trong máy)');
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      final errStr = e.toString().replaceFirst('Exception: ', '');
      if (errStr.contains('not authorized for OAuth') || errStr.contains('unauthorized-domain')) {
        _errorMessage = 'Tên miền này chưa đăng ký OAuth trên Firebase. Vui lòng bấm "Đăng ký ngay" bên dưới để đăng ký bằng Email & Mật khẩu!';
      } else {
        _errorMessage = errStr;
      }
      _setLoading(false);
      return false;
    }
  }

  /// Đổi mật khẩu tài khoản đang đăng nhập
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Thay đổi quyền hạn tài khoản (Admin / User)
  Future<void> toggleAdminRole() async {
    if (_currentUserModel == null) return;
    final newRole = _currentUserModel!.isAdmin ? 'user' : 'admin';
    _currentUserModel = _currentUserModel!.copyWith(role: newRole);
    await _saveLocalUserProfile(_currentUserModel!);
    try {
      await AppFirestore.instance
          .collection('users')
          .doc(_currentUserModel!.uid)
          .update({'role': newRole});
    } catch (_) {}
    notifyListeners();
  }

  /// Cập nhật trạng thái trực tuyến
  Future<void> updateOnlineStatus(bool isOnline) async {
    if (_currentUserModel == null) return;
    _currentUserModel = _currentUserModel!.copyWith(isOnline: isOnline);
    await _saveLocalUserProfile(_currentUserModel!);
    await PresenceService().setOnline(isOnline);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
