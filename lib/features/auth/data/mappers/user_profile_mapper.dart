import '../../../../core/constants/appwrite_constants.dart';
import '../../domain/entities/account_status.dart';
import '../../domain/entities/user_role.dart';
import '../models/user_profile_model.dart';

/// Converts between raw Appwrite document maps and [UserProfileModel].
///
/// `companyId` is modelled as an Appwrite *relationship* attribute
/// (many user_profiles -> one company). Depending on the query (whether
/// the related document was selected), Appwrite returns either the related
/// document's id as a plain [String], a nested `Map` (populated relation),
/// or `null` (Super Admin has no company). This mapper normalises all
/// three cases to a plain `String?` id, since Auth only ever needs the id
/// - never the nested Company payload.
class UserProfileMapper {
  UserProfileMapper._();

  static UserProfileModel fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      id: map[r'$id'] as String,
      fullName: map[UserProfileAttributes.fullName] as String,
      email: map[UserProfileAttributes.email] as String,
      phone: map[UserProfileAttributes.phone] as String,
      role: UserRoleX.fromValue(map[UserProfileAttributes.role] as String),
      companyId: _extractRelationId(map[UserProfileAttributes.companyId]),
      status: AccountStatusX.fromValue(map[UserProfileAttributes.status] as String),
      createdBy: map[UserProfileAttributes.createdBy] as String?,
      createdAt: DateTime.parse(map[r'$createdAt'] as String),
      updatedAt: DateTime.parse(map[r'$updatedAt'] as String),
    );
  }

  static String? _extractRelationId(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    if (raw is Map<String, dynamic>) return raw[r'$id'] as String?;
    return null;
  }

  /// Payload for `databases.createDocument` / `updateDocument`.
  static Map<String, dynamic> toMap(UserProfileModel model) => {
        UserProfileAttributes.fullName: model.fullName,
        UserProfileAttributes.email: model.email,
        UserProfileAttributes.phone: model.phone,
        UserProfileAttributes.role: model.role.value,
        UserProfileAttributes.companyId: model.companyId,
        UserProfileAttributes.status: model.status.value,
        UserProfileAttributes.createdBy: model.createdBy,
      };
}
