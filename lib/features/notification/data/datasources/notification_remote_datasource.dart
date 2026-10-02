import 'dart:async';

import 'package:appwrite/appwrite.dart';

import '../../../../core/constants/appwrite_constants.dart';
import '../../../../core/env/env_config.dart';
import '../../../../core/error/base_exception.dart';
import '../../domain/entities/notification_template_realtime_event.dart';
import '../models/notification_log_model.dart';
import '../models/notification_preferences_model.dart';
import '../models/notification_template_model.dart';

/// Non-privileged, direct Appwrite access: template reads (create/
/// update/delete are privileged - see
/// `NotificationFunctionsRemoteDataSource`) and log reads (logs are
/// never written by the client at all, only ever by the Cloud
/// Function). Every template document is created with `read(users)`
/// permission; every log document is created with
/// `read(team:<companyId>)` + `read(label:superAdmin)` (or, for a Super
/// Admin's own test-send with no company, `read(label:superAdmin)`
/// alone) - see `main.py`.
abstract class NotificationRemoteDataSource {
  Future<NotificationTemplateModel> getTemplateById(String templateId);

  Future<List<NotificationTemplateModel>> listTemplates({required int limit, required int offset});

  Future<List<NotificationTemplateModel>> searchTemplates(String query);

  Stream<NotificationTemplateRealtimeEvent> watchTemplates();

  Future<List<NotificationLogModel>> listLogs({required int limit, required int offset});

  /// Reads the CURRENT user's own preferences document directly -
  /// permitted via `read(user:<userId>)`, set by
  /// `notification.set-my-preferences` the first time it's ever called
  /// for that user. Resolves "current user" itself (via the injected
  /// `Account` service) rather than taking an explicit id - the Data
  /// layer shouldn't depend on Presentation/AuthBloc for this. Returns
  /// `null` if no document exists yet (never opted out of anything) -
  /// the repository impl maps that to `NotificationPreferences.empty`.
  Future<NotificationPreferencesModel?> getMyPreferences();
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final Databases databases;
  final Realtime realtime;
  final Account account;

  NotificationRemoteDataSourceImpl({
    required this.databases,
    required this.realtime,
    required this.account,
  });

  @override
  Future<NotificationTemplateModel> getTemplateById(String templateId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.notificationTemplatesCollectionId,
        documentId: templateId,
      );
      return NotificationTemplateModel.fromMap(_withMeta(doc));
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        throw NotFoundException(message: "Modele de notification introuvable (id: $templateId).");
      }
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  @override
  Future<List<NotificationTemplateModel>> listTemplates({
    required int limit,
    required int offset,
  }) async {
    try {
      final result = await databases.listDocuments(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.notificationTemplatesCollectionId,
        queries: [
          Query.limit(limit),
          Query.offset(offset),
          Query.orderDesc(r'$createdAt'),
        ],
      );
      return result.documents
          .map((doc) => NotificationTemplateModel.fromMap(_withMeta(doc)))
          .toList();
    } on AppwriteException catch (e) {
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  @override
  Future<List<NotificationTemplateModel>> searchTemplates(String query) async {
    try {
      final result = await databases.listDocuments(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.notificationTemplatesCollectionId,
        queries: [
          // Requires a fulltext index on `name` (see appwrite_setup.md).
          Query.search(NotificationTemplateAttributes.name, query),
        ],
      );
      return result.documents
          .map((doc) => NotificationTemplateModel.fromMap(_withMeta(doc)))
          .toList();
    } on AppwriteException catch (e) {
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  @override
  Stream<NotificationTemplateRealtimeEvent> watchTemplates() {
    final channel = 'databases.${EnvConfig.databaseId}.collections.'
        '${EnvConfig.notificationTemplatesCollectionId}.documents';

    final controller = StreamController<NotificationTemplateRealtimeEvent>.broadcast();
    late final RealtimeSubscription subscription;

    subscription = realtime.subscribe([channel]);
    subscription.stream.listen(
      (event) {
        final type = _eventType(event.events);
        if (type == null) return;
        final template = NotificationTemplateModel.fromMap(event.payload);
        controller.add(NotificationTemplateRealtimeEvent(type: type, template: template));
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await subscription.close();
    };

    return controller.stream;
  }

  @override
  Future<List<NotificationLogModel>> listLogs({required int limit, required int offset}) async {
    try {
      final result = await databases.listDocuments(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.notificationLogsCollectionId,
        queries: [
          Query.limit(limit),
          Query.offset(offset),
          Query.orderDesc(r'$createdAt'),
        ],
      );
      return result.documents.map((doc) => NotificationLogModel.fromMap(_withMeta(doc))).toList();
    } on AppwriteException catch (e) {
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  Map<String, dynamic> _withMeta(dynamic doc) => {
        ...doc.data as Map<String, dynamic>,
        r'$id': doc.$id,
        r'$createdAt': doc.$createdAt,
        r'$updatedAt': doc.$updatedAt,
      };

  @override
  Future<NotificationPreferencesModel?> getMyPreferences() async {
    try {
      final currentUser = await account.get();
      final doc = await databases.getDocument(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.notificationPreferencesCollectionId,
        documentId: currentUser.$id,
      );
      return NotificationPreferencesModel.fromMap(_withMeta(doc));
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  NotificationTemplateEventType? _eventType(List<String> events) {
    if (events.any((e) => e.endsWith('.create'))) return NotificationTemplateEventType.created;
    if (events.any((e) => e.endsWith('.update'))) return NotificationTemplateEventType.updated;
    if (events.any((e) => e.endsWith('.delete'))) return NotificationTemplateEventType.deleted;
    return null;
  }
}
