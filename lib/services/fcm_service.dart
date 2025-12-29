import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Singleton pattern
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  // Navigation key for background navigation
  static GlobalKey<NavigatorState>? navigatorKey;

  Future<void> initialize(GlobalKey<NavigatorState> navKey) async {
    navigatorKey = navKey;
    
    // Request permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );
    
    debugPrint('FCM Permission: ${settings.authorizationStatus}');

    // Initialize local notifications
    await _initLocalNotifications();

    // Get and store token
    await _getAndStoreToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveToken);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check initial message (app opened from terminated state)
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        final payload = response.payload;
        if (payload != null) {
          _navigateFromPayload(payload);
        }
      },
    );

    // Create notification channels
    const AndroidNotificationChannel summonChannel = AndroidNotificationChannel(
      'summon_channel',
      'Ready Check',
      description: 'Notifications for Ready Check summons',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      'chat_channel',
      'Chat Messages',
      description: 'Notifications for chat messages',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(summonChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(chatChannel);
  }

  Future<void> _getAndStoreToken() async {
    String? token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('FCM Token saved for user: ${user.uid}');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');
    
    final data = message.data;
    final type = data['type'];

    if (type == 'summon') {
      // Navigate directly to ReadyCheckOverlay + play audio (no notification)
      final sessionId = data['sessionId'];
      if (sessionId != null) {
        _navigateToReadyCheck(sessionId);
        // Audio is played in ReadyCheckOverlay itself
      }
    } else if (type == 'chat' || type == 'dm') {
      // Show regular notification for chat/dm
      _showChatNotification(message);
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    
    if (type == 'summon') {
      final sessionId = data['sessionId'];
      if (sessionId != null) {
        _navigateToReadyCheck(sessionId);
      }
    } else if (type == 'chat') {
      final circleId = data['circleId'];
      if (circleId != null) {
        // Could navigate to circle chat
        debugPrint('Navigate to circle: $circleId');
      }
    }
  }

  void _navigateFromPayload(String payload) {
    // Payload format: "type:id"
    final parts = payload.split(':');
    if (parts.length == 2) {
      if (parts[0] == 'summon') {
        _navigateToReadyCheck(parts[1]);
      }
    }
  }

  void _navigateToReadyCheck(String sessionId) {
    if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.pushNamed('/ready-check', arguments: sessionId);
    }
  }

  Future<void> _showSummonNotification(RemoteMessage message) async {
    final data = message.data;
    final sessionId = data['sessionId'] ?? '';
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'READY CHECK!',
      message.notification?.body ?? 'Your squad needs you!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'summon_channel',
          'Ready Check',
          channelDescription: 'Notifications for Ready Check summons',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true, // Full screen like phone call
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
          ongoing: true, // Can't be swiped away
          autoCancel: false,
        ),
      ),
      payload: 'summon:$sessionId',
    );
  }

  Future<void> _showChatNotification(RemoteMessage message) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? 'You have a new message',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_channel',
          'Chat Messages',
          channelDescription: 'Notifications for chat messages',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.data}');
  
  final data = message.data;
  final type = data['type'];
  
  if (type == 'summon') {
    // Show fullScreenIntent notification for summon
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    
    // Initialize
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await localNotifications.initialize(initSettings);
    
    final sessionId = data['sessionId'] ?? '';
    final title = data['title'] ?? '⚡ READY CHECK!';
    final body = data['body'] ?? 'Your squad needs you!';
    
    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'summon_channel',
          'Ready Check',
          channelDescription: 'Notifications for Ready Check summons',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true, // Shows like phone call
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          playSound: false, // We play our own sound in the overlay
          enableVibration: true,
          ongoing: true,
          autoCancel: false,
        ),
      ),
      payload: 'summon:$sessionId',
    );
  }
}
