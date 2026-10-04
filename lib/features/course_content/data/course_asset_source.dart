import '../../../core/assets/asset_loader.dart';

class AssetDataSource {
  AssetDataSource(this._assetLoader);

  final AssetLoader _assetLoader;

  static const String _courseIndexPath = 'assets/data/courses/index.json';

  static String _courseDetailPath(String courseId) =>
      'assets/data/courses/content/$courseId.json';

  Future<Map<String, dynamic>> fetchCourseIndex({String lang = 'en'}) =>
      _assetLoader.loadJson(_courseIndexPath);

  Future<Map<String, dynamic>> fetchCourseDetail(
    String courseId, {
    String lang = 'en',
  }) => _assetLoader.loadJson(_courseDetailPath(courseId));
}
