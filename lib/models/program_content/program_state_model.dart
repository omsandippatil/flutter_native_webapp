class ProgramStateModel {
  const ProgramStateModel({required this.stateId, required this.availableCourseIds});

  final String stateId;
  final List<String> availableCourseIds;

  factory ProgramStateModel.fromJson(Map<String, dynamic> json) => ProgramStateModel(
        stateId: json['state_id'] as String? ?? '',
        availableCourseIds:
            (json['available_course_ids'] as List?)?.whereType<String>().toList() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'state_id': stateId,
        'available_course_ids': availableCourseIds,
      };
}
