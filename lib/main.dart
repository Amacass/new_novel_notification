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
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await initSupabase();

  // Initialize Firebase (requires GoogleService-Info.plist / google-services.json)
  await Firebase.initializeApp();

  // Set Japanese locale for timeago
  timeago.setLocaleMessages('ja', timeago.JaMessages());

  final container = ProviderContainer();

  // Listen for shared URLs from iOS Share Extension
  const channel = MethodChannel('com.amacass.novelNotification/share');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'sharedUrl') {
      final url = call.arguments as String?;
      if (url != null && url.isNotEmpty) {
        container.read(sharedUrlProvider.notifier).state = url;
      }
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

  // FCM初期化（ログイン後に実行される前提でrunApp後に呼ぶ）
  await FcmService().initialize();
}
