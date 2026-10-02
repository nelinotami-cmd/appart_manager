import '../entities/notification_template_realtime_event.dart';
import '../repositories/notification_repository.dart';

class WatchNotificationTemplatesUseCase {
  final NotificationRepository repository;

  const WatchNotificationTemplatesUseCase(this.repository);

  Stream<NotificationTemplateRealtimeEvent> call() => repository.watchTemplates();
}
