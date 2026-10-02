import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/subscription_repository.dart';

/// Params is a plain [String] (the plan id) - no dedicated Params class
/// needed for a single-field input. Returns the number of companies
/// whose plan reference was cleared as a result.
class DeletePlanUseCase implements UseCase<int, String> {
  final SubscriptionRepository repository;

  const DeletePlanUseCase(this.repository);

  @override
  FutureEither<int> call(String planId) => repository.deletePlan(planId);
}
