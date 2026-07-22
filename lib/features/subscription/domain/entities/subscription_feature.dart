/// Feature flags a subscription plan can enable (cahier des charges 5.3:
/// "fonctionnalites activees"). The spec doesn't enumerate a fixed
/// catalog - this is a small, illustrative set tied to real sections of
/// the project rather than invented ones (the reference mockups showed
/// fictional flags like "Rapports SMS" that don't map to anything in the
/// cahier des charges). The backend does NOT validate against this list
/// (see `functions/api/src/main.py`, `subscription.create-plan`) - it's
/// purely a Flutter-side convenience for building the checkbox form and
/// rendering known flags with a label; unrecognized values coming back
/// from the server are simply skipped (see `SubscriptionPlanMapper`),
/// not treated as an error, since the catalog may grow without a Flutter
/// release keeping pace.
enum SubscriptionFeature {
  bookings,
  discounts,
  prioritySupport,
  advancedReports,
  apiAccess,
  unlimitedGestionnaires,
}

extension SubscriptionFeatureX on SubscriptionFeature {
  String get value => switch (this) {
        SubscriptionFeature.bookings => 'bookings',
        SubscriptionFeature.discounts => 'discounts',
        SubscriptionFeature.prioritySupport => 'prioritySupport',
        SubscriptionFeature.advancedReports => 'advancedReports',
        SubscriptionFeature.apiAccess => 'apiAccess',
        SubscriptionFeature.unlimitedGestionnaires => 'unlimitedGestionnaires',
      };

  String get label => switch (this) {
        SubscriptionFeature.bookings => 'Reservations (5.8)',
        SubscriptionFeature.discounts => 'Reductions (5.9)',
        SubscriptionFeature.prioritySupport => 'Support prioritaire',
        SubscriptionFeature.advancedReports => 'Rapports avances',
        SubscriptionFeature.apiAccess => 'Acces API',
        SubscriptionFeature.unlimitedGestionnaires => 'Gestionnaires illimites',
      };

  static SubscriptionFeature? tryFromValue(String value) => switch (value) {
        'bookings' => SubscriptionFeature.bookings,
        'discounts' => SubscriptionFeature.discounts,
        'prioritySupport' => SubscriptionFeature.prioritySupport,
        'advancedReports' => SubscriptionFeature.advancedReports,
        'apiAccess' => SubscriptionFeature.apiAccess,
        'unlimitedGestionnaires' => SubscriptionFeature.unlimitedGestionnaires,
        _ => null, // unrecognized - tolerated, not an error (see above).
      };
}
