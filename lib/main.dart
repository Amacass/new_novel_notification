import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'app.dart';
import 'config/supabase.dart';
import 'providers/shared_url_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await initSupabase();

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
}
