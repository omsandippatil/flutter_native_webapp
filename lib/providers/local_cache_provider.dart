import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tapapp/core/storage/local_cache.dart';

final localCacheProvider = FutureProvider<LocalCache>((ref) {
  return LocalCache.open();
});
