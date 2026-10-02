import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../../../../core/env/env_config.dart';
import '../../../../core/error/base_exception.dart';

/// Gateway to the privileged `notification.*` resources on
/// `EnvConfig.apiFunctionId` - THE one Appwrite Function for the whole
/// project. Only writes go through this gateway; template reads and log
/// reads are plain client calls in [NotificationRemoteDataSource].
abstract class NotificationFunctionsRemoteDataSource {
  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> updateTemplate(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> deleteTemplate(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> sendTestEmail(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> setMutedTemplateIds(Map<String, dynamic> payload);
}

class NotificationFunctionsRemoteDataSourceImpl
    implements NotificationFunctionsRemoteDataSource {
  final Functions functions;

  NotificationFunctionsRemoteDataSourceImpl({required this.functions});

  @override
  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> payload) =>
      _executeResource('notification.create-template', payload);

  @override
  Future<Map<String, dynamic>> updateTemplate(Map<String, dynamic> payload) =>
      _executeResource('notification.update-template', payload);

  @override
  Future<Map<String, dynamic>> deleteTemplate(Map<String, dynamic> payload) =>
      _executeResource('notification.delete-template', payload);

  @override
  Future<Map<String, dynamic>> sendTestEmail(Map<String, dynamic> payload) =>
      _executeResource('notification.send-test-email', payload);

  @override
  Future<Map<String, dynamic>> setMutedTemplateIds(Map<String, dynamic> payload) =>
      _executeResource('notification.set-my-preferences', payload);

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
