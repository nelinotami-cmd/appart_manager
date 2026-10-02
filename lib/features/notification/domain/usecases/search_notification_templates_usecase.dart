import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/notification_template.dart';
import '../repositories/notification_repository.dart';

class SearchNotificationTemplatesUseCase implements UseCase<List<NotificationTemplate>, String> {
  final NotificationRepository repository;

  const SearchNotificationTemplatesUseCase(this.repository);

  @override
  FutureEither<List<NotificationTemplate>> call(String query) => repository.searchTemplates(query);
}
