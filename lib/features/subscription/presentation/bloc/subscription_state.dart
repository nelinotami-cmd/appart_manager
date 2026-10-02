import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/subscription_plan.dart';

enum SubscriptionDetailStatus { initial, loading, loaded, error }
enum SubscriptionListStatus { initial, loading, loaded, error }

class SubscriptionState extends Equatable {
  final SubscriptionDetailStatus detailStatus;
  final SubscriptionPlan? currentPlan;
  final Failure? detailFailure;

  final SubscriptionListStatus listStatus;
  final List<SubscriptionPlan> plans;
  final Failure? listFailure;

  /// Set once, right after a delete succeeds - number of companies whose
  /// plan reference was cleared. See
  /// `SubscriptionLastDeletionResultAcknowledged`.
  final int? lastDeletedPlanCompaniesUpdated;

  const SubscriptionState({
    this.detailStatus = SubscriptionDetailStatus.initial,
    this.currentPlan,
    this.detailFailure,
    this.listStatus = SubscriptionListStatus.initial,
    this.plans = const [],
    this.listFailure,
    this.lastDeletedPlanCompaniesUpdated,
  });

  const SubscriptionState.initial() : this();

  SubscriptionState copyWith({
    SubscriptionDetailStatus? detailStatus,
    SubscriptionPlan? currentPlan,
    Failure? detailFailure,
    bool clearDetailFailure = false,
    SubscriptionListStatus? listStatus,
    List<SubscriptionPlan>? plans,
    Failure? listFailure,
    bool clearListFailure = false,
    int? lastDeletedPlanCompaniesUpdated,
    bool clearLastDeletedPlanCompaniesUpdated = false,
  }) {
    return SubscriptionState(
      detailStatus: detailStatus ?? this.detailStatus,
      currentPlan: currentPlan ?? this.currentPlan,
      detailFailure: clearDetailFailure ? null : (detailFailure ?? this.detailFailure),
      listStatus: listStatus ?? this.listStatus,
      plans: plans ?? this.plans,
      listFailure: clearListFailure ? null : (listFailure ?? this.listFailure),
      lastDeletedPlanCompaniesUpdated: clearLastDeletedPlanCompaniesUpdated
          ? null
          : (lastDeletedPlanCompaniesUpdated ?? this.lastDeletedPlanCompaniesUpdated),
    );
  }

  @override
  List<Object?> get props => [
        detailStatus,
        currentPlan,
        detailFailure,
        listStatus,
        plans,
        listFailure,
        lastDeletedPlanCompaniesUpdated,
      ];
}
