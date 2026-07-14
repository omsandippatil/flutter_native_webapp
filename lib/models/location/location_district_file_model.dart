import 'location_district_model.dart';

class LocationDistrictFileModel {
  const LocationDistrictFileModel({required this.districts});

  final List<LocationDistrictModel> districts;

  factory LocationDistrictFileModel.fromRaw(dynamic raw) {
    if (raw is List) {
      return LocationDistrictFileModel(districts: LocationDistrictModel.listFromJson(raw));
    }
    if (raw is Map && raw['districts'] is List) {
      return LocationDistrictFileModel(
        districts: LocationDistrictModel.listFromJson(raw['districts']),
      );
    }
    return const LocationDistrictFileModel(districts: []);
  }
}
