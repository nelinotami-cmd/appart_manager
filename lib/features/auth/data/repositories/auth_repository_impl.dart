import 'package:appartements_erp/features/auth/domain/entities/account_status.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/base_exception.dart';
import '../../../../core/typedefs/future_either.dart';
import '../../domain/entities/gestionnaire_creation_result.dart';
import '../../domain/entities/otp_challenge.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_profile_realtime_event.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_account_remote_datasource.dart';
import '../datasources/auth_functions_remote_datasource.dart';
import '../datasources/user_profile_remote_datasource.dart';
import '../mappers/user_profile_mapper.dart';

/// Simple heuristic to decide whether a login/OTP identifier is an email
/// or a phone number, since Appwrite's password/OTP-by-email APIs are
/// email-keyed while phone OTP has its own API.
bool _looksLikeEmail(String identifier) => identifier.contains('@');

class AuthRepositoryImpl implements AuthRepository {
  final AuthAccountRemoteDataSource accountDataSource;
  final AuthFunctionsRemoteDataSource functionsDataSource;
  final UserProfileRemoteDataSource userProfileDataSource;

  AuthRepositoryImpl({
    required this.accountDataSource,
    required this.functionsDataSource,
    required this.userProfileDataSource,
  });

  // ---- Onboarding / identity ---------------------------------------------

  @override
  FutureEither<UserProfile> registerCompanyAndAdmin(
    RegisterCompanyAndAdminParams params,
  ) async {
    try {
      final result = await functionsDataSource.registerCompanyAndAdmin({
        'companyName': params.companyName,
        'companyAddress': params.companyAddress,
        'companyContactEmail': params.companyContactEmail,
        'companyContactPhone': params.companyContactPhone,
        'adminFullName': params.adminFullName,
        'adminEmail': params.adminEmail,
        'adminPhone': params.adminPhone,
        'password': params.password,
      });

      // The function only creates the Auth account + documents; the client
      // still needs to log in explicitly to obtain a session.
      await accountDataSource.createEmailPasswordSession(
        email: params.adminEmail,
        password: params.password,
      );

      return Right(UserProfileMapper.fromMap(result));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<UserProfile> login(LoginParams params) async {
    try {
      final email = _looksLikeEmail(params.identifier)
          ? params.identifier
          : (await _resolveIdentifier(params.identifier))['email'] as String;

      await accountDataSource.createEmailPasswordSession(
        email: email,
        password: params.password,
      );
      final account = await accountDataSource.getCurrentAccount();
      final profile = await userProfileDataSource.getById(account.$id);
      return Right(profile);
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<void> logout() async {
    try {
      await accountDataSource.deleteCurrentSession();
      return const Right(null);
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<UserProfile> getCurrentUser() async {
    try {
      final account = await accountDataSource.getCurrentAccount();
      final profile = await userProfileDataSource.getById(account.$id);
      return Right(profile);
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  // ---- Password reset -----------------------------------------------------

  @override
  FutureEither<OtpChallenge> requestPasswordResetOtp(
      RequestOtpParams params) async {
    try {
      final resolved = await _resolveIdentifier(params.identifier);
      final userId = resolved['userId'] as String;

      if (_looksLikeEmail(params.identifier)) {
        await accountDataSource.createEmailOtpToken(
          userId: userId,
          email: params.identifier,
        );
        return Right(OtpChallenge(userId: userId, channel: 'email'));
      } else {
        await accountDataSource.createPhoneOtpToken(
          userId: userId,
          phone: params.identifier,
        );
        return Right(OtpChallenge(userId: userId, channel: 'phone'));
      }
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<void> verifyOtpAndResetPassword(VerifyOtpParams params) async {
    try {
      // Proves the OTP was correct by successfully opening a session with
      // it; then delegates the actual password write to a Cloud Function
      // (Server SDK Users API) so we never depend on Appwrite's
      // old-password requirement for `account.updatePassword`.
      await accountDataSource.createSessionFromOtp(
        userId: params.userId,
        secret: params.otp,
      );

      await functionsDataSource.resetPassword({
        'userId': params.userId,
        'newPassword': params.newPassword,
      });

      // The OTP-derived session has served its purpose; drop it so the
      // user must log in explicitly with the new password.
      await accountDataSource.deleteCurrentSession();

      return const Right(null);
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  // ---- Gestionnaire management --------------------------------------------

  @override
  FutureEither<GestionnaireCreationResult> createGestionnaireAccount(
    CreateGestionnaireParams params,
  ) async {
    try {
      final result = await functionsDataSource.createGestionnaireAccount({
        'fullName': params.fullName,
        'email': params.email,
        'phone': params.phone,
      });
      return Right(GestionnaireCreationResult(
        profile: UserProfileMapper.fromMap(result),
        tempPassword: result['tempPassword'] as String,
      ));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<UserProfile> updateAccountStatus(
    UpdateAccountStatusParams params,
  ) async {
    try {
      final result = await functionsDataSource.updateAccountStatus({
        'userId': params.userId,
        'status': params.status.value,
      });
      return Right(UserProfileMapper.fromMap(result));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<void> deleteGestionnaireAccount(
      DeleteGestionnaireParams params) async {
    try {
      await functionsDataSource
          .deleteGestionnaireAccount({'userId': params.userId});
      return const Right(null);
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  // ---- Read / Search / Realtime -------------------------------------------

  @override
  FutureEither<UserProfile> getUserProfileById(String userId) async {
    try {
      return Right(await userProfileDataSource.getById(userId));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<List<UserProfile>> listUserProfilesByCompany(
    ListUserProfilesParams params,
  ) async {
    try {
      final profiles = await userProfileDataSource.listByCompany(
        companyId: params.companyId,
        limit: params.limit,
        offset: params.offset,
      );
      return Right(profiles);
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<List<UserProfile>> searchUserProfiles(
    SearchUserProfilesParams params,
  ) async {
    try {
      final profiles = await userProfileDataSource.search(
        companyId: params.companyId,
        query: params.query,
      );
      return Right(profiles);
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  Stream<UserProfileRealtimeEvent> watchUserProfiles(String companyId) =>
      userProfileDataSource.watchByCompany(companyId);

  // ---- Helpers --------------------------------------------------------------

  /// Login and OTP-request both accept email OR phone, but Appwrite's
  /// password/email-OTP APIs are email-keyed and Appwrite's phone-OTP API
  /// is userId-keyed. Resolving an arbitrary identifier to
  /// `{userId, email}` therefore requires a lookup that is intentionally
  /// NOT exposed as a direct, public `user_profiles` query (that would let
  /// anyone enumerate accounts and leak fullName/role/companyId by phone
  /// number). Instead it goes through the `auth.resolve-login-identifier`
  /// resource on the project's single shared `api` Cloud Function, which
  /// is allowed to read the collection with the Server SDK and returns
  /// only the two fields needed here.
  Future<Map<String, dynamic>> _resolveIdentifier(String identifier) async {
    final result = await functionsDataSource.resolveLoginIdentifier({
      'identifier': identifier,
    });
    if (result['userId'] == null || result['email'] == null) {
      throw const AuthException(
          message: 'Aucun compte associe a cet identifiant.');
    }
    return result;
  }
}
