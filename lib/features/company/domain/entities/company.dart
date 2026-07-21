import 'package:equatable/equatable.dart';

import 'company_status.dart';

/// Domain entity for a tenant company (cahier des charges 5.2).
///
/// NOTE: this feature is intentionally minimal for now. It is created here
/// only because Auth's "register company + admin" flow (5.1) needs a
/// Company document to attach the new Admin's `companyId` to. Full Company
/// management (profile edition, activation toggle, subscription plan
/// association) belongs to section 5.2 and will extend this entity/feature
/// when implemented - do not add unrelated fields here in the meantime.
class Company extends Equatable {
  final String id;
  final String name;
  final String contactEmail;
  final String contactPhone;
  final String address;
  final CompanyStatus status;
  final String? subscriptionPlanId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Company({
    required this.id,
    required this.name,
    required this.contactEmail,
    required this.contactPhone,
    required this.address,
    required this.status,
    required this.subscriptionPlanId,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        contactEmail,
        contactPhone,
        address,
        status,
        subscriptionPlanId,
        createdAt,
        updatedAt,
      ];
}
