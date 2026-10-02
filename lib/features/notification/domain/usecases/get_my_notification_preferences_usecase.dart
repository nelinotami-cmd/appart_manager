import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/usecase/no_params.dart';
import '../entities/notification_preferences.dart';
import '../repositories/notification_repository.dart';

class GetMyNotificationPreferencesUseCase
    implements UseCase<NotificationPreferences, NoParams> {
  final NotificationRepository repository;

  const GetMyNotificationPreferencesUseCase(this.repository);

  @override
  FutureEither<NotificationPreferences> call(NoParams params) => repository.getMyPreferences();
}
