import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'welcome_screen.dart';

/// Cổng kiểm tra phiên đăng nhập tự động (Auth Gate / Auth Wrapper)
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    if (authProvider.isAuthenticated) {
      return const HomeScreen();
    }

    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Đang kiểm tra phiên đăng nhập lưu trong máy
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_rounded, size: 64, color: AppColors.primary),
                  SizedBox(height: 16),
                  CircularProgressIndicator(color: AppColors.primary),
                ],
              ),
            ),
          );
        }

        // Đã đăng nhập -> Chuyển thẳng vào màn hình chính
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }

        // Chưa đăng nhập -> Vào màn hình Chào mừng chuẩn Figma
        return const WelcomeScreen();
      },
    );
  }
}
