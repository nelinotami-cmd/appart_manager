import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/subscription_plan.dart';
import '../repositories/subscription_repository.dart';

class SearchPlansUseCase implements UseCase<List<SubscriptionPlan>, String> {
  final SubscriptionRepository repository;

  const SearchPlansUseCase(this.repository);

  @override
  FutureEither<List<SubscriptionPlan>> call(String query) => repository.searchPlans(query);
}
