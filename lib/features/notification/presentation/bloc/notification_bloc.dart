import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/no_params.dart';
import '../../domain/entities/notification_template_realtime_event.dart';
import '../../domain/repositories/notification_repository.dart' show
    CreateTemplateParams,
    UpdateTemplateParams;
import '../../domain/usecases/create_notification_template_usecase.dart';
import '../../domain/usecases/delete_notification_template_usecase.dart';
import '../../domain/usecases/get_my_notification_preferences_usecase.dart';
import '../../domain/usecases/get_notification_template_by_id_usecase.dart';
import '../../domain/usecases/list_notification_logs_usecase.dart';
import '../../domain/usecases/list_notification_templates_usecase.dart';
import '../../domain/usecases/search_notification_templates_usecase.dart';
import '../../domain/usecases/send_test_email_usecase.dart';
import '../../domain/usecases/set_muted_template_ids_usecase.dart';
import '../../domain/usecases/update_notification_template_usecase.dart';
import '../../domain/usecases/watch_notification_templates_usecase.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class _TemplateListRealtimeEventReceived extends NotificationEvent {
  final NotificationTemplateRealtimeEvent event;

  const _TemplateListRealtimeEventReceived(this.event);

  @override
  List<Object?> get props => [event];
}

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final CreateNotificationTemplateUseCase createTemplateUseCase;
  final UpdateNotificationTemplateUseCase updateTemplateUseCase;
  final DeleteNotificationTemplateUseCase deleteTemplateUseCase;
  final GetNotificationTemplateByIdUseCase getTemplateByIdUseCase;
  final ListNotificationTemplatesUseCase listTemplatesUseCase;
  final SearchNotificationTemplatesUseCase searchTemplatesUseCase;
  final WatchNotificationTemplatesUseCase watchTemplatesUseCase;
  final ListNotificationLogsUseCase listLogsUseCase;
  final SendTestEmailUseCase sendTestEmailUseCase;
  final GetMyNotificationPreferencesUseCase getMyPreferencesUseCase;
  final SetMutedTemplateIdsUseCase setMutedTemplateIdsUseCase;

  StreamSubscription<NotificationTemplateRealtimeEvent>? _realtimeSubscription;

  NotificationBloc({
    required this.createTemplateUseCase,
    required this.updateTemplateUseCase,
    required this.deleteTemplateUseCase,
    required this.getTemplateByIdUseCase,
    required this.listTemplatesUseCase,
    required this.searchTemplatesUseCase,
    required this.watchTemplatesUseCase,
    required this.listLogsUseCase,
    required this.sendTestEmailUseCase,
    required this.getMyPreferencesUseCase,
    required this.setMutedTemplateIdsUseCase,
  }) : super(const NotificationState.initial()) {
    on<NotificationTemplateDetailLoadRequested>(_onDetailLoadRequested);
    on<NotificationTemplateCreateRequested>(_onCreateRequested);
    on<NotificationTemplateUpdateRequested>(_onUpdateRequested);
    on<NotificationTemplateDeleteRequested>(_onDeleteRequested);
    on<NotificationTemplateListLoadRequested>(_onListLoadRequested);
    on<NotificationTemplateSearchRequested>(_onSearchRequested);
    on<NotificationTemplateListWatchStarted>(_onListWatchStarted);
    on<NotificationTemplateListWatchStopped>(_onListWatchStopped);
    on<NotificationLogListLoadRequested>(_onLogListLoadRequested);
    on<NotificationTestEmailSendRequested>(_onTestEmailSendRequested);
    on<NotificationPreferencesLoadRequested>(_onPreferencesLoadRequested);
    on<NotificationMutedTemplateIdsSetRequested>(_onMutedTemplateIdsSetRequested);
    on<_TemplateListRealtimeEventReceived>(_onRealtimeEventReceived);
  }

  Future<void> _onDetailLoadRequested(
    NotificationTemplateDetailLoadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(detailStatus: NotificationDetailStatus.loading, clearDetailFailure: true));
    final result = await getTemplateByIdUseCase(event.templateId);
    result.fold(
      (exception) => emit(state.copyWith(
        detailStatus: NotificationDetailStatus.error,
        detailFailure: Failure.fromException(exception),
      )),
      (template) => emit(state.copyWith(
        detailStatus: NotificationDetailStatus.loaded,
        currentTemplate: template,
      )),
    );
  }

  Future<void> _onCreateRequested(
    NotificationTemplateCreateRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(detailStatus: NotificationDetailStatus.loading, clearDetailFailure: true));
    final result = await createTemplateUseCase(
      CreateTemplateParams(name: event.name, message: event.message, channel: event.channel),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        detailStatus: NotificationDetailStatus.error,
        detailFailure: Failure.fromException(exception),
      )),
      (template) => emit(state.copyWith(
        detailStatus: NotificationDetailStatus.loaded,
        currentTemplate: template,
        templates: [template, ...state.templates],
      )),
    );
  }

  Future<void> _onUpdateRequested(
    NotificationTemplateUpdateRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(detailStatus: NotificationDetailStatus.loading, clearDetailFailure: true));
    final result = await updateTemplateUseCase(
      UpdateTemplateParams(
        templateId: event.templateId,
        name: event.name,
        message: event.message,
        channel: event.channel,
      ),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        detailStatus: NotificationDetailStatus.error,
        detailFailure: Failure.fromException(exception),
      )),
      (template) => emit(state.copyWith(
        detailStatus: NotificationDetailStatus.loaded,
        currentTemplate: template,
        templates: [
          for (final t in state.templates) if (t.id == template.id) template else t,
        ],
      )),
    );
  }

  Future<void> _onDeleteRequested(
    NotificationTemplateDeleteRequested event,
    Emitter<NotificationState> emit,
  ) async {
    final result = await deleteTemplateUseCase(event.templateId);
    result.fold(
      (exception) => emit(state.copyWith(
        listStatus: NotificationListStatus.error,
        listFailure: Failure.fromException(exception),
      )),
      (_) => emit(state.copyWith(
        templates: state.templates.where((t) => t.id != event.templateId).toList(),
      )),
    );
  }

  Future<void> _onListLoadRequested(
    NotificationTemplateListLoadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(listStatus: NotificationListStatus.loading, clearListFailure: true));
    final result = await listTemplatesUseCase(const ListNotificationTemplatesParams());
    result.fold(
      (exception) => emit(state.copyWith(
        listStatus: NotificationListStatus.error,
        listFailure: Failure.fromException(exception),
      )),
      (templates) =>
          emit(state.copyWith(listStatus: NotificationListStatus.loaded, templates: templates)),
    );
  }

  Future<void> _onSearchRequested(
    NotificationTemplateSearchRequested event,
    Emitter<NotificationState> emit,
  ) async {
    if (event.query.trim().isEmpty) {
      add(const NotificationTemplateListLoadRequested());
      return;
    }
    emit(state.copyWith(listStatus: NotificationListStatus.loading, clearListFailure: true));
    final result = await searchTemplatesUseCase(event.query.trim());
    result.fold(
      (exception) => emit(state.copyWith(
        listStatus: NotificationListStatus.error,
        listFailure: Failure.fromException(exception),
      )),
      (templates) =>
          emit(state.copyWith(listStatus: NotificationListStatus.loaded, templates: templates)),
    );
  }

  Future<void> _onListWatchStarted(
    NotificationTemplateListWatchStarted event,
    Emitter<NotificationState> emit,
  ) async {
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = watchTemplatesUseCase().listen(
      (realtimeEvent) => add(_TemplateListRealtimeEventReceived(realtimeEvent)),
    );
  }

  Future<void> _onListWatchStopped(
    NotificationTemplateListWatchStopped event,
    Emitter<NotificationState> emit,
  ) async {
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  Future<void> _onLogListLoadRequested(
    NotificationLogListLoadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(logsStatus: NotificationLogsStatus.loading, clearLogsFailure: true));
    final result = await listLogsUseCase(const ListNotificationLogsParams());
    result.fold(
      (exception) => emit(state.copyWith(
        logsStatus: NotificationLogsStatus.error,
        logsFailure: Failure.fromException(exception),
      )),
      (logs) => emit(state.copyWith(logsStatus: NotificationLogsStatus.loaded, logs: logs)),
    );
  }

  Future<void> _onTestEmailSendRequested(
    NotificationTestEmailSendRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(
      sendTestStatus: NotificationSendTestStatus.sending,
      clearSendTestFailure: true,
    ));
    final result = await sendTestEmailUseCase(
      SendTestEmailParams(subject: event.subject, message: event.message),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        sendTestStatus: NotificationSendTestStatus.error,
        sendTestFailure: Failure.fromException(exception),
      )),
      (_) {
        emit(state.copyWith(sendTestStatus: NotificationSendTestStatus.sent));
        // The test send writes a NotificationLog server-side - refresh
        // the history so it shows up without the user needing to leave
        // and come back.
        add(const NotificationLogListLoadRequested());
      },
    );
  }

  Future<void> _onPreferencesLoadRequested(
    NotificationPreferencesLoadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(
      preferencesStatus: NotificationPreferencesStatus.loading,
      clearPreferencesFailure: true,
    ));
    final result = await getMyPreferencesUseCase(const NoParams());
    result.fold(
      (exception) => emit(state.copyWith(
        preferencesStatus: NotificationPreferencesStatus.error,
        preferencesFailure: Failure.fromException(exception),
      )),
      (preferences) => emit(state.copyWith(
        preferencesStatus: NotificationPreferencesStatus.loaded,
        preferences: preferences,
      )),
    );
  }

  Future<void> _onMutedTemplateIdsSetRequested(
    NotificationMutedTemplateIdsSetRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(
      preferencesStatus: NotificationPreferencesStatus.saving,
      clearPreferencesFailure: true,
    ));
    final result = await setMutedTemplateIdsUseCase(event.mutedTemplateIds);
    result.fold(
      (exception) => emit(state.copyWith(
        preferencesStatus: NotificationPreferencesStatus.error,
        preferencesFailure: Failure.fromException(exception),
      )),
      (preferences) => emit(state.copyWith(
        preferencesStatus: NotificationPreferencesStatus.loaded,
        preferences: preferences,
      )),
    );
  }

  void _onRealtimeEventReceived(
    _TemplateListRealtimeEventReceived event,
    Emitter<NotificationState> emit,
  ) {
    final template = event.event.template;
    switch (event.event.type) {
      case NotificationTemplateEventType.created:
        if (state.templates.any((t) => t.id == template.id)) return;
        emit(state.copyWith(templates: [template, ...state.templates]));
        break;
      case NotificationTemplateEventType.updated:
        emit(state.copyWith(templates: [
          for (final t in state.templates) if (t.id == template.id) template else t,
        ]));
        break;
      case NotificationTemplateEventType.deleted:
        emit(state.copyWith(templates: state.templates.where((t) => t.id != template.id).toList()));
        break;
    }
  }

  @override
  Future<void> close() {
    _realtimeSubscription?.cancel();
    return super.close();
  }
}
