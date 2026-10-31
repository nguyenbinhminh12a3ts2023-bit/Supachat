import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'firestore_helper.dart';

/// Dịch vụ xử lý đăng ký, đăng nhập, hồ sơ người dùng với Firebase Auth & Firestore
class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => AppFirestore.instance;
  GoogleSignIn get _googleSignIn => GoogleSignIn(
    clientId: kIsWeb ? '725465702601-hqhh9hkmc539pfllr8b66u9dbdo5upjp.apps.googleusercontent.com' : null,
  );

  /// Tự động đồng bộ tài khoản Auth sang Firestore để đảm bảo luôn tìm thấy và kết bạn được
  Future<void> syncUserToFirestore(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get().timeout(const Duration(seconds: 6));
      final displayName = (user.displayName != null && user.displayName!.isNotEmpty)
          ? user.displayName!
          : (user.email?.split('@').first ?? 'Người dùng');

      if (!doc.exists) {
        final newUser = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: displayName,
          photoUrl: null, // Không lấy avatar mặc định từ Google, chỉ dùng avatar SupaChat
          bio: null,
          isOnline: true,
          lastSeen: DateTime.now(),
          createdAt: DateTime.now(),
          role: (user.email ?? '').toLowerCase().contains('admin') ? 'admin' : 'user',
        );
        await docRef.set(newUser.toMap(), SetOptions(merge: true));
      } else {
        await docRef.set({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
          if (user.displayName != null && user.displayName!.isNotEmpty)
            'displayName': user.displayName,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Lưu ý đồng bộ user sang Firestore: $e');
    }
  }

  /// Lấy thông tin user hiện tại từ Firebase Auth
  User? get currentUser {
    try {
      if (Firebase.apps.isNotEmpty) {
        return _auth.currentUser;
      }
    } catch (_) {}
    return null;
  }

  /// Stream theo dõi trạng thái đăng nhập thời gian thực (Auth State)
  Stream<User?> get authStateChanges {
    try {
      if (Firebase.apps.isNotEmpty) {
        return _auth.authStateChanges();
      }
    } catch (_) {}
    return const Stream.empty();
  }

  /// Đăng ký tài khoản mới bằng Email & Mật khẩu
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // 1. Tạo tài khoản trong Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Không thể tạo người dùng. Vui lòng thử lại.');
      }

      // 2. Cập nhật Display Name trong Firebase Auth
      try {
        await user.updateDisplayName(displayName.trim());
      } catch (e) {
        debugPrint('Lỗi cập nhật displayName trong Auth: $e');
      }

      // 3. Khởi tạo dữ liệu người dùng trên Firestore
      final newUser = UserModel(
        uid: user.uid,
        email: email.trim(),
        displayName: displayName.trim(),
        photoUrl: null,
        bio: null,
        isOnline: true,
        lastSeen: DateTime.now(),
        createdAt: DateTime.now(),
        role: email.trim().toLowerCase().contains('admin') ? 'admin' : 'user',
      );

      // Timeout an toàn khi ghi Firestore (15 giây)
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(newUser.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('Lưu ý khi ghi Firestore: $e');
      }

      return newUser;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Đã xảy ra lỗi khi đăng ký: $e');
    }
  }

  /// Đăng nhập bằng Email & Mật khẩu
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Đăng nhập thất bại.');
      }

      // Cập nhật trạng thái online và thời điểm truy cập với timeout
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('Lưu ý cập nhật trạng thái online: $e');
      }

      // Lấy thông tin người dùng từ Firestore với timeout
      try {
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 15));
        if (doc.exists) {
          return UserModel.fromDocument(doc);
        }
      } catch (e) {
        debugPrint('Lưu ý đọc thông tin Firestore: $e');
      }

      // Trường hợp document chưa tồn tại hoặc Firestore chưa khởi tạo, fallback
      final fallbackUser = UserModel(
        uid: user.uid,
        email: user.email ?? email.trim(),
        displayName: (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName!
            : email.trim().split('@').first,
        photoUrl: user.photoURL,
        isOnline: true,
        lastSeen: DateTime.now(),
        createdAt: DateTime.now(),
      );
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(fallbackUser.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
      return fallbackUser;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Đã xảy ra lỗi khi đăng nhập: $e');
    }
  }

  /// Đăng nhập bằng Google (Hỗ trợ Firebase trực tiếp trên cả Mobile và Web)
  Future<UserModel?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        final userCredential = await _auth.signInWithPopup(googleProvider);
        final user = userCredential.user;
        if (user == null) {
          throw Exception('Đăng nhập Google thất bại');
        }

        final docRef = _firestore.collection('users').doc(user.uid);
        DocumentSnapshot? doc;
        try {
          doc = await docRef.get().timeout(const Duration(seconds: 12));
        } catch (_) {}

        if (doc != null && doc.exists) {
          try {
            await docRef.set({
              'isOnline': true,
              'lastSeen': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
          } catch (_) {}
          return UserModel.fromDocument(doc);
        } else {
          final newUser = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? (user.email?.split('@').first ?? 'Người dùng'),
            photoUrl: null, // Không lấy avatar Gmail/Google
            bio: null,
            isOnline: true,
            lastSeen: DateTime.now(),
            createdAt: DateTime.now(),
          );
          try {
            await docRef.set(newUser.toMap()).timeout(const Duration(seconds: 10));
          } catch (_) {}
          return newUser;
        }
      }

      // Trên nền tảng Native Mobile (Android & iOS)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Người dùng hủy chọn tài khoản
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Đăng nhập Google thất bại');
      }

      DocumentSnapshot? userDoc;
      try {
        userDoc = await _firestore.collection('users').doc(user.uid).get().timeout(const Duration(seconds: 12));
      } catch (_) {}

      if (userDoc == null || !userDoc.exists) {
        // Tạo tài khoản mới trên Firestore
        final newUser = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'Người dùng Google',
          photoUrl: null, // Không lấy avatar Gmail/Google
          bio: null,
          isOnline: true,
          lastSeen: DateTime.now(),
          createdAt: DateTime.now(),
        );
        try {
          await _firestore.collection('users').doc(user.uid).set(newUser.toMap()).timeout(const Duration(seconds: 10));
        } catch (_) {}
        return newUser;
      } else {
        // Cập nhật trạng thái online
        try {
          await _firestore.collection('users').doc(user.uid).update({
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 10));
        } catch (_) {}
        return UserModel.fromDocument(userDoc);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Lỗi khi đăng nhập Google: $e');
    }
  }

  /// Đăng nhập nhanh Trải nghiệm / Khách (Hỗ trợ Admin test)
  Future<UserModel> signInAnonymously({
    String displayName = 'Quản trị viên Supa',
    String role = 'admin',
  }) async {
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user!;
      await user.updateDisplayName(displayName);

      final docRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await docRef.get();
      if (!userDoc.exists) {
        final newUser = UserModel(
          uid: user.uid,
          email: 'admin_${user.uid.substring(0, 5)}@supachat.com',
          displayName: displayName,
          photoUrl: null,
          bio: null,
          isOnline: true,
          lastSeen: DateTime.now(),
          createdAt: DateTime.now(),
          role: role,
        );
        try {
          await docRef.set(newUser.toMap());
        } catch (_) {}
        return newUser;
      } else {
        return UserModel.fromDocument(userDoc);
      }
    } catch (e) {
      throw Exception('Chức năng khách đã được đóng. Vui lòng đăng nhập bằng tài khoản.');
    }
  }

  /// Đăng xuất tài khoản
  Future<void> signOut() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        try {
          // Cập nhật trạng thái offline trước khi sign out
          await _firestore.collection('users').doc(uid).update({
            'isOnline': false,
            'lastSeen': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 2));
        } catch (_) {}
      }
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw Exception('Lỗi khi đăng xuất: $e');
    }
  }

  /// Lấy thông tin chi tiết người dùng dạng Future
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get().timeout(const Duration(seconds: 3));
      if (doc.exists) {
        return UserModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Stream thông tin người dùng realtime
  Stream<UserModel?> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromDocument(doc);
      }
      return null;
    });
  }

  /// Cập nhật thông tin hồ sơ (Tên hiển thị, avatar, bio)
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
    String? bio,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final Map<String, dynamic> updates = {};

      if (displayName != null && displayName.trim().isNotEmpty) {
        updates['displayName'] = displayName.trim();
        try {
          await user.updateDisplayName(displayName.trim());
        } catch (_) {}
      }

      if (photoUrl != null && photoUrl.isNotEmpty) {
        updates['photoUrl'] = photoUrl;
        try {
          await user.updatePhotoURL(photoUrl);
        } catch (_) {}
      }

      if (bio != null) {
        updates['bio'] = bio.trim();
      }

      if (updates.isNotEmpty) {
        try {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(updates, SetOptions(merge: true))
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Đổi mật khẩu hoặc gửi email đặt lại mật khẩu
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Đổi mật khẩu trực tiếp cho người dùng đang đăng nhập
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Người dùng chưa đăng nhập');
    final email = user.email;
    if (email == null) throw Exception('Tài khoản không có email');

    try {
      final cred = EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Chuyển đổi mã lỗi Firebase Auth sang tiếng Việt thân thiện
  static String mapFirebaseAuthError(String code, [String? fallbackMessage]) {
    switch (code) {
      case 'user-not-found':
        return 'Tài khoản không tồn tại trên hệ thống.';
      case 'wrong-password':
        return 'Mật khẩu không chính xác.';
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng bởi một tài khoản khác.';
      case 'invalid-email':
        return 'Địa chỉ email không hợp lệ.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng chọn mật khẩu từ 6 ký tự trở lên.';
      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa.';
      case 'too-many-requests':
        return 'Quá nhiều lần thử thất bại. Vui lòng đợi trong giây lát và thử lại.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Vui lòng kiểm tra lại kết nối.';
      case 'unauthorized-domain':
        return 'Tên miền này chưa được thêm vào Authorized Domains trong Firebase Console. Vui lòng đăng nhập bằng Email / Mật khẩu hoặc thêm tên miền vào Firebase Console.';
      default:
        return fallbackMessage ?? 'Đã xảy ra lỗi xác thực. Mã lỗi: $code';
    }
  }

  String _handleAuthException(FirebaseAuthException e) =>
      mapFirebaseAuthError(e.code, e.message);
}
