import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';

/// Dịch vụ xử lý Tìm kiếm, Lời mời kết bạn và Danh sách bạn bè trên Firestore
class FriendService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? get currentUserId {
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  String _normalizeString(String str) {
    var result = str.toLowerCase().trim();
    const withDiacritics = 'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
    const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    result = result.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
    result = result.replaceAll('đ', 'd').replaceAll('Đ', 'd');
    return result;
  }

  /// Tìm kiếm người dùng chính xác theo Email hoặc Tên hiển thị (Hỗ trợ tiếng Việt có dấu và không dấu)
  Future<List<UserModel>> searchUsersByEmail(String query) async {
    final rawQuery = query.trim().toLowerCase();
    if (rawQuery.isEmpty) return [];

    final cleanQuery = rawQuery.replaceAll('@', '');
    final normalizedQuery = _normalizeString(rawQuery);
    final normalizedClean = _normalizeString(cleanQuery);
    final currentUid = currentUserId;
    final Map<String, UserModel> resultsMap = {};

    // 1. Tìm trực tiếp bằng Firestore query theo email chính xác (ngay cả khi có hàng nghìn user)
    try {
      final emailQuerySnap = await _firestore
          .collection('users')
          .where('email', isEqualTo: query.trim())
          .get()
          .timeout(const Duration(seconds: 6));
      for (var doc in emailQuerySnap.docs) {
        if (doc.id != currentUid) {
          resultsMap[doc.id] = UserModel.fromDocument(doc);
        }
      }
    } catch (_) {}

    // 1b. Thử lowercase email nếu khác
    if (rawQuery != query.trim()) {
      try {
        final emailLowerSnap = await _firestore
            .collection('users')
            .where('email', isEqualTo: rawQuery)
            .get()
            .timeout(const Duration(seconds: 6));
        for (var doc in emailLowerSnap.docs) {
          if (doc.id != currentUid) {
            resultsMap[doc.id] = UserModel.fromDocument(doc);
          }
        }
      } catch (_) {}
    }

    // 2. Quét danh sách người dùng trên Firestore để tìm kiếm linh hoạt (fuzzy search: tên, email, uid)
    try {
      final allDocs = await _firestore
          .collection('users')
          .limit(200)
          .get()
          .timeout(const Duration(seconds: 10));

      for (var doc in allDocs.docs) {
        if (doc.id == currentUid || resultsMap.containsKey(doc.id)) continue;

        final u = UserModel.fromDocument(doc);
        final uEmail = u.email.trim().toLowerCase();
        final uName = u.displayName.trim().toLowerCase();
        final uEmailPrefix = uEmail.split('@').first;
        final uNormName = _normalizeString(uName);
        final uNormEmail = _normalizeString(uEmail);

        // So khớp đa năng: Email đầy đủ, Tiền tố email, Tên có dấu, Tên không dấu, UID
        final isMatch = uEmail == rawQuery ||
            uEmail.contains(rawQuery) ||
            uEmailPrefix == cleanQuery ||
            uEmailPrefix.contains(cleanQuery) ||
            uName.contains(rawQuery) ||
            uNormName.contains(normalizedQuery) ||
            uNormName.contains(normalizedClean) ||
            uNormEmail.contains(normalizedQuery) ||
            u.uid == rawQuery;

        if (isMatch) {
          resultsMap[doc.id] = u;
        }
      }
    } catch (e) {
      debugPrint('Lỗi tìm kiếm người dùng: $e');
    }

    return resultsMap.values.toList();
  }

  /// Lấy danh sách người dùng thật trên Firestore để gợi ý kết bạn
  Stream<List<UserModel>> getSuggestedUsersStream() {
    final uid = currentUserId;
    return _firestore.collection('users').limit(30).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromDocument(doc))
          .where((user) => user.uid != uid)
          .toList();
    });
  }

  /// Gửi lời mời kết bạn (Thêm doc vào collection `friend_requests`)
  Future<void> sendFriendRequest(UserModel targetUser) async {
    final sender = _auth.currentUser;
    if (sender == null) throw Exception('Người dùng chưa đăng nhập');
    if (sender.uid == targetUser.uid) {
      throw Exception('Không thể tự kết bạn với chính mình');
    }

    // 1. Kiểm tra xem đã là bạn bè chưa
    final myDoc = await _firestore.collection('users').doc(sender.uid).get();
    final myUserData = UserModel.fromDocument(myDoc);
    if (myUserData.friendsList.contains(targetUser.uid)) {
      throw Exception('Hai người đã là bạn bè');
    }

    // 2. Kiểm tra xem đã gửi lời mời đang chờ (pending) trước đó chưa
    final existingSent = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: sender.uid)
        .where('receiverId', isEqualTo: targetUser.uid)
        .where('status', isEqualTo: FriendRequestStatus.pending)
        .get();

    if (existingSent.docs.isNotEmpty) {
      throw Exception('Bạn đã gửi lời mời kết bạn cho người này rồi');
    }

    // 3. Kiểm tra xem đối phương có gửi lời mời cho mình trước đó không
    final existingReceived = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: targetUser.uid)
        .where('receiverId', isEqualTo: sender.uid)
        .where('status', isEqualTo: FriendRequestStatus.pending)
        .get();

    if (existingReceived.docs.isNotEmpty) {
      // Đối phương đã gửi lời mời, tự động chấp nhận luôn!
      final reqDoc = existingReceived.docs.first;
      await acceptFriendRequest(FriendRequestModel.fromDocument(reqDoc));
      return;
    }

    // 4. Tạo document mới trong collection `friend_requests`
    final requestRef = _firestore.collection('friend_requests').doc();
    final request = FriendRequestModel(
      id: requestRef.id,
      senderId: sender.uid,
      receiverId: targetUser.uid,
      senderEmail: sender.email ?? myUserData.email,
      senderName: sender.displayName ?? myUserData.displayName,
      senderPhotoUrl: sender.photoURL ?? myUserData.photoUrl,
      status: FriendRequestStatus.pending,
      timestamp: DateTime.now(),
    );

    await requestRef.set(request.toMap());
  }

  /// Stream lắng nghe danh sách lời mời kết bạn ĐẾN theo thời gian thực (Realtime)
  Stream<List<FriendRequestModel>> getReceivedFriendRequestsStream() {
    final uid = currentUserId;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: FriendRequestStatus.pending)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => FriendRequestModel.fromDocument(doc))
          .toList();
      // Sắp xếp client-side để không yêu cầu index tổng hợp
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  /// Chấp nhận lời mời kết bạn:
  /// 1. Cập nhật status thành 'accepted'
  /// 2. Cập nhật `friendsList` của cả 2 user bằng FieldValue.arrayUnion
  Future<void> acceptFriendRequest(FriendRequestModel request) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Người dùng chưa đăng nhập');

    final batch = _firestore.batch();

    // 1. Cập nhật status lời mời
    final requestRef = _firestore.collection('friend_requests').doc(request.id);
    batch.update(requestRef, {'status': FriendRequestStatus.accepted});

    // 2. Thêm senderId vào friendsList của mình (receiver)
    final myUserRef = _firestore.collection('users').doc(request.receiverId);
    batch.update(myUserRef, {
      'friendsList': FieldValue.arrayUnion([request.senderId]),
    });

    // 3. Thêm receiverId vào friendsList của người gửi (sender)
    final senderUserRef = _firestore.collection('users').doc(request.senderId);
    batch.update(senderUserRef, {
      'friendsList': FieldValue.arrayUnion([request.receiverId]),
    });

    await batch.commit();
  }

  /// Từ chối lời mời kết bạn (Cập nhật status: 'rejected')
  Future<void> rejectFriendRequest(FriendRequestModel request) async {
    await _firestore
        .collection('friend_requests')
        .doc(request.id)
        .update({'status': FriendRequestStatus.rejected});
  }

  /// Stream lắng nghe danh sách bạn bè realtime từ `friendsList` của user hiện tại
  Stream<List<UserModel>> getFriendsListStream() {
    final uid = currentUserId;
    if (uid == null) return const Stream.empty();

    return _firestore.collection('users').doc(uid).snapshots().asyncMap((doc) async {
      if (!doc.exists) return [];

      final data = doc.data() ?? {};
      final List<String> friendUids = List<String>.from(data['friendsList'] ?? []);

      if (friendUids.isEmpty) return [];

      // Do Firestore giới hạn whereIn tối đa 10/30 phần tử, ta chia chunk hoặc fetch song song
      final List<UserModel> friends = [];
      final chunks = <List<String>>[];
      for (var i = 0; i < friendUids.length; i += 10) {
        chunks.add(friendUids.sublist(i, i + 10 > friendUids.length ? friendUids.length : i + 10));
      }

      for (var chunk in chunks) {
        final query = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        friends.addAll(query.docs.map((d) => UserModel.fromDocument(d)));
      }

      return friends;
    });
  }
}
