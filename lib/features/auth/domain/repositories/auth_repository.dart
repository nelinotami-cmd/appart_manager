import 'package:equatable/equatable.dart';

import '../../../../core/typedefs/future_either.dart';
import '../entities/account_status.dart';
import '../entities/gestionnaire_creation_result.dart';
import '../entities/otp_challenge.dart';
import '../entities/user_profile.dart';
import '../entities/user_profile_realtime_event.dart';

/// Domain contract for the Auth feature. Implemented in the Data layer by
/// `AuthRepositoryImpl`, which composes three Appwrite-backed datasources
/// (Account/session, privileged Cloud Functions, and `user_profiles`
/// document access). Presentation only ever depends on this interface.
abstract class AuthRepository {
  // ---- Onboarding / identity -------------------------------------------

  /// Onboards a brand new tenant company and its first Admin account
  /// (cahier des charges 5.1: "Inscription des entreprises (onboarding
  /// SaaS) et creation du compte Admin entreprise"). Delegates to a Cloud
  /// Function so that the `role`/`companyId` assignment cannot be forged
  /// by the client.
  FutureEither<UserProfile> registerCompanyAndAdmin(
    RegisterCompanyAndAdminParams params,
  );

  /// Authenticates with email-or-phone + password.
  FutureEither<UserProfile> login(LoginParams params);

  /// Destroys the current Appwrite session.
  FutureEither<void> logout();

  /// Returns the profile of the currently authenticated user, if any.
  FutureEither<UserProfile> getCurrentUser();

  // ---- Password reset (OTP based, no MFA) --------------------------------

  /// Step 1 of password reset: sends an OTP code by email or SMS
  /// (whichever [identifier] resolves to) and returns the challenge to use
  /// in step 2.
  FutureEither<OtpChallenge> requestPasswordResetOtp(RequestOtpParams params);

  /// Step 2 of password reset: verifies [VerifyOtpParams.otp] against the
  /// challenge created in step 1 and sets the new password.
  FutureEither<void> verifyOtpAndResetPassword(VerifyOtpParams params);

  // ---- Gestionnaire account management (Admin only) ----------------------

  /// Creates a Gestionnaire account for the calling Admin's company
  /// (cahier des charges 5.7: "Creation des comptes gestionnaire par
  /// l'Admin entreprise"). Delegates to a Cloud Function. The returned
  /// [GestionnaireCreationResult.tempPassword] is shown to the Admin
  /// exactly once - it is never re-fetchable afterward.
  FutureEither<GestionnaireCreationResult> createGestionnaireAccount(
    CreateGestionnaireParams params,
  );

  /// Activates/deactivates an existing account (used by an Admin to
  /// disable a Gestionnaire without deleting their history).
  FutureEither<UserProfile> updateAccountStatus(UpdateAccountStatusParams params);

  /// Permanently deletes a Gestionnaire's Auth account + profile.
  FutureEither<void> deleteGestionnaireAccount(DeleteGestionnaireParams params);

  // ---- Read / Search / Realtime on user_profiles -------------------------

  FutureEither<UserProfile> getUserProfileById(String userId);

  FutureEither<List<UserProfile>> listUserProfilesByCompany(
    ListUserProfilesParams params,
  );

  FutureEither<List<UserProfile>> searchUserProfiles(
    SearchUserProfilesParams params,
  );

  /// Realtime stream of create/update/delete events on the
  /// `user_profiles` collection, scoped to [companyId].
  Stream<UserProfileRealtimeEvent> watchUserProfiles(String companyId);
}

// ---------------------------------------------------------------------------
// Params (kept alongside the interface they belong to; each UseCase file
// uses the one it needs).
// ---------------------------------------------------------------------------

class RegisterCompanyAndAdminParams extends Equatable {
  final String companyName;
  final String companyAddress;
  final String companyContactEmail;
  final String companyContactPhone;
  final String adminFullName;
  final String adminEmail;
  final String adminPhone;
  final String password;

  const RegisterCompanyAndAdminParams({
    required this.companyName,
    required this.companyAddress,
    required this.companyContactEmail,
    required this.companyContactPhone,
    required this.adminFullName,
    required this.adminEmail,
    required this.adminPhone,
    required this.password,
  });

  @override
  List<Object?> get props => [
        companyName,
        companyAddress,
        companyContactEmail,
        companyContactPhone,
        adminFullName,
        adminEmail,
        adminPhone,
        password,
      ];
}

class LoginParams extends Equatable {
  /// Email address OR phone number.
  final String identifier;
  final String password;

  const LoginParams({required this.identifier, required this.password});

  @override
  List<Object?> get props => [identifier, password];
}

class RequestOtpParams extends Equatable {
  /// Email address OR phone number the OTP should be sent to.
  final String identifier;

  const RequestOtpParams({required this.identifier});

  @override
  List<Object?> get props => [identifier];
}

class VerifyOtpParams extends Equatable {
  final String userId;
  final String otp;
  final String newPassword;

  const VerifyOtpParams({
    required this.userId,
    required this.otp,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [userId, otp, newPassword];
}

class CreateGestionnaireParams extends Equatable {
  final String fullName;
  final String email;
  final String phone;

  const CreateGestionnaireParams({
    required this.fullName,
    required this.email,
    required this.phone,
  });

  @override
  List<Object?> get props => [fullName, email, phone];
}

class UpdateAccountStatusParams extends Equatable {
  final String userId;
  final AccountStatus status;

  const UpdateAccountStatusParams({required this.userId, required this.status});

  @override
  List<Object?> get props => [userId, status];
}

class DeleteGestionnaireParams extends Equatable {
  final String userId;

  const DeleteGestionnaireParams({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class ListUserProfilesParams extends Equatable {
  final String companyId;
  final int limit;
  final int offset;

  const ListUserProfilesParams({
    required this.companyId,
    this.limit = 25,
    this.offset = 0,
  });

  @override
  List<Object?> get props => [companyId, limit, offset];
}

class SearchUserProfilesParams extends Equatable {
  final String companyId;
  final String query;

  const SearchUserProfilesParams({required this.companyId, required this.query});

  @override
  List<Object?> get props => [companyId, query];
}
