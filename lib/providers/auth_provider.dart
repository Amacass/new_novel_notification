import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase.dart';

// Safari Extension がトークンを読めるよう App Group に保存する
const _sessionChannel = MethodChannel('com.amacass.novelNotification/session');

Future<void> _syncSessionToAppGroup(Session? session) async {
  try {
    if (session != null) {
      await _sessionChannel.invokeMethod('saveSession', {
        'access_token': session.accessToken,
      });
    } else {
      await _sessionChannel.invokeMethod('clearSession');
    }
  } catch (_) {
    // iOS 以外のプラットフォームでは無視
  }
}

final authStateProvider = StreamProvider<Session?>((ref) {
  final stream = supabase.auth.onAuthStateChange.map((event) => event.session);
  // セッション変化のたびに App Group へ同期
  stream.listen(_syncSessionToAppGroup);
  return stream;
});

final currentUserProvider = Provider<User?>((ref) {
  return supabase.auth.currentUser;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> deleteAccount() async {
    await supabase.functions.invoke('delete-account');
    await supabase.auth.signOut();
  }
}
