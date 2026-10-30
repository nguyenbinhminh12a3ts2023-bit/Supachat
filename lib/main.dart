import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/auth/auth_wrapper.dart';
import 'widgets/incoming_call_listener.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  try {
    if (Firebase.apps.isEmpty) {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyB_2f1j2BXkUAb-UT2EZusl2bazIawB2mU",
            authDomain: "supachat-n1523dthc7.firebaseapp.com",
            projectId: "supachat-n1523dthc7",
            storageBucket: "supachat-n1523dthc7.firebasestorage.app",
            messagingSenderId: "725465702601",
            appId: "1:725465702601:web:68f43b2c2d0fbe6ca5ed18",
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
    }
  } catch (e) {
    debugPrint('Lưu ý Firebase Init: $e');
  }

  runApp(const SupaChatApp());
}


class SupaChatApp extends StatelessWidget {
  const SupaChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) {
          return MaterialApp(
            title: 'SupaChat',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: Locale(localeProvider.languageCode),
            home: const IncomingCallListener(child: AuthWrapper()),
          );
        },
      ),
    );
  }
}
