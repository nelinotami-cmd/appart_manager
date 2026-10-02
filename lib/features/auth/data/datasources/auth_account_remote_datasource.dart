import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../../../../core/error/base_exception.dart';
import '../../../../core/logging/app_logger.dart';

/// Wraps the Appwrite `Account` service: session lifecycle and the
/// client-side half of the OTP challenge/response flow. Privileged
/// operations (account creation on behalf of someone else, force password
/// reset, role/company assignment) are NOT here - see
/// [AuthFunctionsRemoteDataSource].
abstract class AuthAccountRemoteDataSource {
  /// Logs in with an email and password. Phone-based login is resolved to
  /// an email upstream (see [AuthRepositoryImpl.login]) since Appwrite
  /// password sessions are email-keyed.
  Future<void> createEmailPasswordSession({
    required String email,
    required String password,
  });

  Future<void> deleteCurrentSession();

  /// Throws [AuthException] if there is no active session.
  Future<models.User> getCurrentAccount();

  /// Sends an OTP code by email. Returns the token's `userId`
  /// (the OTP code itself is delivered out-of-band, never returned here).
  Future<String> createEmailOtpToken(
      {required String userId, required String email});

  /// Sends an OTP code by SMS.
  Future<String> createPhoneOtpToken(
      {required String userId, required String phone});

  /// Exchanges a userId + OTP code for a session. Throws [AuthException] if
  /// the code is invalid/expired. A successful call is itself the proof
  /// that the code was correct - the resulting session is then used to
  /// authorize the privileged "force reset password" Cloud Function call.
  Future<void> createSessionFromOtp(
      {required String userId, required String secret});
}

class AuthAccountRemoteDataSourceImpl implements AuthAccountRemoteDataSource {
  final Account account;

  AuthAccountRemoteDataSourceImpl({required this.account});

  @override
  Future<void> createEmailPasswordSession({
    required String email,
    required String password,
  }) async {
    AppLogger.apiRequest('Account.createEmailPasswordSession',
        details: {'email': email});
    try {
      await account.createEmailPasswordSession(
          email: email, password: password);
      AppLogger.apiResponse('Account.createEmailPasswordSession',
          details: {'email': email});
    } on AppwriteException catch (e, st) {
      AppLogger.apiError(
        'Account.createEmailPasswordSession',
        e,
        stackTrace: st,
        details: {
          'email': email,
          'code': e.code,
          'type': e.type,
          'message': e.message
        },
      );
      throw AuthException(
          message: _friendlyMessage(e, fallback: 'Identifiants invalides.'));
    }
  }

  @override
  Future<void> deleteCurrentSession() async {
    AppLogger.apiRequest('Account.deleteCurrentSession');
    try {
      await account.deleteSession(sessionId: 'current');
      AppLogger.apiResponse('Account.deleteCurrentSession');
    } on AppwriteException catch (e, st) {
      AppLogger.apiError(
        'Account.deleteCurrentSession',
        e,
        stackTrace: st,
        details: {'code': e.code, 'type': e.type, 'message': e.message},
      );
      throw AuthException(
        message: _friendlyMessage(e, fallback: 'Impossible de se deconnecter.'),
      );
    }
  }

  @override
  Future<models.User> getCurrentAccount() async {
    AppLogger.apiRequest('Account.getCurrentAccount');
    try {
      final user = await account.get();
      AppLogger.apiResponse('Account.getCurrentAccount',
          details: {'id': user.$id});
      return user;
    } on AppwriteException catch (e, st) {
      AppLogger.apiError(
        'Account.getCurrentAccount',
        e,
        stackTrace: st,
        details: {'code': e.code, 'type': e.type, 'message': e.message},
      );
      throw AuthException(
        message: _friendlyMessage(e, fallback: 'Aucune session active.'),
      );
    }
  }

  @override
  Future<String> createEmailOtpToken({
    required String userId,
    required String email,
  }) async {
    AppLogger.apiRequest('Account.createEmailToken',
        details: {'userId': userId, 'email': email});
    try {
      final token =
          await account.createEmailToken(userId: userId, email: email);
      AppLogger.apiResponse('Account.createEmailToken',
          details: {'userId': userId, 'tokenUserId': token.userId});
      return token.userId;
    } on AppwriteException catch (e, st) {
      AppLogger.apiError(
        'Account.createEmailToken',
        e,
        stackTrace: st,
        details: {
          'userId': userId,
          'email': email,
          'code': e.code,
          'type': e.type,
          'message': e.message
        },
      );
      throw AuthException(
        message: _friendlyMessage(e,
            fallback: "Echec de l'envoi du code par email."),
      );
    }
  }

  @override
  Future<String> createPhoneOtpToken({
    required String userId,
    required String phone,
  }) async {
    AppLogger.apiRequest('Account.createPhoneToken',
        details: {'userId': userId, 'phone': phone});
    try {
      final token =
          await account.createPhoneToken(userId: userId, phone: phone);
      AppLogger.apiResponse('Account.createPhoneToken',
          details: {'userId': userId, 'tokenUserId': token.userId});
      return token.userId;
    } on AppwriteException catch (e, st) {
      AppLogger.apiError(
        'Account.createPhoneToken',
        e,
        stackTrace: st,
        details: {
          'userId': userId,
          'phone': phone,
          'code': e.code,
          'type': e.type,
          'message': e.message
        },
      );
      throw AuthException(
        message:
            _friendlyMessage(e, fallback: "Echec de l'envoi du code par SMS."),
      );
    }
  }

  @override
  Future<void> createSessionFromOtp({
    required String userId,
    required String secret,
  }) async {
    AppLogger.apiRequest('Account.createSessionFromOtp',
        details: {'userId': userId});
    try {
      await account.createSession(userId: userId, secret: secret);
      AppLogger.apiResponse('Account.createSessionFromOtp',
          details: {'userId': userId});
    } on AppwriteException catch (e, st) {
      AppLogger.apiError(
        'Account.createSessionFromOtp',
        e,
        stackTrace: st,
        details: {
          'userId': userId,
          'code': e.code,
          'type': e.type,
          'message': e.message
        },
      );
      throw AuthException(
        message: _friendlyMessage(e, fallback: 'Code invalide ou expire.'),
      );
    }
  }

  String _friendlyMessage(AppwriteException e, {required String fallback}) =>
      e.message ?? fallback;
}
