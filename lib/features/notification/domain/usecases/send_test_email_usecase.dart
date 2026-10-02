import 'package:equatable/equatable.dart';

import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/notification_repository.dart';

class SendTestEmailParams extends Equatable {
  final String subject;
  final String message;

  const SendTestEmailParams({required this.subject, required this.message});

  @override
  List<Object?> get props => [subject, message];
}

class SendTestEmailUseCase implements UseCase<bool, SendTestEmailParams> {
  final NotificationRepository repository;

  const SendTestEmailUseCase(this.repository);

  @override
  FutureEither<bool> call(SendTestEmailParams params) =>
      repository.sendTestEmail(subject: params.subject, message: params.message);
}
