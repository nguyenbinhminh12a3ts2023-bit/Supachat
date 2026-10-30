import 'package:cloud_firestore/cloud_firestore.dart';

/// Model thông tin người dùng trong ứng dụng SupaChat
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? bio;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;
  final List<String> friendsList;
  final bool isVerified;
  final double? latitude;
  final double? longitude;
  final String? locationCity;
  final String role; // 'user' hoặc 'admin'
  final bool isLocationSharingEnabled; // Quyền riêng tư Opt-in vị trí

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.bio,
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
    this.friendsList = const [],
    this.isVerified = false,
    this.latitude,
    this.longitude,
    this.locationCity,
    this.role = 'user',
    this.isLocationSharingEnabled = false,
  });

  /// Kiểm tra xem người dùng có phải là Quản trị viên (Admin) không
  bool get isAdmin => role == 'admin' || email.toLowerCase().contains('admin');

  /// Chuyển đổi dữ liệu UserModel sang Map để lưu trên Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl ?? '',
      'bio': bio,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : FieldValue.serverTimestamp(),
      'createdAt': Timestamp.fromDate(createdAt),
      'friendsList': friendsList,
      'isVerified': isVerified,
      'role': role,
      'isLocationSharingEnabled': isLocationSharingEnabled,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationCity != null) 'locationCity': locationCity,
    };
  }

  /// Chuyển đổi dữ liệu sang Map dạng JSON thuần để lưu trữ cục bộ SharedPreferences
  Map<String, dynamic> toJsonMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'friendsList': friendsList,
      'isVerified': isVerified,
      'role': role,
      'isLocationSharingEnabled': isLocationSharingEnabled,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationCity != null) 'locationCity': locationCity,
    };
  }

  /// Khởi tạo UserModel từ DocumentSnapshot của Firestore
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  /// Khởi tạo UserModel từ Map
  factory UserModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return UserModel(
      uid: id ?? map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? 'Người dùng',
      photoUrl: (map['photoUrl'] as String?)?.isNotEmpty == true ? map['photoUrl'] : null,
      bio: (map['bio'] as String?)?.isNotEmpty == true && map['bio'] != 'Xin chào, tôi đang dùng SupaChat.' ? map['bio'] : null,
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null ? parseDate(map['lastSeen']) : null,
      createdAt: map['createdAt'] != null ? parseDate(map['createdAt']) : DateTime.now(),
      friendsList: List<String>.from(map['friendsList'] ?? []),
      isVerified: map['isVerified'] ?? false,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationCity: map['locationCity'] as String?,
      role: map['role'] ?? 'user',
      isLocationSharingEnabled: map['isLocationSharingEnabled'] ?? false,
    );
  }

  /// Tạo bản sao với các trường được cập nhật
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool nullifyPhotoUrl = false,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
    List<String>? friendsList,
    bool? isVerified,
    double? latitude,
    double? longitude,
    String? locationCity,
    String? role,
    bool? isLocationSharingEnabled,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: nullifyPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      friendsList: friendsList ?? this.friendsList,
      isVerified: isVerified ?? this.isVerified,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationCity: locationCity ?? this.locationCity,
      role: role ?? this.role,
      isLocationSharingEnabled: isLocationSharingEnabled ?? this.isLocationSharingEnabled,
    );
  }
}
