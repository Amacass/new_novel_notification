import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'app.dart';
import 'config/supabase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await initSupabase();

  // Set Japanese locale for timeago
  timeago.setLocaleMessages('ja', timeago.JaMessages());

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
