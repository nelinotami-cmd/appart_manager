import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../../../../core/env/env_config.dart';
import '../../../../core/error/base_exception.dart';
import '../../../../core/logging/app_logger.dart';

/// Gateway to the privileged Appwrite Cloud Function backing every Auth
/// operation that must not trust the client to set `role`/`companyId`
/// itself, or that requires the Appwrite Server SDK (API key) to act on a
/// different user's Auth account: registration, Gestionnaire provisioning,
/// forced password reset, account activation/deactivation, deletion, and
/// login-identifier resolution.
///
/// All six operations are resources on `EnvConfig.apiFunctionId` - THE one
/// Appwrite Function for the whole project (project policy: there is only
/// ever one; other features add resources to the same function rather
/// than deploying their own). Each resource is namespaced `auth.<action>`
/// so it can never collide with another feature's resource names as more
/// get added. See `/functions/api/src/main.py` for the routing/handler
/// implementation and `appwrite_setup.md` for deployment/permission
/// configuration.
abstract class AuthFunctionsRemoteDataSource {
  Future<Map<String, dynamic>> registerCompanyAndAdmin(
      Map<String, dynamic> payload);
  Future<Map<String, dynamic>> createGestionnaireAccount(
      Map<String, dynamic> payload);
  Future<void> resetPassword(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> updateAccountStatus(
      Map<String, dynamic> payload);
  Future<void> deleteGestionnaireAccount(Map<String, dynamic> payload);

  /// Resolves a login/OTP identifier (email OR phone) to the account's
  /// `userId` + `email`, WITHOUT exposing any other profile field. Backed
  /// by a Cloud Function using the Server SDK so that the `user_profiles`
  /// collection itself never needs a public/cross-tenant read permission
  /// (which would otherwise leak fullName/role/companyId by phone number).
  /// Returns `{'userId': ..., 'email': ...}`.
  Future<Map<String, dynamic>> resolveLoginIdentifier(
      Map<String, dynamic> payload);
}

class AuthFunctionsRemoteDataSourceImpl
    implements AuthFunctionsRemoteDataSource {
  final Functions functions;

  AuthFunctionsRemoteDataSourceImpl({required this.functions});

  @override
  Future<Map<String, dynamic>> registerCompanyAndAdmin(
    Map<String, dynamic> payload,
  ) =>
      _executeResource('auth.register-company-and-admin', payload);

  @override
  Future<Map<String, dynamic>> createGestionnaireAccount(
    Map<String, dynamic> payload,
  ) =>
      _executeResource('auth.create-gestionnaire-account', payload);

  @override
  Future<void> resetPassword(Map<String, dynamic> payload) async {
    await _executeResource('auth.reset-password', payload);
  }

  @override
  Future<Map<String, dynamic>> updateAccountStatus(
          Map<String, dynamic> payload) =>
      _executeResource('auth.update-account-status', payload);

  @override
  Future<void> deleteGestionnaireAccount(Map<String, dynamic> payload) async {
    await _executeResource('auth.delete-gestionnaire-account', payload);
  }

  @override
  Future<Map<String, dynamic>> resolveLoginIdentifier(
          Map<String, dynamic> payload) =>
      _executeResource('auth.resolve-login-identifier', payload);

  /// Executes the project's single Appwrite Function, injecting [resource]
  /// into the body so `functions/api/src/main.py` can route to the right
  /// handler, then decodes the JSON response. The calling user's session
  /// is automatically forwarded by the SDK, so the function can read
  /// `req.headers['x-appwrite-user-id']` server-side to know who is
  /// calling - the client never sends its own identity in the payload for
  /// authorization purposes.
  Future<Map<String, dynamic>> _executeResource(
    String resource,
    Map<String, dynamic> payload,
  ) async {
    AppLogger.apiRequest('Functions.$resource', details: payload);
    try {
      final execution = await functions.createExecution(
        functionId: EnvConfig.apiFunctionId,
        body: jsonEncode({'resource': resource, ...payload}),
      );

      final responseBody = execution.responseBody;
      final statusCode = execution.responseStatusCode;
      AppLogger.apiResponse(
        'Functions.$resource',
        statusCode: statusCode,
        details: {'body': _tryDecode(responseBody), 'rawBody': responseBody},
      );

      if (statusCode >= 400) {
        final decoded = _tryDecode(responseBody);
        throw AuthException(
          message: decoded?['message'] as String? ??
              'Operation refusee (code $statusCode).',
        );
      }

      final decoded = _tryDecode(responseBody);
      return decoded ?? const {};
    } on AppwriteException catch (e, st) {
      AppLogger.apiError(
        'Functions.$resource',
        e,
        stackTrace: st,
        details: {
          'payload': payload,
          'code': e.code,
          'type': e.type,
          'message': e.message
        },
      );
      throw ServerException(
        message: e.message ?? "Echec de l'appel pour la ressource '$resource'.",
      );
    }
  }

  Map<String, dynamic>? _tryDecode(String raw) {
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
