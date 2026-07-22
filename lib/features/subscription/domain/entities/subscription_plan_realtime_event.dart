import 'package:equatable/equatable.dart';

import 'subscription_plan.dart';

enum SubscriptionPlanEventType { created, updated, deleted }

class SubscriptionPlanRealtimeEvent extends Equatable {
  final SubscriptionPlanEventType type;
  final SubscriptionPlan plan;

  const SubscriptionPlanRealtimeEvent({required this.type, required this.plan});

  @override
  List<Object?> get props => [type, plan];
}
