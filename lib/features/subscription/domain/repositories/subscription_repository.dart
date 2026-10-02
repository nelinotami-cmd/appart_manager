import 'package:equatable/equatable.dart';

import '../../../../core/typedefs/future_either.dart';
import '../entities/subscription_feature.dart';
import '../entities/subscription_plan.dart';
import '../entities/subscription_plan_realtime_event.dart';

/// Domain contract for feature 5.3 (Gestion des abonnements). All writes
/// are Super Admin-only privileged Cloud Function calls (`subscription.*`
/// on the shared `api` function); reads are plain client calls, since
/// every plan document is created with `read(users)` permission - the
/// catalog isn't sensitive and Admins need to see their own plan's
/// features/price (5.2).
abstract class SubscriptionRepository {
  FutureEither<SubscriptionPlan> createPlan(CreatePlanParams params);

  FutureEither<SubscriptionPlan> updatePlan(UpdatePlanParams params);

  /// Real deletion (see `SubscriptionPlan`'s doc comment for why there's
  /// no soft-deactivation state). Returns the number of companies whose
  /// `subscriptionPlanId` was cleared as a result - purely informational
  /// for the UI to show after the fact; the *before* impact preview is a
  /// separate call (`CompanyRepository.listCompaniesByPlanId`).
  FutureEither<int> deletePlan(String planId);

  FutureEither<SubscriptionPlan> getPlanById(String planId);

  FutureEither<List<SubscriptionPlan>> listPlans({int limit = 25, int offset = 0});

  FutureEither<List<SubscriptionPlan>> searchPlans(String query);

  Stream<SubscriptionPlanRealtimeEvent> watchPlans();
}

class CreatePlanParams extends Equatable {
  final String name;
  final String description;
  final double monthlyPrice;
  final List<SubscriptionFeature> enabledFeatures;

  const CreatePlanParams({
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.enabledFeatures,
  });

  @override
  List<Object?> get props => [name, description, monthlyPrice, enabledFeatures];
}

class UpdatePlanParams extends Equatable {
  final String planId;
  final String name;
  final String description;
  final double monthlyPrice;
  final List<SubscriptionFeature> enabledFeatures;

  const UpdatePlanParams({
    required this.planId,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.enabledFeatures,
  });

  @override
  List<Object?> get props => [planId, name, description, monthlyPrice, enabledFeatures];
}
