import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/notification_log.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/entities/notification_template.dart';

enum NotificationDetailStatus { initial, loading, loaded, error }
enum NotificationListStatus { initial, loading, loaded, error }
enum NotificationLogsStatus { initial, loading, loaded, error }
enum NotificationSendTestStatus { initial, sending, sent, error }
enum NotificationPreferencesStatus { initial, loading, loaded, saving, error }

class NotificationState extends Equatable {
  final NotificationDetailStatus detailStatus;
  final NotificationTemplate? currentTemplate;
  final Failure? detailFailure;

  final NotificationListStatus listStatus;
  final List<NotificationTemplate> templates;
  final Failure? listFailure;

  final NotificationLogsStatus logsStatus;
  final List<NotificationLog> logs;
  final Failure? logsFailure;

  final NotificationSendTestStatus sendTestStatus;
  final Failure? sendTestFailure;

  final NotificationPreferencesStatus preferencesStatus;
  final NotificationPreferences? preferences;
  final Failure? preferencesFailure;

  const NotificationState({
    this.detailStatus = NotificationDetailStatus.initial,
    this.currentTemplate,
    this.detailFailure,
    this.listStatus = NotificationListStatus.initial,
    this.templates = const [],
    this.listFailure,
    this.logsStatus = NotificationLogsStatus.initial,
    this.logs = const [],
    this.logsFailure,
    this.sendTestStatus = NotificationSendTestStatus.initial,
    this.sendTestFailure,
    this.preferencesStatus = NotificationPreferencesStatus.initial,
    this.preferences,
    this.preferencesFailure,
  });

  const NotificationState.initial() : this();

  NotificationState copyWith({
    NotificationDetailStatus? detailStatus,
    NotificationTemplate? currentTemplate,
    Failure? detailFailure,
    bool clearDetailFailure = false,
    NotificationListStatus? listStatus,
    List<NotificationTemplate>? templates,
    Failure? listFailure,
    bool clearListFailure = false,
    NotificationLogsStatus? logsStatus,
    List<NotificationLog>? logs,
    Failure? logsFailure,
    bool clearLogsFailure = false,
    NotificationSendTestStatus? sendTestStatus,
    Failure? sendTestFailure,
    bool clearSendTestFailure = false,
    NotificationPreferencesStatus? preferencesStatus,
    NotificationPreferences? preferences,
    Failure? preferencesFailure,
    bool clearPreferencesFailure = false,
  }) {
    return NotificationState(
      detailStatus: detailStatus ?? this.detailStatus,
      currentTemplate: currentTemplate ?? this.currentTemplate,
      detailFailure: clearDetailFailure ? null : (detailFailure ?? this.detailFailure),
      listStatus: listStatus ?? this.listStatus,
      templates: templates ?? this.templates,
      listFailure: clearListFailure ? null : (listFailure ?? this.listFailure),
      logsStatus: logsStatus ?? this.logsStatus,
      logs: logs ?? this.logs,
      logsFailure: clearLogsFailure ? null : (logsFailure ?? this.logsFailure),
      sendTestStatus: sendTestStatus ?? this.sendTestStatus,
      sendTestFailure: clearSendTestFailure ? null : (sendTestFailure ?? this.sendTestFailure),
      preferencesStatus: preferencesStatus ?? this.preferencesStatus,
      preferences: preferences ?? this.preferences,
      preferencesFailure:
          clearPreferencesFailure ? null : (preferencesFailure ?? this.preferencesFailure),
    );
  }

  @override
  List<Object?> get props => [
        detailStatus,
        currentTemplate,
        detailFailure,
        listStatus,
        templates,
        listFailure,
        logsStatus,
        logs,
        logsFailure,
        sendTestStatus,
        sendTestFailure,
        preferencesStatus,
        preferences,
        preferencesFailure,
      ];
}
