import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:tapapp/core/storage/secure_token_store.dart';
import 'package:tapapp/core/network/http_client.dart';

final secureTokenStoreProvider = Provider<SecureTokenStore>((ref) {
  return SecureTokenStore(const FlutterSecureStorage());
});

final httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient(ref.watch(secureTokenStoreProvider));
});
