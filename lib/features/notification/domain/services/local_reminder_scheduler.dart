/// A generic, feature-agnostic on-device reminder mechanism - the local
/// half of cahier des charges 5.4 (push channel), built ahead of any
/// concrete feature that will use it (5.8 Bookings, 5.10 Taches), so
/// those features only need to call [syncReminder] with their own
/// computed `(entityId, scheduledFor, title, body)`, not build
/// scheduling/persistence logic themselves.
///
/// Deliberately knows NOTHING about bookings, tasks, payment state, or
/// any other domain concept - it only knows "ensure exactly one
/// reminder is scheduled for this id, at this time, with this content,"
/// which is the reusable part. The business logic that decides WHICH
/// reminder type applies to a given booking right now (confirmation
/// reminder / payment-required alert / liberation) belongs entirely to
/// 5.8, not here.
///
/// Idempotent by design, to match how it's meant to be called - on
/// every fetch of a list of reminder-worthy entities (e.g. bookings), a
/// caller recomputes what SHOULD be scheduled right now for each one and
/// calls [syncReminder] (or [cancelReminder] if nothing should be
/// scheduled anymore) unconditionally. [syncReminder] itself figures out
/// whether anything actually needs to change:
/// - Nothing currently scheduled for this id -> schedules fresh.
/// - Already scheduled for the same time -> no-op (this is what makes
///   repeated fetches safe to call this on every time, not just once).
/// - Scheduled for a DIFFERENT time (the underlying due date changed) ->
///   cancels the old one and schedules the new one.
///
/// Local-only, on purpose (explicit scope decision): no FCM, no
/// server-triggered push. This means a reminder can only be
/// (re)scheduled while the app is open and fetching - if the app isn't
/// opened again before a reminder's original due time, it won't have
/// been rescheduled in response to any change made in the meantime.
/// That's an inherent tradeoff of "local push only," not a bug.
abstract class LocalReminderScheduler {
  Future<void> initialize();

  Future<bool> requestPermission();

  Future<void> syncReminder({
    required String entityId,
    required DateTime scheduledFor,
    required String title,
    required String body,
  });

  Future<void> cancelReminder(String entityId);
}
