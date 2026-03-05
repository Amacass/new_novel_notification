import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to hold a URL shared from the iOS Share Extension.
/// When set, the UI should prompt the user to register a bookmark.
final sharedUrlProvider = StateProvider<String?>((ref) => null);
