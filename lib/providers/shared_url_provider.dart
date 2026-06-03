import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Queue of URLs shared from the Safari Extension, processed one at a time.
final sharedUrlProvider = StateProvider<List<String>>((ref) => const []);
