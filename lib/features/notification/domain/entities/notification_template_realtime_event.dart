import 'package:equatable/equatable.dart';

import 'notification_template.dart';

enum NotificationTemplateEventType { created, updated, deleted }

class NotificationTemplateRealtimeEvent extends Equatable {
  final NotificationTemplateEventType type;
  final NotificationTemplate template;

  const NotificationTemplateRealtimeEvent({required this.type, required this.template});

  @override
  List<Object?> get props => [type, template];
}
