import '../../domain/entities/user_profile.dart';

/// Data-layer model mirroring the `user_profiles` Appwrite collection.
/// Extends the Domain entity directly (Equatable is inherited) instead of
/// duplicating fields, per the "no Freezed / hand-written models" rule.
class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.phone,
    required super.role,
    required super.companyId,
    required super.status,
    required super.createdBy,
    required super.createdAt,
    required super.updatedAt,
  });

  factory UserProfileModel.fromEntity(UserProfile entity) => UserProfileModel(
        id: entity.id,
        fullName: entity.fullName,
        email: entity.email,
        phone: entity.phone,
        role: entity.role,
        companyId: entity.companyId,
        status: entity.status,
        createdBy: entity.createdBy,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}
