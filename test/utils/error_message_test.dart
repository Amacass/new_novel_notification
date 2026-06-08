import 'package:flutter_test/flutter_test.dart';
import 'package:novelmark/utils/error_message.dart';

void main() {
  group('isNetworkError', () {
    test('本番で観測されたトークンリフレッシュの通信失敗を検知する', () {
      const raw =
          'AuthRetryableFetchException(message: ClientException with '
          'SocketException: Failed host lookup: '
          "'zrxsapgvlflxitddeqcn.supabase.co' (OS Error: nodename nor "
          'servname provided, or not known, errno = 8), '
          'uri=https://zrxsapgvlflxitddeqcn.supabase.co/auth/v1/token'
          '?grant_type=refresh_token, statusCode: null)';
      expect(isNetworkError(raw), isTrue);
    });

    test('各種ソケット/接続系エラーを検知する', () {
      expect(isNetworkError('SocketException: Connection refused'), isTrue);
      expect(isNetworkError('TimeoutException after 0:00:30'), isTrue);
      expect(isNetworkError('HandshakeException: handshake error'), isTrue);
    });

    test('null や非通信エラーは検知しない', () {
      expect(isNetworkError(null), isFalse);
      expect(isNetworkError('PostgrestException: row not found'), isFalse);
      expect(isNetworkError('Invalid login credentials'), isFalse);
    });
  });

  group('errorMessage', () {
    test('通信エラーはトークンを含む生の文字列を出さず汎用文言を返す', () {
      const raw =
          'AuthRetryableFetchException(... uri=https://x.supabase.co/auth/v1/'
          'token?grant_type=refresh_token, statusCode: null) SocketException';
      final msg = errorMessage(raw);
      expect(msg, kNetworkErrorMessage);
      expect(msg.contains('token'), isFalse);
      expect(msg.contains('supabase'), isFalse);
    });

    test('通信以外のエラーは従来どおりそのまま返す', () {
      const raw = 'PostgrestException: permission denied';
      expect(errorMessage(raw), raw);
    });
  });
}
