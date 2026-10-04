import '../../../core/storage/program_content_cache.dart';
import '../../../core/storage/local_cache.dart';
import 'course_asset_source.dart';
import 'json_cache_loader.dart';
import '../models/course_detail.dart';
import '../models/course_index_entry.dart';
import '../models/program_content_exceptions.dart';

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
    final json = await _dataLoader.loadJson(
      cacheKey: ProgramContentCache.courseIndex(lang),
      fetch: () => _assetDataSource.fetchCourseIndex(lang: lang),
      forceRefresh: forceRefresh,
    );
    return CourseIndexEntryModel.listFromJson(json['courses']);
  }

  Future<CourseDetailModel> fetchCourseDetail(
    String courseId, {
    String lang = 'en',
    bool forceRefresh = false,
  }) async {
    Map<String, dynamic> json;
    try {
      json = await _dataLoader.loadJson(
        cacheKey: ProgramContentCache.courseDetail(courseId, lang),
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
        ProgramContentCache.courseDetail(courseId, lang),
      );
    }
  }

  Future<void> invalidateCourse(String courseId, {String lang = 'en'}) =>
      _dataLoader.invalidate(ProgramContentCache.courseDetail(courseId, lang));

  Future<void> invalidateIndex({String lang = 'en'}) =>
      _dataLoader.invalidate(ProgramContentCache.courseIndex(lang));
}
