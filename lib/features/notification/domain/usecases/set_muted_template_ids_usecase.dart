import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/notification_preferences.dart';
import '../repositories/notification_repository.dart';

/// Params is a plain [List<String>] (the full replacement list of muted
/// template ids) - no dedicated Params class needed for a single-field
/// input.
class SetMutedTemplateIdsUseCase implements UseCase<NotificationPreferences, List<String>> {
  final NotificationRepository repository;

  const SetMutedTemplateIdsUseCase(this.repository);

  @override
  FutureEither<NotificationPreferences> call(List<String> templateIds) =>
      repository.setMutedTemplateIds(templateIds);
}
