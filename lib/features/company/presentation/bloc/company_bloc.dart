import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/company_realtime_event.dart';
import '../../domain/repositories/company_repository.dart' show
    UpdateCompanyProfileParams,
    UpdateCompanyStatusParams,
    AssignSubscriptionPlanParams;
import '../../domain/entities/company_status.dart';
import '../../domain/usecases/get_company_by_id_usecase.dart';
import '../../domain/usecases/update_company_profile_usecase.dart';
import '../../domain/usecases/update_company_status_usecase.dart';
import '../../domain/usecases/assign_subscription_plan_usecase.dart';
import '../../domain/usecases/list_companies_usecase.dart';
import '../../domain/usecases/search_companies_usecase.dart';
import '../../domain/usecases/watch_companies_usecase.dart';
import 'company_event.dart';
import 'company_state.dart';

class _CompanyListRealtimeEventReceived extends CompanyEvent {
  final CompanyRealtimeEvent event;

  const _CompanyListRealtimeEventReceived(this.event);

  @override
  List<Object?> get props => [event];
}

class CompanyBloc extends Bloc<CompanyEvent, CompanyState> {
  final GetCompanyByIdUseCase getCompanyByIdUseCase;
  final UpdateCompanyProfileUseCase updateCompanyProfileUseCase;
  final UpdateCompanyStatusUseCase updateCompanyStatusUseCase;
  final AssignSubscriptionPlanUseCase assignSubscriptionPlanUseCase;
  final ListCompaniesUseCase listCompaniesUseCase;
  final SearchCompaniesUseCase searchCompaniesUseCase;
  final WatchCompaniesUseCase watchCompaniesUseCase;

  StreamSubscription<CompanyRealtimeEvent>? _realtimeSubscription;

  CompanyBloc({
    required this.getCompanyByIdUseCase,
    required this.updateCompanyProfileUseCase,
    required this.updateCompanyStatusUseCase,
    required this.assignSubscriptionPlanUseCase,
    required this.listCompaniesUseCase,
    required this.searchCompaniesUseCase,
    required this.watchCompaniesUseCase,
  }) : super(const CompanyState.initial()) {
    on<CompanyDetailLoadRequested>(_onDetailLoadRequested);
    on<CompanyProfileUpdateRequested>(_onProfileUpdateRequested);
    on<CompanyStatusUpdateRequested>(_onStatusUpdateRequested);
    on<CompanyPlanAssignRequested>(_onPlanAssignRequested);
    on<CompanyListLoadRequested>(_onListLoadRequested);
    on<CompanySearchRequested>(_onSearchRequested);
    on<CompanyListWatchStarted>(_onListWatchStarted);
    on<CompanyListWatchStopped>(_onListWatchStopped);
    on<_CompanyListRealtimeEventReceived>(_onRealtimeEventReceived);
  }

  Future<void> _onDetailLoadRequested(
    CompanyDetailLoadRequested event,
    Emitter<CompanyState> emit,
  ) async {
    emit(state.copyWith(detailStatus: CompanyDetailStatus.loading, clearDetailFailure: true));
    final result = await getCompanyByIdUseCase(event.companyId);
    result.fold(
      (exception) => emit(state.copyWith(
        detailStatus: CompanyDetailStatus.error,
        detailFailure: Failure.fromException(exception),
      )),
      (company) => emit(state.copyWith(
        detailStatus: CompanyDetailStatus.loaded,
        currentCompany: company,
      )),
    );
  }

  Future<void> _onProfileUpdateRequested(
    CompanyProfileUpdateRequested event,
    Emitter<CompanyState> emit,
  ) async {
    emit(state.copyWith(detailStatus: CompanyDetailStatus.loading, clearDetailFailure: true));
    final result = await updateCompanyProfileUseCase(
      UpdateCompanyProfileParams(
        companyId: event.companyId,
        name: event.name,
        contactName: event.contactName,
        contactEmail: event.contactEmail,
        contactPhone: event.contactPhone,
        address: event.address,
      ),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        detailStatus: CompanyDetailStatus.error,
        detailFailure: Failure.fromException(exception),
      )),
      (company) => emit(state.copyWith(
        detailStatus: CompanyDetailStatus.loaded,
        currentCompany: company,
      )),
    );
  }

  Future<void> _onStatusUpdateRequested(
    CompanyStatusUpdateRequested event,
    Emitter<CompanyState> emit,
  ) async {
    final result = await updateCompanyStatusUseCase(
      UpdateCompanyStatusParams(
        companyId: event.companyId,
        status: event.activate ? CompanyStatus.active : CompanyStatus.inactive,
      ),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        detailStatus: CompanyDetailStatus.error,
        detailFailure: Failure.fromException(exception),
      )),
      (company) => emit(state.copyWith(
        detailStatus: CompanyDetailStatus.loaded,
        currentCompany: company,
        companies: [
          for (final c in state.companies) if (c.id == company.id) company else c,
        ],
      )),
    );
  }

  Future<void> _onPlanAssignRequested(
    CompanyPlanAssignRequested event,
    Emitter<CompanyState> emit,
  ) async {
    final result = await assignSubscriptionPlanUseCase(
      AssignSubscriptionPlanParams(
        companyId: event.companyId,
        subscriptionPlanId: event.subscriptionPlanId,
      ),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        detailStatus: CompanyDetailStatus.error,
        detailFailure: Failure.fromException(exception),
      )),
      (company) => emit(state.copyWith(
        detailStatus: CompanyDetailStatus.loaded,
        currentCompany: company,
      )),
    );
  }

  Future<void> _onListLoadRequested(
    CompanyListLoadRequested event,
    Emitter<CompanyState> emit,
  ) async {
    emit(state.copyWith(listStatus: CompanyListStatus.loading, clearListFailure: true));
    final result = await listCompaniesUseCase(const ListCompaniesParams());
    result.fold(
      (exception) => emit(state.copyWith(
        listStatus: CompanyListStatus.error,
        listFailure: Failure.fromException(exception),
      )),
      (companies) => emit(state.copyWith(
        listStatus: CompanyListStatus.loaded,
        companies: companies,
      )),
    );
  }

  Future<void> _onSearchRequested(
    CompanySearchRequested event,
    Emitter<CompanyState> emit,
  ) async {
    if (event.query.trim().isEmpty) {
      add(const CompanyListLoadRequested());
      return;
    }
    emit(state.copyWith(listStatus: CompanyListStatus.loading, clearListFailure: true));
    final result = await searchCompaniesUseCase(event.query.trim());
    result.fold(
      (exception) => emit(state.copyWith(
        listStatus: CompanyListStatus.error,
        listFailure: Failure.fromException(exception),
      )),
      (companies) => emit(state.copyWith(
        listStatus: CompanyListStatus.loaded,
        companies: companies,
      )),
    );
  }

  Future<void> _onListWatchStarted(
    CompanyListWatchStarted event,
    Emitter<CompanyState> emit,
  ) async {
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = watchCompaniesUseCase().listen(
      (realtimeEvent) => add(_CompanyListRealtimeEventReceived(realtimeEvent)),
    );
  }

  Future<void> _onListWatchStopped(
    CompanyListWatchStopped event,
    Emitter<CompanyState> emit,
  ) async {
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  void _onRealtimeEventReceived(
    _CompanyListRealtimeEventReceived event,
    Emitter<CompanyState> emit,
  ) {
    final company = event.event.company;
    switch (event.event.type) {
      case CompanyEventType.created:
        if (state.companies.any((c) => c.id == company.id)) return;
        emit(state.copyWith(companies: [company, ...state.companies]));
        break;
      case CompanyEventType.updated:
        emit(state.copyWith(companies: [
          for (final c in state.companies) if (c.id == company.id) company else c,
        ]));
        break;
      case CompanyEventType.deleted:
        emit(state.copyWith(
          companies: state.companies.where((c) => c.id != company.id).toList(),
        ));
        break;
    }
  }

  @override
  Future<void> close() {
    _realtimeSubscription?.cancel();
    return super.close();
  }
}
