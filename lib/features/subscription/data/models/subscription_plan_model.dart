import '../../../../core/constants/appwrite_constants.dart';
import '../../domain/entities/subscription_feature.dart';
import '../../domain/entities/subscription_plan.dart';

/// Data-layer model mirroring the `subscription_plans` Appwrite
/// collection. Extends the Domain entity directly (Equatable inherited),
/// no Freezed.
class SubscriptionPlanModel extends SubscriptionPlan {
  const SubscriptionPlanModel({
    required super.id,
    required super.name,
    required super.description,
    required super.monthlyPrice,
    required super.enabledFeatures,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Builds a [SubscriptionPlanModel] from a raw Appwrite document map
  /// (`Document.data` merged with `$id`/`$createdAt`/`$updatedAt`).
  /// Unrecognized feature-flag strings are silently skipped (see
  /// `SubscriptionFeature`'s doc comment for why that's intentional, not
  /// a bug).
  factory SubscriptionPlanModel.fromMap(Map<String, dynamic> map) {
    final rawFeatures = (map[SubscriptionPlanAttributes.enabledFeatures] as List?) ?? const [];
    return SubscriptionPlanModel(
      id: map[r'$id'] as String,
      name: map[SubscriptionPlanAttributes.name] as String,
      description: map[SubscriptionPlanAttributes.description] as String,
      monthlyPrice: (map[SubscriptionPlanAttributes.monthlyPrice] as num).toDouble(),
      enabledFeatures: rawFeatures
          .cast<String>()
          .map(SubscriptionFeatureX.tryFromValue)
          .whereType<SubscriptionFeature>()
          .toList(),
      createdAt: DateTime.parse(map[r'$createdAt'] as String),
      updatedAt: DateTime.parse(map[r'$updatedAt'] as String),
    );
  }
}
