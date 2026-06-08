import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'app.dart';
import 'config/supabase.dart';
import 'providers/shared_url_provider.dart';
import 'services/fcm_service.dart';

Future<void> main() async {
  await runZonedGuarded(_main, (error, stack) {
    debugPrint('FATAL ERROR: $error\n$stack');
  });
}

Future<void> _main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'development');
  await dotenv.load(fileName: '.env.$flavor');

  // Initialize Supabase
  await initSupabase();

  // Initialize Firebase (requires GoogleService-Info.plist / google-services.json)
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  timeago.setLocaleMessages('ja', _JaMessages());

  final container = ProviderContainer();

  // Listen for shared URLs from Safari Extension (sent as a batch array)
  const channel = MethodChannel('com.amacass.novelNotification/share');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'sharedUrls') {
      final incoming = (call.arguments as List?)
          ?.whereType<String>()
          .where((u) => u.isNotEmpty)
          .toList() ?? [];
      if (incoming.isEmpty) return;
      final current = container.read(sharedUrlProvider);
      container.read(sharedUrlProvider.notifier).state = [...current, ...incoming];
    }
  });

  // Catch unhandled Flutter errors to prevent white screen crashes
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );

  // FCM初期化（Firebase が初期化できた場合のみ実行）
  if (firebaseInitialized) {
    try {
      await FcmService().initialize();
    } catch (e) {
      debugPrint('FCM initialization failed: $e');
    }
  }
}

class _JaMessages implements timeago.LookupMessages {
  @override String prefixAgo() => '';
  @override String prefixFromNow() => '';
  @override String suffixAgo() => '前';
  @override String suffixFromNow() => '後';
  @override String lessThanOneMinute(int seconds) => 'たった今';
  @override String aboutAMinute(int minutes) => '1分';
  @override String minutes(int minutes) => '$minutes分';
  @override String aboutAnHour(int minutes) => '${minutes ~/ 60}時間';
  @override String hours(int hours) => '$hours時間';
  @override String aDay(int hours) => '${hours ~/ 24}日';
  @override String days(int days) => '$days日';
  @override String aboutAMonth(int days) => '${days ~/ 30}ヶ月';
  @override String months(int months) => '$months月';
  @override String aboutAYear(int year) => '約1年';
  @override String years(int years) => '$years年';
  @override String wordSeparator() => '';
}
