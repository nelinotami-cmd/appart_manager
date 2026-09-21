import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/notification_repository.dart';

/// Params is a plain [String] (the template id) - no dedicated Params
/// class needed for a single-field input.
class DeleteNotificationTemplateUseCase implements UseCase<bool, String> {
  final NotificationRepository repository;

  const DeleteNotificationTemplateUseCase(this.repository);

  @override
  FutureEither<bool> call(String templateId) => repository.deleteTemplate(templateId);
}
