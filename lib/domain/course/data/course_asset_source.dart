import 'package:tapapp/core/assets/asset_loader.dart';
import 'package:tapapp/core/constants/app_constants.dart';

class AssetDataSource {
  AssetDataSource(this._assetLoader);

  final AssetLoader _assetLoader;

  static String _indexPath(String lang) =>
      'assets/data/courses/$lang/index.json';

  static String _detailPath(String lang, String courseId) =>
      'assets/data/courses/$lang/$courseId.json';

  Future<List<dynamic>> fetchCourseIndex({String lang = 'en'}) async {
    try {
      return await _assetLoader.loadJsonList(_indexPath(lang));
    } on AssetLoadException {
      if (lang == AppConstants.defaultLanguageCode) rethrow;
      return _assetLoader.loadJsonList(
        _indexPath(AppConstants.defaultLanguageCode),
      );
    }
  }

  Future<Map<String, dynamic>> fetchCourseDetail(
    String courseId, {
    String lang = 'en',
  }) async {
    try {
      return await _assetLoader.loadJson(_detailPath(lang, courseId));
    } on AssetLoadException {
      if (lang == AppConstants.defaultLanguageCode) rethrow;
      return _assetLoader.loadJson(
        _detailPath(AppConstants.defaultLanguageCode, courseId),
      );
    }
  }
}
