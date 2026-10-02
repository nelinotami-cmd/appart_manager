import 'package:equatable/equatable.dart';

import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/notification_template.dart';
import '../repositories/notification_repository.dart';

class ListNotificationTemplatesParams extends Equatable {
  final int limit;
  final int offset;

  const ListNotificationTemplatesParams({this.limit = 25, this.offset = 0});

  @override
  List<Object?> get props => [limit, offset];
}

class ListNotificationTemplatesUseCase
    implements UseCase<List<NotificationTemplate>, ListNotificationTemplatesParams> {
  final NotificationRepository repository;

  const ListNotificationTemplatesUseCase(this.repository);

  @override
  FutureEither<List<NotificationTemplate>> call(ListNotificationTemplatesParams params) =>
      repository.listTemplates(limit: params.limit, offset: params.offset);
}
