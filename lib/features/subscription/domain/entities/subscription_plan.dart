import 'package:equatable/equatable.dart';

import 'subscription_feature.dart';

/// Domain entity for a subscription plan (cahier des charges 5.3).
///
/// No `status`/active-inactive field on purpose: the cahier des charges
/// says "CRUD des plans", and deletion here is real (see
/// `SubscriptionRepository.deletePlan`) rather than a soft-deactivation -
/// there's no "legacy/inactive plan" state to represent.
class SubscriptionPlan extends Equatable {
  final String id;
  final String name;
  final String description;
  final double monthlyPrice;
  final List<SubscriptionFeature> enabledFeatures;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.enabledFeatures,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Derived, not stored: the reference mockups display an annual price
  /// alongside the monthly one, but it's always exactly this formula in
  /// every mockup shown (15% off monthly*12) - storing it separately
  /// would just be a second number that can drift out of sync with the
  /// real one.
  double get annualPrice => monthlyPrice * 12 * 0.85;

  @override
  List<Object?> get props =>
      [id, name, description, monthlyPrice, enabledFeatures, createdAt, updatedAt];
}
