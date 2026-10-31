import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/friend_service.dart';
import '../../services/post_service.dart';
import '../../widgets/avatar_crop_dialog.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/custom_text_field.dart';
import '../feed/create_post_screen.dart';
import '../friends/friends_list_screen.dart';
import '../settings/settings_screen.dart';
import '../story/story_archive_screen.dart';

/// Màn hình Hồ sơ cá nhân chuẩn Instagram / Facebook
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final PostService _postService = PostService();
  final FriendService _friendService = FriendService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (picked != null && mounted) {
        final rawBytes = await picked.readAsBytes();
        if (!mounted) return;

        final croppedBytes = await AvatarCropDialog.show(context, rawBytes);
        if (croppedBytes == null || !mounted) return;

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.updateAvatarBytes(croppedBytes);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã cập nhật ảnh đại diện thành công'),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authProvider.errorMessage ?? 'Không thể tải ảnh đại diện lên.'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chọn ảnh: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showImagePickerModal() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final hasCustomAvatar = authProvider.currentUserModel?.photoUrl != null &&
        authProvider.currentUserModel!.photoUrl!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thay đổi ảnh đại diện',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: const Text('Chụp ảnh mới'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.accent),
                ),
                title: const Text('Chọn từ thư viện'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              if (hasCustomAvatar)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.coralDanger.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.coralDanger),
                  ),
                  title: const Text(
                    'Xóa ảnh đại diện',
                    style: TextStyle(color: AppColors.coralDanger, fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final success = await authProvider.deleteAvatar();
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã xóa ảnh đại diện thành công!'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserModel;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user?.displayName ?? '');
    final bioController = TextEditingController(text: user?.bio ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Chỉnh sửa thông tin', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                label: 'Họ và tên',
                hint: 'Nhập tên hiển thị mới',
                validator: (val) {
                  final trimmed = val?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Họ tên không được để trống';
                  if (trimmed.length < 2) return 'Họ tên phải có ít nhất 2 ký tự';
                  if (trimmed.length > 50) return 'Họ tên không vượt quá 50 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: bioController,
                label: 'Tiểu sử',
                hint: 'Giới thiệu về bạn...',
                maxLines: 3,
                validator: (val) {
                  final trimmed = val?.trim() ?? '';
                  if (trimmed.length > 150) return 'Tiểu sử tối đa 150 ký tự';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final success = await authProvider.updateProfile(
                  displayName: nameController.text,
                  bio: bioController.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã cập nhật thông tin thành công!'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Lưu thay đổi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showShareProfileDialog(String name, String handle) {
    final baseUrl = kIsWeb ? Uri.base.origin : 'http://localhost:62727';
    final shareLink = '$baseUrl/#/profile/$handle';
    Clipboard.setData(ClipboardData(text: shareLink));

    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
          final textP = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
          final textS = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

          return Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textS.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Đã sao chép liên kết trang cá nhân!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textP),
                ),
                const SizedBox(height: 8),
                Text(
                  shareLink,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bạn bè có thể truy cập liên kết trên hoặc tìm kiếm @$handle trên SupaChat',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: textS),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Đã hiểu', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    final displayName = user?.displayName != null && user!.displayName.isNotEmpty
        ? user.displayName
        : (user?.email != null ? user!.email.split('@').first : 'Thành viên');
    final handleName = user?.email != null ? user!.email.split('@').first : 'user';
    final bio = user?.bio != null && user!.bio!.isNotEmpty ? user.bio! : 'Chào mừng bạn đến với trang cá nhân SupaChat! ✨';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          '@$handleName',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textPrimary),
            tooltip: 'Cài đặt',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Avatar & Stats
                    StreamBuilder<List<PostModel>>(
                      stream: _postService.getPostsStream(),
                      builder: (context, snapshot) {
                        final allPosts = snapshot.data ?? [];
                        final myPosts = allPosts.where((p) => p.authorId == user?.uid).toList();
                        final totalLikes = myPosts.fold<int>(0, (total, p) => total + p.likes.length);

                        return Row(
                          children: [
                            // Avatar với nút đổi ảnh
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [AppColors.gradientStart, AppColors.gradientEnd],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: AvatarWidget(
                                    photoUrl: user?.photoUrl,
                                    name: displayName,
                                    radius: 40,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    onTap: _showImagePickerModal,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: bg, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),

                            // Stats: Bài viết, Bạn bè, Tim (Dữ liệu thật 100%)
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatColumn('${myPosts.length}', 'Bài viết', textPrimary, textSecondary),
                                  StreamBuilder<List<UserModel>>(
                                    stream: _friendService.getFriendsListStream(),
                                    builder: (context, friendSnapshot) {
                                      final friendList = friendSnapshot.data ?? [];
                                      final count = friendSnapshot.hasData
                                          ? friendList.length
                                          : (user?.friendsList.length ?? 0);
                                      return _buildStatColumn(
                                        '$count',
                                        'Bạn bè',
                                        textPrimary,
                                        textSecondary,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const FriendsListScreen()),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  _buildStatColumn('$totalLikes', 'Lượt thích', textPrimary, textSecondary),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // Tên & Bio
                    Text(
                      displayName,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bio,
                      style: TextStyle(fontSize: 13, color: textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 16),

                    // Action buttons chuẩn Instagram: Chỉnh sửa trang cá nhân & Chia sẻ trang cá nhân
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textPrimary,
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                            onPressed: _showEditProfileDialog,
                            child: const Text('Chỉnh sửa trang cá nhân', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textPrimary,
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                            onPressed: () => _showShareProfileDialog(displayName, handleName),
                            child: const Text('Chia sẻ trang cá nhân', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Nút mở Kho lưu trữ tin (Story Archive)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                          side: BorderSide(color: (isDark ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.35)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                        icon: const Icon(Icons.auto_stories_rounded, size: 18),
                        label: const Text('Kho lưu trữ tin (Story Archive)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const StoryArchiveScreen()),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Tab bar (Grid Bài viết & Âm thanh)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: textSecondary,
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.grid_on_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Bài viết', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Phương tiện ảnh & video', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                bg,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Grid Bài viết cá nhân
            StreamBuilder<List<PostModel>>(
              stream: _postService.getPostsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allPosts = snapshot.data ?? [];
                final myPosts = allPosts.where((p) => p.authorId == user?.uid).toList();

                if (myPosts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_camera_back_outlined, size: 64, color: textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có bài viết nào',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Khi bạn chia sẻ ảnh hoặc bài viết, chúng sẽ xuất hiện ở đây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: textSecondary),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Tạo bài viết đầu tiên', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: myPosts.length,
                  itemBuilder: (context, index) {
                    final post = myPosts[index];
                    return GestureDetector(
                      onTap: () {
                        // Xem chi tiết bài viết
                        _showPostDetailModal(context, post, isDark, cardBg, textPrimary, textSecondary);
                      },
                      child: Container(
                        color: isDark ? AppColors.darkSurface : Colors.grey[200],
                        child: post.imageUrl != null
                            ? (post.imageUrl!.startsWith('data:image')
                                ? Image.memory(
                                    base64Decode(post.imageUrl!.split(',').last),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                                  )
                                : Image.network(
                                    post.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                                  ))
                            : Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    post.content,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                );
              },
            ),

            // Tab 2: Phương tiện ảnh & video của người dùng
            StreamBuilder<List<PostModel>>(
              stream: _postService.getPostsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allPosts = snapshot.data ?? [];
                final myMediaPosts = allPosts
                    .where((p) => p.authorId == user?.uid && p.imageUrl != null && p.imageUrl!.isNotEmpty)
                    .toList();

                if (myMediaPosts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library_outlined, size: 64, color: textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có ảnh hoặc video nào',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Khi bạn đăng tải hình ảnh hoặc video trong bài viết, chúng sẽ xuất hiện đầy đủ ở đây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: myMediaPosts.length,
                  itemBuilder: (context, index) {
                    final post = myMediaPosts[index];
                    return GestureDetector(
                      onTap: () => _showPostDetailModal(
                        context,
                        post,
                        isDark,
                        cardBg,
                        textPrimary,
                        textSecondary,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              post.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                child: const Icon(Icons.broken_image_rounded),
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 10),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${post.likes.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPostDetailModal(
    BuildContext context,
    PostModel post,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Builder(builder: (c) {
              final authUser = Provider.of<AuthProvider>(c, listen: false).currentUserModel;
              final currentAvatar = (post.authorId == authUser?.uid && authUser?.photoUrl != null)
                  ? authUser!.photoUrl
                  : post.authorAvatar;
              return Row(
                children: [
                  AvatarWidget(photoUrl: currentAvatar, name: post.authorName, radius: 18),
                  const SizedBox(width: 10),
                  Text(post.authorName, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.coralDanger, size: 20),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _postService.deletePost(post.id);
                    },
                  ),
                ],
              );
            }),
            if (post.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: post.imageUrl!.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(post.imageUrl!.split(',').last),
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        post.imageUrl!,
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
            ],
            const SizedBox(height: 12),
            Text(post.content, style: TextStyle(color: textPrimary, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.favorite, color: AppColors.coralDanger, size: 18),
                const SizedBox(width: 4),
                Text('${post.likes.length}', style: TextStyle(color: textSecondary, fontSize: 13)),
                const SizedBox(width: 16),
                const Icon(Icons.comment_outlined, size: 18),
                const SizedBox(width: 4),
                Text('${post.commentsCount}', style: TextStyle(color: textSecondary, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label, Color textPrimary, Color textSecondary, {VoidCallback? onTap}) {
    final col = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: col,
        ),
      );
    }
    return col;
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverAppBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
