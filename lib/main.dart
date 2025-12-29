import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/core/theme/app_theme.dart';
import 'package:ready_check/screens/splash_screen.dart';
import 'package:ready_check/screens/session/ready_check_overlay.dart';
import 'package:ready_check/services/auth_service.dart';
import 'package:ready_check/services/fcm_service.dart';

import 'package:ready_check/services/lobby_service.dart';
import 'package:ready_check/services/session_service.dart';
import 'package:ready_check/services/circle_service.dart';
import 'package:ready_check/services/theme_service.dart';
import 'package:ready_check/services/sound_service.dart';
import 'package:ready_check/services/notification_service.dart';
import 'package:ready_check/services/friend_service.dart';
import 'package:ready_check/services/direct_chat_service.dart';
import 'package:ready_check/services/call_service.dart';

// Global navigator key for FCM navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Initialize notifications early
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(MyApp(notificationService: notificationService));
}

class MyApp extends StatefulWidget {
  final NotificationService notificationService;

  const MyApp({super.key, required this.notificationService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize FCM after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService().initialize(navigatorKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LobbyService()), 
        ChangeNotifierProvider(create: (_) => SessionService()),
        ChangeNotifierProvider(create: (_) => CircleService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => FriendService()),
        ChangeNotifierProvider(create: (_) => DirectChatService()),
        ChangeNotifierProvider(create: (_) => CallService()),
        Provider<SoundService>(create: (_) => SoundService()),
        Provider<NotificationService>.value(value: widget.notificationService),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Ready Check',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeService.themeMode,
            home: const SplashScreen(),
            routes: {
              '/ready-check': (context) {
                final sessionId = ModalRoute.of(context)?.settings.arguments as String?;
                if (sessionId != null) {
                  return ReadyCheckOverlay(sessionId: sessionId);
                }
                return const SplashScreen();
              },
            },
          );
        },
      ),
    );
  }
}
