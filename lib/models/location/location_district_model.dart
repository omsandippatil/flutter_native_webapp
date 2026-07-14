class LocationDistrictModel {
  const LocationDistrictModel({required this.id, required this.name});

  final String id;
  final String name;

  factory LocationDistrictModel.fromJson(Map<String, dynamic> json) => LocationDistrictModel(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  static List<LocationDistrictModel> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => LocationDistrictModel.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> listToJson(List<LocationDistrictModel> list) =>
      list.map((d) => d.toJson()).toList(growable: false);
}
