import 'package:tapapp/core/storage/cache_keys.dart';
import 'package:tapapp/core/storage/local_cache.dart';
import 'package:tapapp/domain/course/data/course_asset_source.dart';
import 'package:tapapp/domain/course/data/json_cache_loader.dart';
import 'package:tapapp/domain/course/models/course_detail.dart';
import 'package:tapapp/domain/course/models/course_index_entry.dart';
import 'package:tapapp/domain/course/models/course_exceptions.dart';

class ProgramContentRepository {
  ProgramContentRepository(this._dataLoader, this._assetDataSource);

  final DataLoader _dataLoader;
  final AssetDataSource _assetDataSource;

  static ProgramContentRepository create(
    LocalCache localCache,
    AssetDataSource assetDataSource,
  ) => ProgramContentRepository(DataLoader(localCache), assetDataSource);

  Future<List<CourseIndexEntryModel>> fetchCourseIndex({
    String lang = 'en',
    bool forceRefresh = false,
  }) async {
    final raw = await _dataLoader.loadJsonRawList(
      cacheKey: CacheKeys.courseIndex(lang),
      fetch: () => _assetDataSource.fetchCourseIndex(lang: lang),
      forceRefresh: forceRefresh,
    );
    return CourseIndexEntryModel.listFromJson(raw);
  }

  Future<CourseDetailModel> fetchCourseDetail(
    String courseId, {
    String lang = 'en',
    bool forceRefresh = false,
  }) async {
    Map<String, dynamic> json;
    try {
      json = await _dataLoader.loadJson(
        cacheKey: CacheKeys.courseDetail(courseId, lang),
        fetch: () => _assetDataSource.fetchCourseDetail(courseId, lang: lang),
        forceRefresh: forceRefresh,
      );
    } catch (_) {
      throw ExportProgramContentErrorModel.courseNotFound(courseId);
    }

    try {
      return CourseDetailModel.fromJson(json);
    } catch (_) {
      throw ExportProgramContentErrorModel.malformed(
        CacheKeys.courseDetail(courseId, lang),
      );
    }
  }

  Future<void> invalidateCourse(String courseId, {String lang = 'en'}) =>
      _dataLoader.invalidate(CacheKeys.courseDetail(courseId, lang));

  Future<void> invalidateIndex({String lang = 'en'}) =>
      _dataLoader.invalidate(CacheKeys.courseIndex(lang));
}
