/// The three application roles defined in the cahier des charges (section
/// 4). "Staff" (informational-only crew, e.g. cleaners) is NOT a role here
/// on purpose: staff members have no platform access and are out of scope
/// for the Auth feature - they are plain reference data owned by another
/// feature (tasks/reporting, section 5.10).
enum UserRole { superAdmin, admin, gestionnaire }

extension UserRoleX on UserRole {
  String get value => switch (this) {
        UserRole.superAdmin => 'superAdmin',
        UserRole.admin => 'admin',
        UserRole.gestionnaire => 'gestionnaire',
      };

  static UserRole fromValue(String value) => switch (value) {
        'superAdmin' => UserRole.superAdmin,
        'admin' => UserRole.admin,
        'gestionnaire' => UserRole.gestionnaire,
        _ => throw ArgumentError('Unknown UserRole: $value'),
      };
}
