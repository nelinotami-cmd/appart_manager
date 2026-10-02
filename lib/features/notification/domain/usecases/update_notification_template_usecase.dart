import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/notification_template.dart';
import '../repositories/notification_repository.dart';

class UpdateNotificationTemplateUseCase
    implements UseCase<NotificationTemplate, UpdateTemplateParams> {
  final NotificationRepository repository;

  const UpdateNotificationTemplateUseCase(this.repository);

  @override
  FutureEither<NotificationTemplate> call(UpdateTemplateParams params) =>
      repository.updateTemplate(params);
}
