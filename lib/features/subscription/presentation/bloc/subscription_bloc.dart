import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/subscription_plan_realtime_event.dart';
import '../../domain/repositories/subscription_repository.dart' show
    CreatePlanParams,
    UpdatePlanParams;
import '../../domain/usecases/create_plan_usecase.dart';
import '../../domain/usecases/update_plan_usecase.dart';
import '../../domain/usecases/delete_plan_usecase.dart';
import '../../domain/usecases/get_plan_by_id_usecase.dart';
import '../../domain/usecases/list_plans_usecase.dart';
import '../../domain/usecases/search_plans_usecase.dart';
import '../../domain/usecases/watch_plans_usecase.dart';
import 'subscription_event.dart';
import 'subscription_state.dart';

class _SubscriptionListRealtimeEventReceived extends SubscriptionEvent {
  final SubscriptionPlanRealtimeEvent event;

  const _SubscriptionListRealtimeEventReceived(this.event);

  @override
  List<Object?> get props => [event];
}

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final CreatePlanUseCase createPlanUseCase;
  final UpdatePlanUseCase updatePlanUseCase;
  final DeletePlanUseCase deletePlanUseCase;
  final GetPlanByIdUseCase getPlanByIdUseCase;
  final ListPlansUseCase listPlansUseCase;
  final SearchPlansUseCase searchPlansUseCase;
  final WatchPlansUseCase watchPlansUseCase;

  StreamSubscription<SubscriptionPlanRealtimeEvent>? _realtimeSubscription;

  SubscriptionBloc({
    required this.createPlanUseCase,
    required this.updatePlanUseCase,
    required this.deletePlanUseCase,
    required this.getPlanByIdUseCase,
    required this.listPlansUseCase,
    required this.searchPlansUseCase,
    required this.watchPlansUseCase,
  }) : super(const SubscriptionState.initial()) {
    on<SubscriptionDetailLoadRequested>(_onDetailLoadRequested);
    on<SubscriptionPlanCreateRequested>(_onPlanCreateRequested);
    on<SubscriptionPlanUpdateRequested>(_onPlanUpdateRequested);
    on<SubscriptionPlanDeleteRequested>(_onPlanDeleteRequested);
    on<SubscriptionListLoadRequested>(_onListLoadRequested);
    on<SubscriptionSearchRequested>(_onSearchRequested);
    on<SubscriptionListWatchStarted>(_onListWatchStarted);
    on<SubscriptionListWatchStopped>(_onListWatchStopped);
    on<SubscriptionLastDeletionResultAcknowledged>(_onLastDeletionResultAcknowledged);
    on<_SubscriptionListRealtimeEventReceived>(_onRealtimeEventReceived);
  }

  Future<void> _onDetailLoadRequested(
    SubscriptionDetailLoadRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(state.copyWith(detailStatus: SubscriptionDetailStatus.loading, clearDetailFailure: true));
    final result = await getPlanByIdUseCase(event.planId);
    result.fold(
      (exception) => emit(state.copyWith(
        detailStatus: SubscriptionDetailStatus.error,
        detailFailure: Failure.fromException(exception),
      )),
      (plan) => emit(state.copyWith(
        detailStatus: SubscriptionDetailStatus.loaded,
        currentPlan: plan,
      )),
    );
  }

  Future<void> _onPlanCreateRequested(
    SubscriptionPlanCreateRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(state.copyWith(detailStatus: SubscriptionDetailStatus.loading, clearDetailFailure: true));
    final result = await createPlanUseCase(
      CreatePlanParams(
        name: event.name,
        description: event.description,
        monthlyPrice: event.monthlyPrice,
        enabledFeatures: event.enabledFeatures,
      ),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        detailStatus: SubscriptionDetailStatus.error,
        detailFailure: Failure.fromException(exception),
      )),
      (plan) => emit(state.copyWith(
        detailStatus: SubscriptionDetailStatus.loaded,
        currentPlan: plan,
        plans: [plan, ...state.plans],
      )),
    );
  }

  Future<void> _onPlanUpdateRequested(
    SubscriptionPlanUpdateRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(state.copyWith(detailStatus: SubscriptionDetailStatus.loading, clearDetailFailure: true));
    final result = await updatePlanUseCase(
      UpdatePlanParams(
        planId: event.planId,
        name: event.name,
        description: event.description,
        monthlyPrice: event.monthlyPrice,
        enabledFeatures: event.enabledFeatures,
      ),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        detailStatus: SubscriptionDetailStatus.error,
        detailFailure: Failure.fromException(exception),
      )),
      (plan) => emit(state.copyWith(
        detailStatus: SubscriptionDetailStatus.loaded,
        currentPlan: plan,
        plans: [
          for (final p in state.plans) if (p.id == plan.id) plan else p,
        ],
      )),
    );
  }

  Future<void> _onPlanDeleteRequested(
    SubscriptionPlanDeleteRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    final result = await deletePlanUseCase(event.planId);
    result.fold(
      (exception) => emit(state.copyWith(
        listStatus: SubscriptionListStatus.error,
        listFailure: Failure.fromException(exception),
      )),
      (companiesUpdated) => emit(state.copyWith(
        plans: state.plans.where((p) => p.id != event.planId).toList(),
        lastDeletedPlanCompaniesUpdated: companiesUpdated,
      )),
    );
  }

  Future<void> _onListLoadRequested(
    SubscriptionListLoadRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(state.copyWith(listStatus: SubscriptionListStatus.loading, clearListFailure: true));
    final result = await listPlansUseCase(const ListPlansParams());
    result.fold(
      (exception) => emit(state.copyWith(
        listStatus: SubscriptionListStatus.error,
        listFailure: Failure.fromException(exception),
      )),
      (plans) => emit(state.copyWith(listStatus: SubscriptionListStatus.loaded, plans: plans)),
    );
  }

  Future<void> _onSearchRequested(
    SubscriptionSearchRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    if (event.query.trim().isEmpty) {
      add(const SubscriptionListLoadRequested());
      return;
    }
    emit(state.copyWith(listStatus: SubscriptionListStatus.loading, clearListFailure: true));
    final result = await searchPlansUseCase(event.query.trim());
    result.fold(
      (exception) => emit(state.copyWith(
        listStatus: SubscriptionListStatus.error,
        listFailure: Failure.fromException(exception),
      )),
      (plans) => emit(state.copyWith(listStatus: SubscriptionListStatus.loaded, plans: plans)),
    );
  }

  Future<void> _onListWatchStarted(
    SubscriptionListWatchStarted event,
    Emitter<SubscriptionState> emit,
  ) async {
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = watchPlansUseCase().listen(
      (realtimeEvent) => add(_SubscriptionListRealtimeEventReceived(realtimeEvent)),
    );
  }

  Future<void> _onListWatchStopped(
    SubscriptionListWatchStopped event,
    Emitter<SubscriptionState> emit,
  ) async {
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  void _onLastDeletionResultAcknowledged(
    SubscriptionLastDeletionResultAcknowledged event,
    Emitter<SubscriptionState> emit,
  ) {
    emit(state.copyWith(clearLastDeletedPlanCompaniesUpdated: true));
  }

  void _onRealtimeEventReceived(
    _SubscriptionListRealtimeEventReceived event,
    Emitter<SubscriptionState> emit,
  ) {
    final plan = event.event.plan;
    switch (event.event.type) {
      case SubscriptionPlanEventType.created:
        if (state.plans.any((p) => p.id == plan.id)) return;
        emit(state.copyWith(plans: [plan, ...state.plans]));
        break;
      case SubscriptionPlanEventType.updated:
        emit(state.copyWith(plans: [
          for (final p in state.plans) if (p.id == plan.id) plan else p,
        ]));
        break;
      case SubscriptionPlanEventType.deleted:
        emit(state.copyWith(plans: state.plans.where((p) => p.id != plan.id).toList()));
        break;
    }
  }

  @override
  Future<void> close() {
    _realtimeSubscription?.cancel();
    return super.close();
  }
}
