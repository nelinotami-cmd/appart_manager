import 'package:appartements_erp/features/company/domain/entities/company_status.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/base_exception.dart';
import '../../../../core/typedefs/future_either.dart';
import '../../domain/entities/company.dart';
import '../../domain/entities/company_realtime_event.dart';
import '../../domain/repositories/company_repository.dart';
import '../datasources/company_functions_remote_datasource.dart';
import '../datasources/company_remote_datasource.dart';
import '../models/company_model.dart';

class CompanyRepositoryImpl implements CompanyRepository {
  final CompanyRemoteDataSource remoteDataSource;
  final CompanyFunctionsRemoteDataSource functionsDataSource;

  CompanyRepositoryImpl({
    required this.remoteDataSource,
    required this.functionsDataSource,
  });

  @override
  FutureEither<Company> getCompanyById(String companyId) async {
    try {
      return Right(await remoteDataSource.getCompanyById(companyId));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<Company> updateCompanyProfile(
      UpdateCompanyProfileParams params) async {
    try {
      final result = await functionsDataSource.updateCompanyProfile({
        'companyId': params.companyId,
        'name': params.name,
        'contactName': params.contactName,
        'contactEmail': params.contactEmail,
        'contactPhone': params.contactPhone,
        'address': params.address,
      });
      return Right(CompanyModel.fromMap(result));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<Company> updateCompanyStatus(
      UpdateCompanyStatusParams params) async {
    try {
      final result = await functionsDataSource.updateCompanyStatus({
        'companyId': params.companyId,
        'status': params.status.value,
      });
      return Right(CompanyModel.fromMap(result));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<Company> assignSubscriptionPlan(
      AssignSubscriptionPlanParams params) async {
    try {
      final result = await functionsDataSource.assignSubscriptionPlan({
        'companyId': params.companyId,
        'subscriptionPlanId': params.subscriptionPlanId,
      });
      return Right(CompanyModel.fromMap(result));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<List<Company>> listCompanies(
      {int limit = 25, int offset = 0}) async {
    try {
      return Right(await remoteDataSource.list(limit: limit, offset: offset));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<List<Company>> searchCompanies(String query) async {
    try {
      return Right(await remoteDataSource.search(query));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<List<Company>> listCompaniesByPlanId(
      String subscriptionPlanId) async {
    try {
      return Right(await remoteDataSource.listByPlanId(subscriptionPlanId));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  Stream<CompanyRealtimeEvent> watchCompanies() => remoteDataSource.watch();
}
