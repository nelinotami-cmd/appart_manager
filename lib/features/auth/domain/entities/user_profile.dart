import 'package:equatable/equatable.dart';

import 'account_status.dart';
import 'user_role.dart';

/// Domain entity for an application user (cahier des charges 4 & 5.1).
///
/// [id] is always identical to the underlying Appwrite Auth account id
/// (the `user_profiles` document is created with that same id as its
/// document id - a 1:1 relationship enforced by construction rather than
/// by an Appwrite relationship attribute).
///
/// [companyId] is null only for [UserRole.superAdmin] (the Super Admin is
/// a platform-level actor, not attached to any tenant company).
///
/// [createdBy] traces "qui a fait quoi": null for a self-registered Admin
/// (or the manually-created Super Admin), otherwise the id of the Admin
/// who created this Gestionnaire account.
class UserProfile extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String? companyId;
  final AccountStatus status;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.companyId,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    UserRole? role,
    String? companyId,
    AccountStatus? status,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      status: status ?? this.status,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        email,
        phone,
        role,
        companyId,
        status,
        createdBy,
        createdAt,
        updatedAt,
      ];
}
