import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/supabase.dart';

// バックグラウンドメッセージハンドラ（トップレベル関数必須）
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // バックグラウンドではOSが通知を表示するため特に処理不要
  debugPrint('Background message: ${message.messageId}');
}

class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'novel_updates',
    '小説更新通知',
    description: '登録した小説が更新されたときに通知します',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    // バックグラウンドハンドラ登録
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // iOS の通知許可を要求
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM: 通知が拒否されました');
      return;
    }

    // フォアグラウンドで通知を表示する設定 (iOS)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android のローカル通知チャンネル作成
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // ローカル通知の初期化
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(initSettings);

    // フォアグラウンドでのメッセージ受信
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // FCMトークン取得・登録
    await _registerToken();

    // トークン更新時の再登録
    _messaging.onTokenRefresh.listen(_sendTokenToServer);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _sendTokenToServer(token);
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;

      await supabase.functions.invoke(
        'register-fcm-token',
        body: {
          'token': token,
          'platform': defaultTargetPlatform.name.toLowerCase(),
        },
      );
    } catch (e) {
      debugPrint('FCM token send error: $e');
    }
  }
}
