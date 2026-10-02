import 'dart:async';

import 'package:appwrite/appwrite.dart';

import '../../../../core/constants/appwrite_constants.dart';
import '../../../../core/env/env_config.dart';
import '../../../../core/error/base_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/user_profile_realtime_event.dart';
import '../mappers/user_profile_mapper.dart';
import '../models/user_profile_model.dart';

/// Direct (non-privileged) read/search/realtime access to the
/// `user_profiles` collection. Document *creation* always goes through
/// [AuthFunctionsRemoteDataSource] - this datasource never writes new
/// documents, only reads them (the collection's `create` permission is
/// server-only, see appwrite_setup.md).
abstract class UserProfileRemoteDataSource {
  Future<UserProfileModel> getById(String userId);

  Future<List<UserProfileModel>> listByCompany({
    required String companyId,
    required int limit,
    required int offset,
  });

  Future<List<UserProfileModel>> search({
    required String companyId,
    required String query,
  });

  Stream<UserProfileRealtimeEvent> watchByCompany(String companyId);
}

class UserProfileRemoteDataSourceImpl implements UserProfileRemoteDataSource {
  final Databases databases;
  final Realtime realtime;

  UserProfileRemoteDataSourceImpl(
      {required this.databases, required this.realtime});

  @override
  Future<UserProfileModel> getById(String userId) async {
    AppLogger.apiRequest('Databases.getDocument', details: {
      'collection': EnvConfig.userProfilesCollectionId,
      'documentId': userId
    });
    try {
      final doc = await databases.getDocument(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.userProfilesCollectionId,
        documentId: userId,
      );
      AppLogger.apiResponse('Databases.getDocument',
          details: {'documentId': userId, 'data': _withMeta(doc)});
      return UserProfileMapper.fromMap(_withMeta(doc));
    } on AppwriteException catch (e, st) {
      AppLogger.apiError(
        'Databases.getDocument',
        e,
        stackTrace: st,
        details: {
          'collection': EnvConfig.userProfilesCollectionId,
          'documentId': userId,
          'code': e.code,
          'type': e.type,
          'message': e.message
        },
      );
      if (e.code == 404) {
        throw NotFoundException(message: 'Profil utilisateur introuvable.');
      }
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  @override
  Future<List<UserProfileModel>> listByCompany({
    required String companyId,
    required int limit,
    required int offset,
  }) async {
    final details = {
      'collection': EnvConfig.userProfilesCollectionId,
      'companyId': companyId,
      'limit': limit,
      'offset': offset,
    };
    AppLogger.apiRequest('Databases.listDocuments', details: details);
    try {
      final result = await databases.listDocuments(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.userProfilesCollectionId,
        queries: [
          Query.equal(UserProfileAttributes.companyId, companyId),
          Query.limit(limit),
          Query.offset(offset),
          Query.orderDesc(r'$createdAt'),
        ],
      );
      final docs = result.documents
          .map((doc) => UserProfileMapper.fromMap(_withMeta(doc)))
          .toList();
      AppLogger.apiResponse('Databases.listDocuments',
          details: {'resultCount': docs.length, ...details});
      return docs;
    } on AppwriteException catch (e, st) {
      AppLogger.apiError(
        'Databases.listDocuments',
        e,
        stackTrace: st,
        details: {
          ...details,
          'code': e.code,
          'type': e.type,
          'message': e.message
        },
      );
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  @override
  Future<List<UserProfileModel>> search({
    required String companyId,
    required String query,
  }) async {
    final details = {
      'collection': EnvConfig.userProfilesCollectionId,
      'companyId': companyId,
      'query': query,
    };
    AppLogger.apiRequest('Databases.listDocuments(search)', details: details);
    try {
      final result = await databases.listDocuments(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.userProfilesCollectionId,
        queries: [
          Query.equal(UserProfileAttributes.companyId, companyId),
          // Requires a fulltext index on `fullName` (see appwrite_setup.md).
          Query.search(UserProfileAttributes.fullName, query),
        ],
      );
      final docs = result.documents
          .map((doc) => UserProfileMapper.fromMap(_withMeta(doc)))
          .toList();
      AppLogger.apiResponse('Databases.listDocuments(search)',
          details: {'resultCount': docs.length, ...details});
      return docs;
    } on AppwriteException catch (e, st) {
      AppLogger.apiError(
        'Databases.listDocuments(search)',
        e,
        stackTrace: st,
        details: {
          ...details,
          'code': e.code,
          'type': e.type,
          'message': e.message
        },
      );
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  @override
  Stream<UserProfileRealtimeEvent> watchByCompany(String companyId) {
    final channel =
        'databases.${EnvConfig.databaseId}.collections.${EnvConfig.userProfilesCollectionId}.documents';

    final controller = StreamController<UserProfileRealtimeEvent>.broadcast();
    late final RealtimeSubscription subscription;

    subscription = realtime.subscribe([channel]);
    subscription.stream.listen(
      (event) {
        final payload = event.payload;
        if (payload[UserProfileAttributes.companyId] != companyId &&
            _extractRelationId(payload[UserProfileAttributes.companyId]) !=
                companyId) {
          return; // Not this tenant - Appwrite realtime has no server-side
          // filter by attribute, so we filter client-side.
        }

        final type = _eventType(event.events);
        if (type == null) return;

        final profile = UserProfileMapper.fromMap(payload);
        controller.add(UserProfileRealtimeEvent(type: type, profile: profile));
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await subscription.close();
    };

    return controller.stream;
  }

  Map<String, dynamic> _withMeta(dynamic doc) => {
        ...doc.data as Map<String, dynamic>,
        r'$id': doc.$id,
        r'$createdAt': doc.$createdAt,
        r'$updatedAt': doc.$updatedAt,
      };

  String? _extractRelationId(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    if (raw is Map<String, dynamic>) return raw[r'$id'] as String?;
    return null;
  }

  UserProfileEventType? _eventType(List<String> events) {
    if (events.any((e) => e.endsWith('.create')))
      return UserProfileEventType.created;
    if (events.any((e) => e.endsWith('.update')))
      return UserProfileEventType.updated;
    if (events.any((e) => e.endsWith('.delete')))
      return UserProfileEventType.deleted;
    return null;
  }
}
