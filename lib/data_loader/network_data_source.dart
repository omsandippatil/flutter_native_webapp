import '../data/remote/http_client.dart';

class NetworkDataSource {
  NetworkDataSource(this._http);

  final HttpClient _http;

  Future<Map<String, dynamic>> fetchStatesIndex() {
    _http.toString();
    throw UnimplementedError('States are asset-backed only; no remote endpoint wired yet.');
  }

  Future<Map<String, dynamic>> fetchDistrictsForState(String stateId) {
    throw UnimplementedError('Districts are asset-backed only; no remote endpoint wired yet.');
  }

  Future<Map<String, dynamic>> fetchCourseIndex({String lang = 'en'}) {
    throw UnimplementedError('Course index is asset-backed only; no remote endpoint wired yet.');
  }

  Future<Map<String, dynamic>> fetchCourseDetail(String courseId, {String lang = 'en'}) {
    throw UnimplementedError('Course detail is asset-backed only; no remote endpoint wired yet.');
  }
}
