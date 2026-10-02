import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/notification_template.dart';
import '../repositories/notification_repository.dart';

class CreateNotificationTemplateUseCase
    implements UseCase<NotificationTemplate, CreateTemplateParams> {
  final NotificationRepository repository;

  const CreateNotificationTemplateUseCase(this.repository);

  @override
  FutureEither<NotificationTemplate> call(CreateTemplateParams params) =>
      repository.createTemplate(params);
}
