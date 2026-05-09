import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class FCMService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ── Get the current FCM token ──
  static Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('FCMService.getToken error: $e');
      return null;
    }
  }

  static Future<void> initFCM() async {
    // Request permissions for iOS and Android 13+
    NotificationSettings settings =
        await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // ── Setup local notifications for foreground popups ──
      const AndroidInitializationSettings initSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      await _localNotifications.initialize(
        settings: const InitializationSettings(android: initSettingsAndroid),
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          print('Notification tapped: ${details.payload}');
        },
      );

      // Create the high-importance notification channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // ── Upload the CURRENT token immediately on startup ──
      // This ensures the DB always has a valid token even if login
      // happened before permissions were granted.
      final currentToken = await _firebaseMessaging.getToken();
      if (currentToken != null) {
        print('FCM Token (startup): ${currentToken.substring(0, 20)}...');
        await _uploadTokenToBackend(currentToken);
      }

      // ── Listen to token refreshes and keep backend in sync ──
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        print('FCM Token Refreshed: ${newToken.substring(0, 20)}...');
        await _uploadTokenToBackend(newToken);
      });

      // ── Handle foreground messages (show local notification) ──
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final String? title =
            message.notification?.title ?? message.data['title'];
        final String? body =
            message.notification?.body ?? message.data['body'];

        if (title != null && body != null) {
          _localNotifications.show(
            id: message.hashCode,
            title: title,
            body: body,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                channelDescription:
                    'This channel is used for important notifications.',
                icon: '@mipmap/ic_launcher',
                importance: Importance.max,
                priority: Priority.high,
                ticker: 'ticker',
                fullScreenIntent: true,
              ),
            ),
          );
        }
      });
    }
  }

  // ── Upload FCM token to backend (farmer or officer) ──
  static Future<void> _uploadTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role');
      final deviceId = prefs.getString('device_id');
      final officerId = prefs.getString('officer_id');

      // Can't upload if not yet logged in — login flow handles first upload
      if (role == null) {
        print('FCM upload skipped: user not logged in yet');
        return;
      }

      final bodyMap = <String, String>{'fcmToken': token};
      String endpoint;

      if (role == 'farmer' && deviceId != null) {
        bodyMap['deviceId'] = deviceId;
        endpoint = '${ApiConfig.baseUrl}/api/mobile/update-fcm-token';
      } else if (role == 'officer' && officerId != null) {
        bodyMap['officerId'] = officerId;
        endpoint = '${ApiConfig.baseUrl}/api/mobile/update-fcm-token';
      } else {
        print('FCM upload skipped: no valid ID found');
        return;
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyMap),
      );
      print('FCM token upload status: ${response.statusCode}');
    } catch (e) {
      print('FCM token upload error: $e');
    }
  }
}
