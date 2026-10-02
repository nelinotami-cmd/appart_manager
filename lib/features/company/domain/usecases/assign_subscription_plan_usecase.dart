import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/company.dart';
import '../repositories/company_repository.dart';

class AssignSubscriptionPlanUseCase
    implements UseCase<Company, AssignSubscriptionPlanParams> {
  final CompanyRepository repository;

  const AssignSubscriptionPlanUseCase(this.repository);

  @override
  FutureEither<Company> call(AssignSubscriptionPlanParams params) =>
      repository.assignSubscriptionPlan(params);
}
