import 'package:equatable/equatable.dart';

import '../../domain/entities/notification_channel.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

class NotificationTemplateDetailLoadRequested extends NotificationEvent {
  final String templateId;

  const NotificationTemplateDetailLoadRequested({required this.templateId});

  @override
  List<Object?> get props => [templateId];
}

class NotificationTemplateCreateRequested extends NotificationEvent {
  final String name;
  final String message;
  final NotificationChannel channel;

  const NotificationTemplateCreateRequested({
    required this.name,
    required this.message,
    required this.channel,
  });

  @override
  List<Object?> get props => [name, message, channel];
}

class NotificationTemplateUpdateRequested extends NotificationEvent {
  final String templateId;
  final String name;
  final String message;
  final NotificationChannel channel;

  const NotificationTemplateUpdateRequested({
    required this.templateId,
    required this.name,
    required this.message,
    required this.channel,
  });

  @override
  List<Object?> get props => [templateId, name, message, channel];
}

class NotificationTemplateDeleteRequested extends NotificationEvent {
  final String templateId;

  const NotificationTemplateDeleteRequested({required this.templateId});

  @override
  List<Object?> get props => [templateId];
}

class NotificationTemplateListLoadRequested extends NotificationEvent {
  const NotificationTemplateListLoadRequested();
}

class NotificationTemplateSearchRequested extends NotificationEvent {
  final String query;

  const NotificationTemplateSearchRequested({required this.query});

  @override
  List<Object?> get props => [query];
}

class NotificationTemplateListWatchStarted extends NotificationEvent {
  const NotificationTemplateListWatchStarted();
}

class NotificationTemplateListWatchStopped extends NotificationEvent {
  const NotificationTemplateListWatchStopped();
}

class NotificationLogListLoadRequested extends NotificationEvent {
  const NotificationLogListLoadRequested();
}

/// Fetches the next page of logs and APPENDS to whatever's already
/// loaded, rather than replacing it - used by both the main History tab
/// and the app-bar bell panel's paginated scroll. A no-op if
/// `NotificationState.logsHasMore` is already false.
class NotificationLogListLoadMoreRequested extends NotificationEvent {
  const NotificationLogListLoadMoreRequested();
}

class NotificationTestEmailSendRequested extends NotificationEvent {
  final String subject;
  final String message;

  const NotificationTestEmailSendRequested(
      {required this.subject, required this.message});

  @override
  List<Object?> get props => [subject, message];
}

class NotificationPreferencesLoadRequested extends NotificationEvent {
  const NotificationPreferencesLoadRequested();
}

class NotificationMutedTemplateIdsSetRequested extends NotificationEvent {
  final List<String> mutedTemplateIds;

  const NotificationMutedTemplateIdsSetRequested(
      {required this.mutedTemplateIds});

  @override
  List<Object?> get props => [mutedTemplateIds];
}
