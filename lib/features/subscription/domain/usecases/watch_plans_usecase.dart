import '../entities/subscription_plan_realtime_event.dart';
import '../repositories/subscription_repository.dart';

class WatchPlansUseCase {
  final SubscriptionRepository repository;

  const WatchPlansUseCase(this.repository);

  Stream<SubscriptionPlanRealtimeEvent> call() => repository.watchPlans();
}
