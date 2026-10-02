import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/subscription_plan.dart';
import '../repositories/subscription_repository.dart';

class GetPlanByIdUseCase implements UseCase<SubscriptionPlan, String> {
  final SubscriptionRepository repository;

  const GetPlanByIdUseCase(this.repository);

  @override
  FutureEither<SubscriptionPlan> call(String planId) => repository.getPlanById(planId);
}
