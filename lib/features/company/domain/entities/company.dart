import 'package:equatable/equatable.dart';

import 'company_status.dart';

/// Domain entity for a tenant company (cahier des charges 5.2).
class Company extends Equatable {
  final String id;
  final String name;
  final String contactName;
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
    required this.contactName,
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
        contactName,
        contactEmail,
        contactPhone,
        address,
        status,
        subscriptionPlanId,
        createdAt,
        updatedAt,
      ];
}
