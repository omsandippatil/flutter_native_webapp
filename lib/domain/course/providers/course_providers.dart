import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tapapp/core/assets/asset_loader.dart';
import 'package:tapapp/core/localization/language_provider.dart';
import 'package:tapapp/domain/course/data/course_repository.dart';
import 'package:tapapp/domain/course/data/course_asset_source.dart';
import 'package:tapapp/domain/course/models/course_detail.dart';
import 'package:tapapp/providers/local_cache_provider.dart';

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
      final lang = ref.watch(languageProvider);
      return repository.fetchCourseDetail(courseId, lang: lang);
    });
