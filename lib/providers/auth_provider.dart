import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session_model.dart';
import '../data/repositories/auth_repository.dart';
import 'http_client_provider.dart';
import 'local_cache_provider.dart';

final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  // Same reasoning as profileRepositoryProvider: this is one-time async
  // construction, so its dependencies are read, not watched, to avoid
  // cascading rebuilds into anything that watches this provider's future.
  final localCache = await ref.read(localCacheProvider.future);
  return AuthRepository(
    ref.read(httpClientProvider),
    localCache,
    ref.read(secureTokenStoreProvider),
  );
});

final authSessionDataProvider = FutureProvider.family<AuthSessionModel?, String>((ref, phone) async {
  final repository = await ref.read(authRepositoryProvider.future);
  return repository.readCachedSession(phone);
});