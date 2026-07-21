import 'package:appwrite/appwrite.dart';

import '../../../../core/env/env_config.dart';
import '../../../../core/error/base_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/company_model.dart';

/// Raw Appwrite access for the `companies` collection. Throws
/// [BaseException] subtypes only - never leaks [AppwriteException] past
/// this layer.
abstract class CompanyRemoteDataSource {
  Future<CompanyModel> getCompanyById(String companyId);
}

class CompanyRemoteDataSourceImpl implements CompanyRemoteDataSource {
  final Databases databases;

  CompanyRemoteDataSourceImpl({required this.databases});

  @override
  Future<CompanyModel> getCompanyById(String companyId) async {
    AppLogger.apiRequest('Databases.getDocument', details: {
      'collection': EnvConfig.companiesCollectionId,
      'documentId': companyId
    });
    try {
      final doc = await databases.getDocument(
        databaseId: EnvConfig.databaseId,
        collectionId: EnvConfig.companiesCollectionId,
        documentId: companyId,
      );
      final model = CompanyModel.fromMap(doc.data
        ..[r'$id'] = doc.$id
        ..[r'$createdAt'] = doc.$createdAt
        ..[r'$updatedAt'] = doc.$updatedAt);
      AppLogger.apiResponse('Databases.getDocument',
          details: {'documentId': companyId, 'data': model});
      return model;
    } on AppwriteException catch (e, st) {
      AppLogger.apiError(
        'Databases.getDocument',
        e,
        stackTrace: st,
        details: {
          'collection': EnvConfig.companiesCollectionId,
          'documentId': companyId,
          'code': e.code,
          'type': e.type,
          'message': e.message
        },
      );
      if (e.code == 404) {
        throw NotFoundException(
            message: "Entreprise introuvable (id: $companyId).");
      }
      throw ServerException(message: e.message ?? 'Erreur Appwrite inconnue.');
    }
  }
}
