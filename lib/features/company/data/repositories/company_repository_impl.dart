import 'package:dartz/dartz.dart';

import '../../../../core/error/base_exception.dart';
import '../../../../core/typedefs/future_either.dart';
import '../../domain/entities/company.dart';
import '../../domain/repositories/company_repository.dart';
import '../datasources/company_remote_datasource.dart';

class CompanyRepositoryImpl implements CompanyRepository {
  final CompanyRemoteDataSource remoteDataSource;

  CompanyRepositoryImpl({required this.remoteDataSource});

  @override
  FutureEither<Company> getCompanyById(String companyId) async {
    try {
      final company = await remoteDataSource.getCompanyById(companyId);
      return Right(company);
    } on BaseException catch (e) {
      return Left(e);
    }
  }
}
