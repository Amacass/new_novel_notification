import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initSupabase() async {
  final url = dotenv.env['SUPABASE_URL'];
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
    throw StateError(
      '.env ファイルに SUPABASE_URL と SUPABASE_ANON_KEY が必要です',
    );
  }

  await Supabase.initialize(url: url, anonKey: anonKey);
}

SupabaseClient get supabase => Supabase.instance.client;
