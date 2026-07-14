
import '../../core/cache/domain_cache/location_cache.dart';
import '../../core/cache/local_cache.dart';
import '../../data_loader/asset_data_source.dart';
import '../../data_loader/data_loader.dart';
import '../../models/location/location_district_file_model.dart';
import '../../models/location/location_district_model.dart';
import '../../models/location/location_state_model.dart';

class LocationRepository {
  LocationRepository(this._dataLoader, this._assetDataSource);

  final DataLoader _dataLoader;
  final AssetDataSource _assetDataSource;

  static LocationRepository create(LocalCache localCache, AssetDataSource assetDataSource) =>
      LocationRepository(DataLoader(localCache), assetDataSource);

  Future<List<LocationStateModel>> fetchStates({bool forceRefresh = false}) async {
    final raw = await _dataLoader.loadJsonRawList(
      cacheKey: LocationCache.states(),
      fetch: _assetDataSource.fetchStatesIndex,
      forceRefresh: forceRefresh,
    );
    return LocationStateModel.listFromJson(raw);
  }

  Future<List<LocationDistrictModel>> fetchDistricts(
    String stateId, {
    bool forceRefresh = false,
  }) async {
    final raw = await _dataLoader.loadJsonRawList(
      cacheKey: LocationCache.districts(stateId),
      fetch: () => _assetDataSource.fetchDistrictsForState(stateId),
      forceRefresh: forceRefresh,
    );
    return LocationDistrictFileModel.fromRaw(raw).districts;
  }
}
