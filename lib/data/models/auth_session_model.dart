class AuthSessionModel {
  const AuthSessionModel({
    required this.phone,
    this.teacher,
    this.schoolId,
    this.adminCode,
  });

  final String phone;
  final String? teacher;
  final String? schoolId;
  final String? adminCode;

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) => AuthSessionModel(
        phone: json['phone'] as String,
        teacher: json['teacher'] as String?,
        schoolId: json['school_id'] as String?,
        adminCode: json['admin_code'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'teacher': teacher,
        'school_id': schoolId,
        'admin_code': adminCode,
      };
}
