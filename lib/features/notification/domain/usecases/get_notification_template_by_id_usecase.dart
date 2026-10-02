import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/notification_template.dart';
import '../repositories/notification_repository.dart';

class GetNotificationTemplateByIdUseCase implements UseCase<NotificationTemplate, String> {
  final NotificationRepository repository;

  const GetNotificationTemplateByIdUseCase(this.repository);

  @override
  FutureEither<NotificationTemplate> call(String templateId) =>
      repository.getTemplateById(templateId);
}
