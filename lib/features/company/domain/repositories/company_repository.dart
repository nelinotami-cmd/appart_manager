import 'package:equatable/equatable.dart';

import '../../../../core/typedefs/future_either.dart';
import '../entities/company.dart';
import '../entities/company_status.dart';
import '../entities/company_realtime_event.dart';

/// Domain contract for feature 5.2 (Gestion des entreprises).
///
/// Scope decisions (see also the module docstring in
/// `functions/api/src/main.py` for the `company.*` resources):
/// - No `createCompany` here: company creation stays exclusively through
///   Auth's `registerCompanyAndAdmin` (5.1) - a company with no Admin/Team
///   is a state the cahier des charges doesn't describe, and creation
///   bundled with its first Admin is already fully built.
/// - Every write goes through a privileged Cloud Function
///   (`company.update-profile` / `company.update-status` /
///   `company.assign-subscription-plan`), even ones an Admin is allowed to
///   perform on their own company - Appwrite permissions are
///   document-level, not field-level, so granting any direct `update`
///   permission would let an Admin also flip `status`/`subscriptionPlanId`
///   directly, which only Super Admin may do.
/// - `getCompanyById` / `listCompanies` / `searchCompanies` /
///   `watchCompanies` are plain, non-privileged reads: every company
///   document carries a `read(team:<companyId>)` permission (its own
///   Admin/Gestionnaires) plus `read(label:superAdmin)` (cross-tenant
///   visibility for Super Admin), so Appwrite's own permission system -
///   including Realtime - already scopes these correctly without a
///   function call.
abstract class CompanyRepository {
  FutureEither<Company> getCompanyById(String companyId);

  /// Admin may only target their own `companyId` (enforced server-side
  /// from the caller's own profile, not from anything in [params]);
  /// Super Admin may target any company.
  FutureEither<Company> updateCompanyProfile(UpdateCompanyProfileParams params);

  /// Super Admin only. Deactivating a company also deactivates every
  /// member's Appwrite account (blocks login immediately, consistent with
  /// individual Gestionnaire deactivation). Reactivating does NOT
  /// auto-reactivate members - Admin/Super Admin re-enable individuals
  /// afterward via the existing Auth `updateAccountStatus`.
  FutureEither<Company> updateCompanyStatus(UpdateCompanyStatusParams params);

  /// Super Admin only. `subscriptionPlanId` is stored as-is with no
  /// validation against an actual plan entity - section 5.3
  /// (Abonnements) doesn't exist yet, so there is nothing to validate
  /// against. Revisit once 5.3 is built.
  FutureEither<Company> assignSubscriptionPlan(AssignSubscriptionPlanParams params);

  /// Super Admin's cross-tenant list (relies on the `label:superAdmin`
  /// read permission described above - not a privileged call).
  FutureEither<List<Company>> listCompanies({int limit = 25, int offset = 0});

  FutureEither<List<Company>> searchCompanies(String query);

  /// Used only by feature 5.3's delete-plan confirmation to show which
  /// companies would be affected before the Super Admin commits to
  /// deleting a plan - a plain filtered read, not a privileged call
  /// (Super Admin already has cross-tenant read via the `label:superAdmin`
  /// permission described above).
  FutureEither<List<Company>> listCompaniesByPlanId(String subscriptionPlanId);

  Stream<CompanyRealtimeEvent> watchCompanies();
}

class UpdateCompanyProfileParams extends Equatable {
  final String companyId;
  final String name;
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final String address;

  const UpdateCompanyProfileParams({
    required this.companyId,
    required this.name,
    required this.contactName,
    required this.contactEmail,
    required this.contactPhone,
    required this.address,
  });

  @override
  List<Object?> get props =>
      [companyId, name, contactName, contactEmail, contactPhone, address];
}

class UpdateCompanyStatusParams extends Equatable {
  final String companyId;
  final CompanyStatus status;

  const UpdateCompanyStatusParams({required this.companyId, required this.status});

  @override
  List<Object?> get props => [companyId, status];
}

class AssignSubscriptionPlanParams extends Equatable {
  final String companyId;
  final String? subscriptionPlanId;

  const AssignSubscriptionPlanParams({required this.companyId, required this.subscriptionPlanId});

  @override
  List<Object?> get props => [companyId, subscriptionPlanId];
}
