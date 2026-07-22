import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/company.dart';
import '../repositories/company_repository.dart';

class UpdateCompanyStatusUseCase
    implements UseCase<Company, UpdateCompanyStatusParams> {
  final CompanyRepository repository;

  const UpdateCompanyStatusUseCase(this.repository);

  @override
  FutureEither<Company> call(UpdateCompanyStatusParams params) =>
      repository.updateCompanyStatus(params);
}
