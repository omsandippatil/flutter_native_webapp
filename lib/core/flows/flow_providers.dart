import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tapapp/core/assets/asset_loader.dart';
import 'package:tapapp/core/flows/flow_manifest_repository.dart';
import 'package:tapapp/core/flows/flow_repository.dart';
import 'package:tapapp/providers/local_cache_provider.dart';

final assetLoaderProvider = Provider<AssetLoader>((ref) => const AssetLoader());

final flowManifestRepositoryProvider = FutureProvider<FlowManifestRepository>((
  ref,
) async {
  final localCache = await ref.watch(localCacheProvider.future);
  return FlowManifestRepository(ref.watch(assetLoaderProvider), localCache);
});

final flowRepositoryProvider = FutureProvider<FlowRepository>((ref) async {
  final localCache = await ref.watch(localCacheProvider.future);
  final manifestRepository = await ref.watch(
    flowManifestRepositoryProvider.future,
  );
  return FlowRepository(
    manifestRepository,
    ref.watch(assetLoaderProvider),
    localCache,
  );
});

final resolvedFlowProvider = FutureProvider.autoDispose
    .family<
      ResolvedFlow,
      ({String category, String fileName, String languageCode})
    >((ref, args) async {
      final repository = await ref.watch(flowRepositoryProvider.future);
      return repository.loadFlow(
        category: args.category,
        fileName: args.fileName,
        languageCode: args.languageCode,
      );
    });
