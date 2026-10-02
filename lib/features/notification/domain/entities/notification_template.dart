import 'package:equatable/equatable.dart';

import 'notification_channel.dart';

/// Domain entity for a notification template (cahier des charges 5.4:
/// "Creation de templates de notification (message, canal)").
///
/// Deliberately generic and feature-agnostic: 5.4 has no concept yet of
/// *when* a template fires or *who* it goes to - that decision belongs
/// to whichever feature actually triggers a send (5.8 Bookings, 5.10
/// Taches), once those exist. A template here is just reusable content
/// an Admin/Super Admin can compose ahead of time and reference later.
///
/// [message] may contain `{{placeholder}}` tokens (e.g. "Le paiement de
/// {{amount}} est du le {{dueDate}}") - see
/// `renderNotificationTemplate` for how these get filled in at send
/// time. This entity itself never interprets or validates them; it's
/// just text until something renders it.
class NotificationTemplate extends Equatable {
  final String id;
  final String name;
  final String message;
  final NotificationChannel channel;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationTemplate({
    required this.id,
    required this.name,
    required this.message,
    required this.channel,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, name, message, channel, createdAt, updatedAt];
}
