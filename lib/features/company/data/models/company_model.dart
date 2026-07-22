import '../../domain/entities/company.dart';
import '../../domain/entities/company_status.dart';
import '../../../../core/constants/appwrite_constants.dart';

/// Data-layer model mirroring the `companies` Appwrite collection.
/// Kept Equatable-compatible via the [Company] base class (no Freezed).
class CompanyModel extends Company {
  const CompanyModel({
    required super.id,
    required super.name,
    required super.contactName,
    required super.contactEmail,
    required super.contactPhone,
    required super.address,
    required super.status,
    required super.subscriptionPlanId,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Builds a [CompanyModel] from a raw Appwrite document map
  /// (`Document.data` merged with `$id`/`$createdAt`/`$updatedAt`).
  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    return CompanyModel(
      id: map[r'$id'] as String,
      name: map[CompanyAttributes.name] as String,
      contactName: map[CompanyAttributes.contactName] as String? ?? '',
      contactEmail: map[CompanyAttributes.contactEmail] as String,
      contactPhone: map[CompanyAttributes.contactPhone] as String,
      address: map[CompanyAttributes.address] as String,
      status: CompanyStatusX.fromValue(map[CompanyAttributes.status] as String),
      subscriptionPlanId: map[CompanyAttributes.subscriptionPlanId] as String?,
      createdAt: DateTime.parse(map[r'$createdAt'] as String),
      updatedAt: DateTime.parse(map[r'$updatedAt'] as String),
    );
  }

  /// Payload for `databases.createDocument` / `updateDocument` (excludes
  /// Appwrite-managed fields like `$id`/`$createdAt`).
  Map<String, dynamic> toCreateMap() => {
        CompanyAttributes.name: name,
        CompanyAttributes.contactName: contactName,
        CompanyAttributes.contactEmail: contactEmail,
        CompanyAttributes.contactPhone: contactPhone,
        CompanyAttributes.address: address,
        CompanyAttributes.status: status.value,
        CompanyAttributes.subscriptionPlanId: subscriptionPlanId,
      };
}
