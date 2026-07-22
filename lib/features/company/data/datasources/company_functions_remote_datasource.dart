import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../../../../core/env/env_config.dart';
import '../../../../core/error/base_exception.dart';

/// Gateway to the privileged `company.*` resources on `EnvConfig.apiFunctionId`
/// - THE one Appwrite Function for the whole project (see
/// `AuthFunctionsRemoteDataSource` for the full rationale, identical here).
///
/// Only WRITES go through this gateway. Reads (`getCompanyById`,
/// `listCompanies`, `searchCompanies`, `watchCompanies`) are plain,
/// non-privileged client calls in [CompanyRemoteDataSource] instead - see
/// the note on `CompanyRepository` for why writes need a function but
/// reads don't.
abstract class CompanyFunctionsRemoteDataSource {
  Future<Map<String, dynamic>> updateCompanyProfile(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> updateCompanyStatus(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> assignSubscriptionPlan(Map<String, dynamic> payload);
}

class CompanyFunctionsRemoteDataSourceImpl implements CompanyFunctionsRemoteDataSource {
  final Functions functions;

  CompanyFunctionsRemoteDataSourceImpl({required this.functions});

  @override
  Future<Map<String, dynamic>> updateCompanyProfile(Map<String, dynamic> payload) =>
      _executeResource('company.update-profile', payload);

  @override
  Future<Map<String, dynamic>> updateCompanyStatus(Map<String, dynamic> payload) =>
      _executeResource('company.update-status', payload);

  @override
  Future<Map<String, dynamic>> assignSubscriptionPlan(Map<String, dynamic> payload) =>
      _executeResource('company.assign-subscription-plan', payload);

  /// Identical pattern to `AuthFunctionsRemoteDataSourceImpl._executeResource`
  /// - kept as a separate small duplication rather than a shared base class,
  /// since the two datasources' error-message text legitimately differs and
  /// a shared abstraction would buy little for two call sites.
  Future<Map<String, dynamic>> _executeResource(
    String resource,
    Map<String, dynamic> payload,
  ) async {
    try {
      final execution = await functions.createExecution(
        functionId: EnvConfig.apiFunctionId,
        body: jsonEncode({'resource': resource, ...payload}),
      );

      if (execution.responseStatusCode >= 400) {
        final decoded = _tryDecode(execution.responseBody);
        throw ServerException(
          message: decoded?['message'] as String? ??
              'Operation refusee (code ${execution.responseStatusCode}).',
        );
      }

      final decoded = _tryDecode(execution.responseBody);
      return decoded ?? const {};
    } on AppwriteException catch (e) {
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
