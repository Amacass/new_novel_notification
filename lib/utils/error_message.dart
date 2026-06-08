/// エラーをユーザー向けの文言に整形するヘルパー。
///
/// ネットワークの通信不良が原因と判断できる場合は、内部情報（リクエスト
/// URL やトークン等）を含む生のエラー文字列を表示せず、汎用の通信エラー
/// メッセージを返す。それ以外は従来どおり生のエラー内容をそのまま返す。
library;

const String kNetworkErrorMessage = 'ネットワークの通信状態が不安定です。\n通信環境を確認してもう一度お試しください。';

/// ネットワーク通信不良に該当するエラーかどうかを判定する。
bool isNetworkError(Object? error) {
  if (error == null) return false;
  final text = error.toString().toLowerCase();
  const markers = [
    'socketexception',
    'failed host lookup',
    'authretryablefetchexception',
    'clientexception',
    'connection refused',
    'connection closed',
    'connection reset',
    'connection timed out',
    'network is unreachable',
    'software caused connection abort',
    'os error',
    'errno = 7', // No address associated with hostname
    'errno = 8', // nodename nor servname provided
    'errno = 50', // Network is down
    'errno = 51', // Network is unreachable
    'errno = 60', // Operation timed out
    'errno = 61', // Connection refused
    'errno = 65', // No route to host
    'timeoutexception',
    'handshakeexception',
    'http request failed',
  ];
  return markers.any(text.contains);
}

/// 画面表示用のエラーメッセージを返す。
///
/// 通信不良の場合は汎用メッセージ、それ以外は生のエラー文字列。
String errorMessage(Object? error) {
  if (isNetworkError(error)) return kNetworkErrorMessage;
  return error.toString();
}
