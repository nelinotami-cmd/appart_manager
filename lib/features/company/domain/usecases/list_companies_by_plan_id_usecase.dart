import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/company.dart';
import '../repositories/company_repository.dart';

/// Params is a plain [String] (the plan id) - no dedicated Params class
/// needed for a single-field input.
class ListCompaniesByPlanIdUseCase implements UseCase<List<Company>, String> {
  final CompanyRepository repository;

  const ListCompaniesByPlanIdUseCase(this.repository);

  @override
  FutureEither<List<Company>> call(String subscriptionPlanId) =>
      repository.listCompaniesByPlanId(subscriptionPlanId);
}
