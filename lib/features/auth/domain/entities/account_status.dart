/// Activation status of a [UserProfile]. Used by Admin to
/// activate/deactivate Gestionnaire accounts without deleting them.
enum AccountStatus { active, inactive }

extension AccountStatusX on AccountStatus {
  String get value => switch (this) {
        AccountStatus.active => 'active',
        AccountStatus.inactive => 'inactive',
      };

  static AccountStatus fromValue(String value) => switch (value) {
        'active' => AccountStatus.active,
        'inactive' => AccountStatus.inactive,
        _ => throw ArgumentError('Unknown AccountStatus: $value'),
      };
}
