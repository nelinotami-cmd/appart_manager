import 'package:equatable/equatable.dart';

import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/notification_log.dart';
import '../repositories/notification_repository.dart';

class ListNotificationLogsParams extends Equatable {
  final int limit;
  final int offset;

  const ListNotificationLogsParams({this.limit = 25, this.offset = 0});

  @override
  List<Object?> get props => [limit, offset];
}

class ListNotificationLogsUseCase
    implements UseCase<List<NotificationLog>, ListNotificationLogsParams> {
  final NotificationRepository repository;

  const ListNotificationLogsUseCase(this.repository);

  @override
  FutureEither<List<NotificationLog>> call(ListNotificationLogsParams params) =>
      repository.listLogs(limit: params.limit, offset: params.offset);
}
