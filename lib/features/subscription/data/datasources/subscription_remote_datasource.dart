import 'dart:async';

import 'package:appwrite/appwrite.dart';

import '../../../../core/constants/appwrite_constants.dart';
import '../../../../core/env/env_config.dart';
import '../../../../core/error/base_exception.dart';
import '../../domain/entities/subscription_plan_realtime_event.dart';
import '../models/subscription_plan_model.dart';

/// Non-privileged, direct Appwrite access for the `subscription_plans`
/// collection: reads only (create/update/delete are all privileged - see
/// `SubscriptionFunctionsRemoteDataSource`). Every document is created
/// with `read(users)` permission, so any authenticated user can read the
/// catalog directly - no function call needed for any method here.
abstract class SubscriptionRemoteDataSource {
  Future<SubscriptionPlanModel> getById(String planId);

  Future<List<SubscriptionPlanModel>> list({required int limit, required int offset});

  Future<List<SubscriptionPlanModel>> search(String query);

  Stream<SubscriptionPlanRealtimeEvent> watch();
}

class SubscriptionRemoteDataSourceImpl implements SubscriptionRemoteDataSource {
  final Databases databases;
  final Realtime realtime;

  SubscriptionRemoteDataSourceImpl({required this.databases, required this.realtime});

  @override
  Future<SubscriptionPlanModel> getById(String planId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.subscriptionPlansCollectionId,
        documentId: planId,
      );
      return SubscriptionPlanModel.fromMap(_withMeta(doc));
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        throw NotFoundException(message: "Plan d'abonnement introuvable (id: $planId).");
      }
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  @override
  Future<List<SubscriptionPlanModel>> list({required int limit, required int offset}) async {
    try {
      final result = await databases.listDocuments(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.subscriptionPlansCollectionId,
        queries: [
          Query.limit(limit),
          Query.offset(offset),
          Query.orderAsc(SubscriptionPlanAttributes.monthlyPrice),
        ],
      );
      return result.documents
          .map((doc) => SubscriptionPlanModel.fromMap(_withMeta(doc)))
          .toList();
    } on AppwriteException catch (e) {
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  @override
  Future<List<SubscriptionPlanModel>> search(String query) async {
    try {
      final result = await databases.listDocuments(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.subscriptionPlansCollectionId,
        queries: [
          // Requires a fulltext index on `name` (see appwrite_setup.md).
          Query.search(SubscriptionPlanAttributes.name, query),
        ],
      );
      return result.documents
          .map((doc) => SubscriptionPlanModel.fromMap(_withMeta(doc)))
          .toList();
    } on AppwriteException catch (e) {
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  @override
  Stream<SubscriptionPlanRealtimeEvent> watch() {
    final channel =
        'databases.${EnvConfig.databaseId}.collections.${EnvConfig.subscriptionPlansCollectionId}.documents';

    final controller = StreamController<SubscriptionPlanRealtimeEvent>.broadcast();
    late final RealtimeSubscription subscription;

    subscription = realtime.subscribe([channel]);
    subscription.stream.listen(
      (event) {
        final type = _eventType(event.events);
        if (type == null) return;
        final plan = SubscriptionPlanModel.fromMap(event.payload);
        controller.add(SubscriptionPlanRealtimeEvent(type: type, plan: plan));
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

  SubscriptionPlanEventType? _eventType(List<String> events) {
    if (events.any((e) => e.endsWith('.create'))) return SubscriptionPlanEventType.created;
    if (events.any((e) => e.endsWith('.update'))) return SubscriptionPlanEventType.updated;
    if (events.any((e) => e.endsWith('.delete'))) return SubscriptionPlanEventType.deleted;
    return null;
  }
}
