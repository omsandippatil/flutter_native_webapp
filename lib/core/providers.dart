import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:tapapp/core/storage/storage.dart";
import "package:tapapp/core/network/network.dart";

final localCacheProvider = FutureProvider<LocalCache>((ref) {
  return LocalCache.open();
});

final secureTokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(const FlutterSecureStorage());
});

final httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient(ref.watch(secureTokenStoreProvider));
});
