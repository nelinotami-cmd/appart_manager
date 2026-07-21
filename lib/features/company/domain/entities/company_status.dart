/// Company activation status (cahier des charges 5.2: "Activation /
/// desactivation d'une entreprise").
enum CompanyStatus { active, inactive }

extension CompanyStatusX on CompanyStatus {
  String get value => switch (this) {
        CompanyStatus.active => 'active',
        CompanyStatus.inactive => 'inactive',
      };

  static CompanyStatus fromValue(String value) => switch (value) {
        'active' => CompanyStatus.active,
        'inactive' => CompanyStatus.inactive,
        _ => throw ArgumentError('Unknown CompanyStatus: $value'),
      };
}
