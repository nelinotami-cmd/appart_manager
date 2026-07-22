import 'dart:async';

import 'package:appwrite/appwrite.dart';

import '../../../../core/constants/appwrite_constants.dart';
import '../../../../core/env/env_config.dart';
import '../../../../core/error/base_exception.dart';
import '../../domain/entities/company_realtime_event.dart';
import '../models/company_model.dart';

/// Non-privileged, direct Appwrite access for the `companies` collection:
/// reads only (Create/Update/Status/Plan-assignment are all privileged -
/// see `CompanyFunctionsRemoteDataSource`). Every document carries
/// `read(team:<companyId>)` + `read(label:superAdmin)` permissions (set
/// server-side at creation, in `auth.register-company-and-admin`), so
/// Appwrite's own permission system already scopes every method here
/// correctly - an Admin's `listByCompany`-equivalent call would only ever
/// return their own company; only a Super Admin-labelled caller sees every
/// company. No function call needed for any of this.
abstract class CompanyRemoteDataSource {
  Future<CompanyModel> getCompanyById(String companyId);

  Future<List<CompanyModel>> list({required int limit, required int offset});

  Future<List<CompanyModel>> search(String query);

  Future<List<CompanyModel>> listByPlanId(String subscriptionPlanId);

  Stream<CompanyRealtimeEvent> watch();
}

class CompanyRemoteDataSourceImpl implements CompanyRemoteDataSource {
  final Databases databases;
  final Realtime realtime;

  CompanyRemoteDataSourceImpl({required this.databases, required this.realtime});

  @override
  Future<CompanyModel> getCompanyById(String companyId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.companiesCollectionId,
        documentId: companyId,
      );
      return CompanyModel.fromMap(_withMeta(doc));
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        throw NotFoundException(message: "Entreprise introuvable (id: $companyId).");
      }
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  @override
  Future<List<CompanyModel>> list({required int limit, required int offset}) async {
    try {
      final result = await databases.listDocuments(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.companiesCollectionId,
        queries: [
          Query.limit(limit),
          Query.offset(offset),
          Query.orderDesc(r'$createdAt'),
        ],
      );
      return result.documents.map((doc) => CompanyModel.fromMap(_withMeta(doc))).toList();
    } on AppwriteException catch (e) {
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  @override
  Future<List<CompanyModel>> search(String query) async {
    try {
      final result = await databases.listDocuments(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.companiesCollectionId,
        queries: [
          // Requires a fulltext index on `name` (see appwrite_setup.md).
          Query.search(CompanyAttributes.name, query),
        ],
      );
      return result.documents.map((doc) => CompanyModel.fromMap(_withMeta(doc))).toList();
    } on AppwriteException catch (e) {
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  @override
  Future<List<CompanyModel>> listByPlanId(String subscriptionPlanId) async {
    try {
      final result = await databases.listDocuments(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.companiesCollectionId,
        queries: [
          Query.equal(CompanyAttributes.subscriptionPlanId, subscriptionPlanId),
          Query.limit(500),
        ],
      );
      return result.documents.map((doc) => CompanyModel.fromMap(_withMeta(doc))).toList();
    } on AppwriteException catch (e) {
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }

  @override
  Stream<CompanyRealtimeEvent> watch() {
    final channel =
        'databases.${EnvConfig.databaseId}.collections.${EnvConfig.companiesCollectionId}.documents';

    final controller = StreamController<CompanyRealtimeEvent>.broadcast();
    late final RealtimeSubscription subscription;

    subscription = realtime.subscribe([channel]);
    subscription.stream.listen(
      (event) {
        final type = _eventType(event.events);
        if (type == null) return;
        final company = CompanyModel.fromMap(event.payload);
        controller.add(CompanyRealtimeEvent(type: type, company: company));
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

  CompanyEventType? _eventType(List<String> events) {
    if (events.any((e) => e.endsWith('.create'))) return CompanyEventType.created;
    if (events.any((e) => e.endsWith('.update'))) return CompanyEventType.updated;
    if (events.any((e) => e.endsWith('.delete'))) return CompanyEventType.deleted;
    return null;
  }
}
