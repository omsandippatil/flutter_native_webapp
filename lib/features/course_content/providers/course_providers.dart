import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assets/asset_loader.dart';
import '../data/course_repository.dart';
import '../data/course_asset_source.dart';
import '../models/course_detail.dart';
import '../../../providers/local_cache_provider.dart';

final assetDataSourceProvider = Provider<AssetDataSource>((ref) {
  return AssetDataSource(const AssetLoader());
});

final programContentRepositoryProvider =
    FutureProvider<ProgramContentRepository>((ref) async {
      final localCache = await ref.watch(localCacheProvider.future);
      return ProgramContentRepository.create(
        localCache,
        ref.watch(assetDataSourceProvider),
      );
    });

final courseDetailDataProvider = FutureProvider.autoDispose
    .family<CourseDetailModel, String>((ref, courseId) async {
      final repository = await ref.watch(
        programContentRepositoryProvider.future,
      );
      return repository.fetchCourseDetail(courseId);
    });
