import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/subscription_plan.dart';
import '../repositories/subscription_repository.dart';

class UpdatePlanUseCase implements UseCase<SubscriptionPlan, UpdatePlanParams> {
  final SubscriptionRepository repository;

  const UpdatePlanUseCase(this.repository);

  @override
  FutureEither<SubscriptionPlan> call(UpdatePlanParams params) => repository.updatePlan(params);
}
