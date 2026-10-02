import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../../../../core/env/env_config.dart';
import '../../../../core/error/base_exception.dart';

/// Gateway to the privileged `subscription.*` resources on
/// `EnvConfig.apiFunctionId` - THE one Appwrite Function for the whole
/// project (see `AuthFunctionsRemoteDataSource` for the full rationale,
/// identical here). Only writes go through this gateway; reads are plain
/// client calls in [SubscriptionRemoteDataSource].
abstract class SubscriptionFunctionsRemoteDataSource {
  Future<Map<String, dynamic>> createPlan(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> updatePlan(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> deletePlan(Map<String, dynamic> payload);
}

class SubscriptionFunctionsRemoteDataSourceImpl
    implements SubscriptionFunctionsRemoteDataSource {
  final Functions functions;

  SubscriptionFunctionsRemoteDataSourceImpl({required this.functions});

  @override
  Future<Map<String, dynamic>> createPlan(Map<String, dynamic> payload) =>
      _executeResource('subscription.create-plan', payload);

  @override
  Future<Map<String, dynamic>> updatePlan(Map<String, dynamic> payload) =>
      _executeResource('subscription.update-plan', payload);

  @override
  Future<Map<String, dynamic>> deletePlan(Map<String, dynamic> payload) =>
      _executeResource('subscription.delete-plan', payload);

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
