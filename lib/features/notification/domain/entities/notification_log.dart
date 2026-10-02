import 'package:equatable/equatable.dart';

import 'notification_channel.dart';

/// "sent" means the backend's call to the delivery provider (Appwrite
/// Messaging for email; the local OS scheduler for push) succeeded - not
/// a delivery receipt. Appwrite Messaging tracks its own richer
/// delivery/error state server-side; this log is deliberately simpler,
/// matching what 5.4 actually needs (a history list), not a full
/// delivery-tracking system.
enum NotificationLogStatus { sent, failed }

extension NotificationLogStatusX on NotificationLogStatus {
  String get value => switch (this) {
        NotificationLogStatus.sent => 'sent',
        NotificationLogStatus.failed => 'failed',
      };

  static NotificationLogStatus fromValue(String value) => switch (value) {
        'sent' => NotificationLogStatus.sent,
        'failed' => NotificationLogStatus.failed,
        _ => throw ArgumentError('Unknown NotificationLogStatus: $value'),
      };
}

/// Domain entity for one entry in the notification history (cahier des
/// charges 5.4: "Historique des notifications envoyees").
///
/// [companyId] is nullable: a Super Admin's own test-sends (Super Admin
/// has no company) produce a log entry with no company, alongside
/// company-scoped entries from Admins - both are legitimate history.
class NotificationLog extends Equatable {
  final String id;
  final String? companyId;
  final String recipientLabel;
  final NotificationChannel channel;
  final String subject;
  final String message;
  final NotificationLogStatus status;
  final String? errorMessage;
  final DateTime createdAt;

  const NotificationLog({
    required this.id,
    required this.companyId,
    required this.recipientLabel,
    required this.channel,
    required this.subject,
    required this.message,
    required this.status,
    required this.errorMessage,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        companyId,
        recipientLabel,
        channel,
        subject,
        message,
        status,
        errorMessage,
        createdAt,
      ];
}
