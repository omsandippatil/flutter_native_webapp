class ActiveProfileModel {
  const ActiveProfileModel({
    required this.phone,
    required this.learnerId,
    required this.studentName,
    this.grade,
    this.division,
    this.avatar,
  });

  final String phone;
  final String learnerId;
  final String? studentName;
  final String? grade;
  final String? division;
  final String? avatar;

  factory ActiveProfileModel.fromJson(Map<String, dynamic> json) => ActiveProfileModel(
        phone: json['phone'] as String,
        learnerId: json['learner_id'] as String,
        studentName: json['student_name'] as String?,
        grade: json['grade'] as String?,
        division: json['division'] as String?,
        avatar: json['avatar'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'learner_id': learnerId,
        'student_name': studentName,
        'grade': grade,
        'division': division,
        'avatar': avatar,
      };
}