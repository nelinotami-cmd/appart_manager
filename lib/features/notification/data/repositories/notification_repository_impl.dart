import 'package:appartements_erp/features/notification/domain/entities/notification_channel.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/base_exception.dart';
import '../../../../core/typedefs/future_either.dart';
import '../../domain/entities/notification_log.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/entities/notification_template.dart';
import '../../domain/entities/notification_template_realtime_event.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_functions_remote_datasource.dart';
import '../datasources/notification_remote_datasource.dart';
import '../models/notification_preferences_model.dart';
import '../models/notification_template_model.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;
  final NotificationFunctionsRemoteDataSource functionsDataSource;

  NotificationRepositoryImpl({
    required this.remoteDataSource,
    required this.functionsDataSource,
  });

  @override
  FutureEither<NotificationTemplate> createTemplate(
      CreateTemplateParams params) async {
    try {
      final result = await functionsDataSource.createTemplate({
        'name': params.name,
        'message': params.message,
        'channel': params.channel.value,
      });
      return Right(NotificationTemplateModel.fromMap(result));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<NotificationTemplate> updateTemplate(
      UpdateTemplateParams params) async {
    try {
      final result = await functionsDataSource.updateTemplate({
        'templateId': params.templateId,
        'name': params.name,
        'message': params.message,
        'channel': params.channel.value,
      });
      return Right(NotificationTemplateModel.fromMap(result));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<bool> deleteTemplate(String templateId) async {
    try {
      await functionsDataSource.deleteTemplate({'templateId': templateId});
      return const Right(true);
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<NotificationTemplate> getTemplateById(String templateId) async {
    try {
      return Right(await remoteDataSource.getTemplateById(templateId));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<List<NotificationTemplate>> listTemplates(
      {int limit = 25, int offset = 0}) async {
    try {
      return Right(
          await remoteDataSource.listTemplates(limit: limit, offset: offset));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<List<NotificationTemplate>> searchTemplates(String query) async {
    try {
      return Right(await remoteDataSource.searchTemplates(query));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  Stream<NotificationTemplateRealtimeEvent> watchTemplates() =>
      remoteDataSource.watchTemplates();

  @override
  FutureEither<List<NotificationLog>> listLogs(
      {int limit = 25, int offset = 0}) async {
    try {
      return Right(
          await remoteDataSource.listLogs(limit: limit, offset: offset));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<bool> sendTestEmail(
      {required String subject, required String message}) async {
    try {
      await functionsDataSource
          .sendTestEmail({'subject': subject, 'message': message});
      return const Right(true);
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<NotificationPreferences> getMyPreferences() async {
    try {
      final model = await remoteDataSource.getMyPreferences();
      // No document yet = never opted out of anything, not an error -
      // the backend only creates this document the first time
      // `notification.set-my-preferences` is actually called.
      if (model == null) {
        return Right(NotificationPreferences.empty(''));
      }
      return Right(model);
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<NotificationPreferences> setMutedTemplateIds(
      List<String> templateIds) async {
    try {
      final result = await functionsDataSource.setMutedTemplateIds({
        'mutedTemplateIds': templateIds,
      });
      return Right(NotificationPreferencesModel.fromMap(result));
    } on BaseException catch (e) {
      return Left(e);
    }
  }
}
