import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/company.dart';
import '../repositories/company_repository.dart';

/// Params is a plain [String] query - no dedicated Params class needed
/// for a single-field input.
class SearchCompaniesUseCase implements UseCase<List<Company>, String> {
  final CompanyRepository repository;

  const SearchCompaniesUseCase(this.repository);

  @override
  FutureEither<List<Company>> call(String query) => repository.searchCompanies(query);
}
