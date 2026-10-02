import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/company.dart';
import '../repositories/company_repository.dart';

class GetCompanyByIdUseCase implements UseCase<Company, String> {
  final CompanyRepository repository;

  const GetCompanyByIdUseCase(this.repository);

  @override
  FutureEither<Company> call(String companyId) => repository.getCompanyById(companyId);
}
