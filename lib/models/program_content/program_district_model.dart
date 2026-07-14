class ProgramDistrictModel {
  const ProgramDistrictModel({required this.districtId, required this.availableCourseIds});

  final String districtId;
  final List<String> availableCourseIds;

  factory ProgramDistrictModel.fromJson(Map<String, dynamic> json) => ProgramDistrictModel(
        districtId: json['district_id'] as String? ?? '',
        availableCourseIds:
            (json['available_course_ids'] as List?)?.whereType<String>().toList() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'district_id': districtId,
        'available_course_ids': availableCourseIds,
      };
}
