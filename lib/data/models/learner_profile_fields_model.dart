class LearnerProfileFieldsModel {
  const LearnerProfileFieldsModel({
    this.studentName,
    this.language,
    this.district,
    this.state,
    this.school,
    this.birthdate,
  });

  final String? studentName;
  final String? language;
  final String? district;
  final String? state;
  final String? school;
  final String? birthdate;

  factory LearnerProfileFieldsModel.fromJson(Map<String, dynamic> json) => LearnerProfileFieldsModel(
        studentName: json['student_name'] as String?,
        language: json['language'] as String?,
        district: json['district'] as String?,
        state: json['state'] as String?,
        school: json['school'] as String?,
        birthdate: json['birthdate'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'student_name': studentName,
        'language': language,
        'district': district,
        'state': state,
        'school': school,
        'birthdate': birthdate,
      };
}
