import '../data/repositories/location_repository.dart';
import '../models/location/location_district_model.dart';
import '../models/location/location_state_model.dart';

class LocationService {
  LocationService(this._repository);

  final LocationRepository _repository;

  Future<List<LocationStateModel>> fetchStates({bool forceRefresh = false}) =>
      _repository.fetchStates(forceRefresh: forceRefresh);

  Future<List<LocationDistrictModel>> fetchDistricts(String stateId, {bool forceRefresh = false}) =>
      _repository.fetchDistricts(stateId, forceRefresh: forceRefresh);
}
