import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tapapp/domain/auth/models/auth_session.dart';
import 'package:tapapp/domain/auth/data/auth_repository.dart';
import 'package:tapapp/providers/http_client_provider.dart';
import 'package:tapapp/providers/local_cache_provider.dart';

final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final localCache = await ref.read(localCacheProvider.future);
  return AuthRepository(
    ref.read(httpClientProvider),
    localCache,
    ref.read(secureTokenStoreProvider),
  );
});

final authSessionDataProvider =
    FutureProvider.family<AuthSessionModel?, String>((ref, phone) async {
      final repository = await ref.read(authRepositoryProvider.future);
      return repository.readCachedSession(phone);
    });
