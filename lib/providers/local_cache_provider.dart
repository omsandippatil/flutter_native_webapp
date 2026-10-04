import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/local_cache.dart';

final localCacheProvider = FutureProvider<LocalCache>((ref) async {
  return LocalCache.open();
});
