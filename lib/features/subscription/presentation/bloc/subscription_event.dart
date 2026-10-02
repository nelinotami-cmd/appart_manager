import 'package:equatable/equatable.dart';

import '../../domain/entities/subscription_feature.dart';

abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

class SubscriptionDetailLoadRequested extends SubscriptionEvent {
  final String planId;

  const SubscriptionDetailLoadRequested({required this.planId});

  @override
  List<Object?> get props => [planId];
}

class SubscriptionPlanCreateRequested extends SubscriptionEvent {
  final String name;
  final String description;
  final double monthlyPrice;
  final List<SubscriptionFeature> enabledFeatures;

  const SubscriptionPlanCreateRequested({
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.enabledFeatures,
  });

  @override
  List<Object?> get props => [name, description, monthlyPrice, enabledFeatures];
}

class SubscriptionPlanUpdateRequested extends SubscriptionEvent {
  final String planId;
  final String name;
  final String description;
  final double monthlyPrice;
  final List<SubscriptionFeature> enabledFeatures;

  const SubscriptionPlanUpdateRequested({
    required this.planId,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.enabledFeatures,
  });

  @override
  List<Object?> get props => [planId, name, description, monthlyPrice, enabledFeatures];
}

class SubscriptionPlanDeleteRequested extends SubscriptionEvent {
  final String planId;

  const SubscriptionPlanDeleteRequested({required this.planId});

  @override
  List<Object?> get props => [planId];
}

class SubscriptionListLoadRequested extends SubscriptionEvent {
  const SubscriptionListLoadRequested();
}

class SubscriptionSearchRequested extends SubscriptionEvent {
  final String query;

  const SubscriptionSearchRequested({required this.query});

  @override
  List<Object?> get props => [query];
}

class SubscriptionListWatchStarted extends SubscriptionEvent {
  const SubscriptionListWatchStarted();
}

class SubscriptionListWatchStopped extends SubscriptionEvent {
  const SubscriptionListWatchStopped();
}

/// Clears `SubscriptionState.lastDeletedPlanCompaniesUpdated` once the UI
/// has shown the post-deletion confirmation (e.g. "3 entreprises mises a
/// jour"), so it doesn't linger/reappear.
class SubscriptionLastDeletionResultAcknowledged extends SubscriptionEvent {
  const SubscriptionLastDeletionResultAcknowledged();
}
