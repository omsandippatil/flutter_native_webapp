enum ContentSourceType { asset, network }

class LoaderRegistry {
  LoaderRegistry._();

  static const Map<String, ContentSourceType> _sources = {
    'location.states': ContentSourceType.asset,
    'location.districts': ContentSourceType.asset,
    'program_content.course_index': ContentSourceType.asset,
    'program_content.course_detail': ContentSourceType.asset,
    'flow.manifest': ContentSourceType.asset,
    'flow.content': ContentSourceType.asset,
  };

  static ContentSourceType sourceFor(String logicalKey) =>
      _sources[logicalKey] ?? ContentSourceType.asset;

  static bool isAssetBacked(String logicalKey) => sourceFor(logicalKey) == ContentSourceType.asset;

  static bool isNetworkBacked(String logicalKey) => sourceFor(logicalKey) == ContentSourceType.network;
}
