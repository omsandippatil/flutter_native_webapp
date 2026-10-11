import "dart:convert";
import "package:tapapp/core/storage/storage.dart";
import "package:tapapp/core/constants/app_constants.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:tapapp/core/providers.dart";
import "package:flutter/services.dart" show rootBundle;

class AssetLoadException implements Exception {
  AssetLoadException(this.path, this.cause);
  final String path;
  final Object cause;
  @override
  String toString() => "AssetLoadException: failed to load \"$path\" ($cause)";
}

class AssetLoader {
  const AssetLoader();
  Future<Map<String, dynamic>> loadJson(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw AssetLoadException(path, "expected a JSON object at top level");
    } on AssetLoadException { rethrow; } catch (e) { throw AssetLoadException(path, e); }
  }
  Future<dynamic> loadJsonAny(String path) async {
    try { final raw = await rootBundle.loadString(path); return jsonDecode(raw); }
    catch (e) { throw AssetLoadException(path, e); }
  }
  Future<List<dynamic>> loadJsonList(String path) async {
    final decoded = await loadJsonAny(path);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded.values.isNotEmpty) {
      final firstList = decoded.values.firstWhere((v) => v is List, orElse: () => null);
      if (firstList is List) return firstList;
    }
    throw AssetLoadException(path, "expected a JSON array at top level");
  }
  Future<String> loadRawString(String path) async {
    try { return await rootBundle.loadString(path); } catch (e) { throw AssetLoadException(path, e); }
  }
}

class FlowManifestFileEntry {
  const FlowManifestFileEntry({required this.languages});
  final List<String> languages;
  bool hasLanguage(String code) => languages.contains(code);
  factory FlowManifestFileEntry.fromJson(Map<String, dynamic> json) {
    final raw = json["languages"];
    return FlowManifestFileEntry(languages: raw is List ? raw.whereType<String>().toList() : <String>[]);
  }
  Map<String, dynamic> toJson() => {"languages": languages};
}

class FlowManifest {
  const FlowManifest({required this.categories});
  final Map<String, Map<String, FlowManifestFileEntry>> categories;
  FlowManifestFileEntry? entryFor(String category, String fileName) => categories[category]?[fileName];
  String resolveLanguage(String category, String fileName, String requestedLanguage) {
    final entry = entryFor(category, fileName);
    if (entry != null && entry.hasLanguage(requestedLanguage)) return requestedLanguage;
    return "en";
  }
  List<String> fileNamesFor(String category) => categories[category]?.keys.toList() ?? const [];
  List<String> allCategories() => categories.keys.toList();
  factory FlowManifest.fromJson(Map<String, dynamic> json) {
    final flows = json["flows"];
    final categories = <String, Map<String, FlowManifestFileEntry>>{};
    if (flows is Map) {
      flows.forEach((category, files) {
        if (files is Map) {
          final fileMap = <String, FlowManifestFileEntry>{};
          files.forEach((fileName, entry) {
            if (entry is Map) fileMap[fileName.toString()] = FlowManifestFileEntry.fromJson(Map<String, dynamic>.from(entry));
          });
          categories[category.toString()] = fileMap;
        }
      });
    }
    return FlowManifest(categories: categories);
  }
  Map<String, dynamic> toJson() => {"flows": categories.map((category, files) => MapEntry(category, files.map((fileName, entry) => MapEntry(fileName, entry.toJson()))))};
}

class FlowManifestRepository {
  FlowManifestRepository(this._assetLoader, LocalCache localCache) : _localCache = localCache, _cache = CachedRepo<FlowManifest>(localCache);
  final AssetLoader _assetLoader;
  final LocalCache _localCache;
  final CachedRepo<FlowManifest> _cache;
  Future<FlowManifest> load(String languageCode) => _cache.getOrFetch(
    key: CacheKeys.flowManifest(languageCode),
    fromJson: FlowManifest.fromJson,
    toJson: (manifest) => manifest.toJson(),
    fetch: () => _fetchManifest(languageCode),
  );
  Future<FlowManifest> _fetchManifest(String languageCode) async {
    Map<String, dynamic> json;
    try { json = await _assetLoader.loadJson(AppConstants.flowManifestPath(languageCode)); }
    on AssetLoadException {
      if (languageCode == AppConstants.defaultLanguageCode) rethrow;
      json = await _assetLoader.loadJson(AppConstants.flowManifestPath(AppConstants.defaultLanguageCode));
    }
    return FlowManifest.fromJson(json);
  }
  Future<void> invalidate(String languageCode) async { _cache.invalidate(CacheKeys.flowManifest(languageCode)); }
  Future<void> invalidateAll() async { await _localCache.deletePrefix("v2:flow:manifest:"); }
}

class FlowNotFoundException implements Exception {
  FlowNotFoundException(this.category, this.fileName);
  final String category;
  final String fileName;
  @override
  String toString() => "FlowNotFoundException: no manifest entry for \"$category/$fileName\"";
}

class ResolvedFlow {
  const ResolvedFlow({required this.data, required this.isFallback});
  final Map<String, dynamic> data;
  final bool isFallback;
  Map<String, dynamic> toJson() => {...data, "_isFallback": isFallback};
  factory ResolvedFlow.fromJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    final isFallback = copy.remove("_isFallback") as bool? ?? false;
    return ResolvedFlow(data: copy, isFallback: isFallback);
  }
}

class FlowRepository {
  FlowRepository(this._manifestRepository, this._assetLoader, LocalCache localCache) : _localCache = localCache, _cache = CachedRepo<ResolvedFlow>(localCache);
  final FlowManifestRepository _manifestRepository;
  final AssetLoader _assetLoader;
  final LocalCache _localCache;
  final CachedRepo<ResolvedFlow> _cache;
  Future<ResolvedFlow> loadFlow({required String category, required String fileName, required String languageCode}) async {
    final manifest = await _manifestRepository.load(languageCode);
    final entry = manifest.entryFor(category, fileName);
    if (entry == null) throw FlowNotFoundException(category, fileName);
    final resolvedLanguage = manifest.resolveLanguage(category, fileName, languageCode);
    final isFallback = resolvedLanguage != languageCode;
    final cacheKey = CacheKeys.flow(resolvedLanguage, category, fileName);
    return _cache.getOrFetch(
      key: cacheKey,
      fromJson: ResolvedFlow.fromJson,
      toJson: (flow) => flow.toJson(),
      fetch: () async {
        final data = await _assetLoader.loadJson(AppConstants.flowAssetPath(resolvedLanguage, category, fileName));
        return ResolvedFlow(data: data, isFallback: isFallback);
      },
    );
  }
  Future<List<String>> fileNamesFor(String category, {String languageCode = AppConstants.defaultLanguageCode}) async {
    final manifest = await _manifestRepository.load(languageCode);
    return manifest.fileNamesFor(category);
  }
  Future<List<String>> allCategories({String languageCode = AppConstants.defaultLanguageCode}) async {
    final manifest = await _manifestRepository.load(languageCode);
    return manifest.allCategories();
  }
  Future<void> invalidateAll() async { await _localCache.deletePrefix("v2:flow:"); }
}

final assetLoaderProvider = Provider<AssetLoader>((ref) => const AssetLoader());

final flowManifestRepositoryProvider = FutureProvider<FlowManifestRepository>((ref) async {
  final localCache = await ref.watch(localCacheProvider.future);
  return FlowManifestRepository(ref.watch(assetLoaderProvider), localCache);
});

final flowRepositoryProvider = FutureProvider<FlowRepository>((ref) async {
  final localCache = await ref.watch(localCacheProvider.future);
  final manifestRepository = await ref.watch(flowManifestRepositoryProvider.future);
  return FlowRepository(manifestRepository, ref.watch(assetLoaderProvider), localCache);
});

final resolvedFlowProvider = FutureProvider.autoDispose.family<ResolvedFlow, ({String category, String fileName, String languageCode})>((ref, args) async {
  final repository = await ref.watch(flowRepositoryProvider.future);
  return repository.loadFlow(category: args.category, fileName: args.fileName, languageCode: args.languageCode);
});
