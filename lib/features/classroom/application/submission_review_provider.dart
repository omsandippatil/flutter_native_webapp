import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tapapp/features/classroom/data/submission_review_repository.dart';
import 'package:tapapp/providers/http_client_provider.dart';
import 'package:tapapp/providers/local_cache_provider.dart';

final submissionReviewRepositoryProvider =
    FutureProvider<SubmissionReviewRepository>((ref) async {
      final localCache = await ref.watch(localCacheProvider.future);
      return SubmissionReviewRepository(
        ref.watch(httpClientProvider),
        localCache,
      );
    });
