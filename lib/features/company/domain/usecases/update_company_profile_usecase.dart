import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/company.dart';
import '../repositories/company_repository.dart';

class UpdateCompanyProfileUseCase
    implements UseCase<Company, UpdateCompanyProfileParams> {
  final CompanyRepository repository;

  const UpdateCompanyProfileUseCase(this.repository);

  @override
  FutureEither<Company> call(UpdateCompanyProfileParams params) =>
      repository.updateCompanyProfile(params);
}
