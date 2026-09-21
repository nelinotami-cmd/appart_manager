/// Cahier des charges 5.4: templates carry a "canal" (channel). Scope
/// narrowed per explicit instruction: local push and email only - no
/// SMS, no FCM/cloud push (see `LocalReminderScheduler`'s doc comment
/// for why push is on-device only).
enum NotificationChannel { push, email }

extension NotificationChannelX on NotificationChannel {
  String get value => switch (this) {
        NotificationChannel.push => 'push',
        NotificationChannel.email => 'email',
      };

  String get label => switch (this) {
        NotificationChannel.push => 'Push (local)',
        NotificationChannel.email => 'Email',
      };

  static NotificationChannel fromValue(String value) => switch (value) {
        'push' => NotificationChannel.push,
        'email' => NotificationChannel.email,
        _ => throw ArgumentError('Unknown NotificationChannel: $value'),
      };
}
