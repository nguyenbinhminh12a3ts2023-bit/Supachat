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
    return result;
  }

  /// Tìm kiếm người dùng chính xác theo Email hoặc Tên hiển thị (Hỗ trợ tiếng Việt có dấu và không dấu)
  Future<List<UserModel>> searchUsersByEmail(String query) async {
    final queryText = query.trim().toLowerCase().replaceAll('@', '');
    if (queryText.isEmpty) return [];

    final normalizedQuery = _normalizeString(queryText);
    final currentUid = currentUserId;
    final Set<String> foundUids = {};
    final List<UserModel> results = [];

    try {
      // Đọc toàn bộ danh sách người dùng trên Firestore (không dùng range filter tránh lỗi index)
      final allDocs = await _firestore.collection('users').limit(100).get().timeout(const Duration(seconds: 10));
      for (var doc in allDocs.docs) {
        if (doc.id == currentUid) continue;

        final u = UserModel.fromDocument(doc);
        final name = u.displayName.toLowerCase();
        final email = u.email.toLowerCase();
        final normalizedName = _normalizeString(u.displayName);
        final normalizedEmail = _normalizeString(u.email);

        if (name.contains(queryText) ||
            normalizedName.contains(normalizedQuery) ||
            email.contains(queryText) ||
            normalizedEmail.contains(normalizedQuery) ||
            u.uid == queryText) {
          if (!foundUids.contains(doc.id)) {
            foundUids.add(doc.id);
            results.add(u);
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi tìm kiếm người dùng: $e');
    }

    return results;
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
