import 'package:equatable/equatable.dart';

import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/company.dart';
import '../repositories/company_repository.dart';

class ListCompaniesParams extends Equatable {
  final int limit;
  final int offset;

  const ListCompaniesParams({this.limit = 25, this.offset = 0});

  @override
  List<Object?> get props => [limit, offset];
}

class ListCompaniesUseCase implements UseCase<List<Company>, ListCompaniesParams> {
  final CompanyRepository repository;

  const ListCompaniesUseCase(this.repository);

  @override
  FutureEither<List<Company>> call(ListCompaniesParams params) =>
      repository.listCompanies(limit: params.limit, offset: params.offset);
}
