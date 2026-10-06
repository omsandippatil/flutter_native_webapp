import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tapapp/features/tap_buddy/models/chat_turn.dart';
import 'package:tapapp/features/tap_buddy/data/tap_buddy_chat_repository.dart';
import 'package:tapapp/providers/http_client_provider.dart';
import 'package:tapapp/providers/local_cache_provider.dart';

final tapbuddyChatRepositoryProvider = FutureProvider<TapbuddyChatRepository>((
  ref,
) async {
  final localCache = await ref.watch(localCacheProvider.future);
  return TapbuddyChatRepository(ref.watch(httpClientProvider), localCache);
});

class ChatTranscriptRequest {
  const ChatTranscriptRequest({required this.phone, required this.learnerId});
  final String phone;
  final String learnerId;

  @override
  bool operator ==(Object other) =>
      other is ChatTranscriptRequest &&
      other.phone == phone &&
      other.learnerId == learnerId;

  @override
  int get hashCode => Object.hash(phone, learnerId);
}

final chatTranscriptDataProvider = FutureProvider.autoDispose
    .family<List<ChatTurnModel>, ChatTranscriptRequest>((ref, request) async {
      final repository = await ref.watch(tapbuddyChatRepositoryProvider.future);
      return repository.readTranscript(request.phone, request.learnerId);
    });
