import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/subscription_plan.dart';
import '../repositories/subscription_repository.dart';

class CreatePlanUseCase implements UseCase<SubscriptionPlan, CreatePlanParams> {
  final SubscriptionRepository repository;

  const CreatePlanUseCase(this.repository);

  @override
  FutureEither<SubscriptionPlan> call(CreatePlanParams params) => repository.createPlan(params);
}
