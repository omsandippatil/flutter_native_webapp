class LocationStateModel {
  const LocationStateModel({required this.id, required this.name, required this.country});

  final String id;
  final String name;
  final String country;

  factory LocationStateModel.fromJson(Map<String, dynamic> json) => LocationStateModel(
        id: json['id'] as String,
        name: json['name'] as String,
        country: json['country'] as String? ?? 'India',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'country': country};

  static List<LocationStateModel> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => LocationStateModel.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> listToJson(List<LocationStateModel> list) =>
      list.map((s) => s.toJson()).toList(growable: false);

  static String assetFileNameFor(String stateId) => stateId.replaceAll(' ', '-');
}
