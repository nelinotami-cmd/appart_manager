import 'dart:async';

import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/no_params.dart';
import '../../domain/entities/user_profile_realtime_event.dart';
import '../../domain/repositories/auth_repository.dart' show
    RegisterCompanyAndAdminParams,
    LoginParams,
    RequestOtpParams,
    VerifyOtpParams,
    CreateGestionnaireParams,
    UpdateAccountStatusParams,
    DeleteGestionnaireParams,
    ListUserProfilesParams,
    SearchUserProfilesParams;
import '../../domain/usecases/create_gestionnaire_account_usecase.dart';
import '../../domain/usecases/delete_gestionnaire_account_usecase.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/get_user_profile_by_id_usecase.dart';
import '../../domain/usecases/list_user_profiles_by_company_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_company_and_admin_usecase.dart';
import '../../domain/usecases/request_password_reset_otp_usecase.dart';
import '../../domain/usecases/search_user_profiles_usecase.dart';
import '../../domain/usecases/update_account_status_usecase.dart';
import '../../domain/usecases/verify_otp_and_reset_password_usecase.dart';
import '../../domain/usecases/watch_user_profiles_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Very small, dependency-free regex checks. Per project convention, this
/// is the extent of "form validation" allowed in Presentation - no
/// external validator/form package, no dedicated Validators class.
class _Regex {
  static final email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  // Loose international phone check: optional '+', 8-15 digits.
  static final phone = RegExp(r'^\+?[0-9]{8,15}$');
}

/// Internal-only event: bridges the realtime [Stream] from
/// [WatchUserProfilesUseCase] into the Bloc's event-driven model, per
/// standard `flutter_bloc` practice for wrapping external streams.
class _AuthCompanyUsersRealtimeEventReceived extends AuthEvent {
  final UserProfileRealtimeEvent event;

  const _AuthCompanyUsersRealtimeEventReceived(this.event);

  @override
  List<Object?> get props => [event];
}

class AuthBloc extends HydratedBloc<AuthEvent, AuthState> {
  final RegisterCompanyAndAdminUseCase registerCompanyAndAdminUseCase;
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final RequestPasswordResetOtpUseCase requestPasswordResetOtpUseCase;
  final VerifyOtpAndResetPasswordUseCase verifyOtpAndResetPasswordUseCase;
  final CreateGestionnaireAccountUseCase createGestionnaireAccountUseCase;
  final UpdateAccountStatusUseCase updateAccountStatusUseCase;
  final DeleteGestionnaireAccountUseCase deleteGestionnaireAccountUseCase;
  final GetUserProfileByIdUseCase getUserProfileByIdUseCase;
  final ListUserProfilesByCompanyUseCase listUserProfilesByCompanyUseCase;
  final SearchUserProfilesUseCase searchUserProfilesUseCase;
  final WatchUserProfilesUseCase watchUserProfilesUseCase;

  StreamSubscription<UserProfileRealtimeEvent>? _realtimeSubscription;

  AuthBloc({
    required this.registerCompanyAndAdminUseCase,
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.getCurrentUserUseCase,
    required this.requestPasswordResetOtpUseCase,
    required this.verifyOtpAndResetPasswordUseCase,
    required this.createGestionnaireAccountUseCase,
    required this.updateAccountStatusUseCase,
    required this.deleteGestionnaireAccountUseCase,
    required this.getUserProfileByIdUseCase,
    required this.listUserProfilesByCompanyUseCase,
    required this.searchUserProfilesUseCase,
    required this.watchUserProfilesUseCase,
  }) : super(const AuthState.initial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthRegisterCompanyRequested>(_onRegisterCompanyRequested);
    on<AuthPasswordResetOtpRequested>(_onPasswordResetOtpRequested);
    on<AuthOtpVerifyAndResetPasswordRequested>(_onOtpVerifyAndResetPasswordRequested);
    on<AuthCreateGestionnaireRequested>(_onCreateGestionnaireRequested);
    on<AuthUpdateAccountStatusRequested>(_onUpdateAccountStatusRequested);
    on<AuthDeleteGestionnaireRequested>(_onDeleteGestionnaireRequested);
    on<AuthCompanyUsersLoadRequested>(_onCompanyUsersLoadRequested);
    on<AuthCompanyUsersSearchRequested>(_onCompanyUsersSearchRequested);
    on<AuthCompanyUsersWatchStarted>(_onCompanyUsersWatchStarted);
    on<AuthCompanyUsersWatchStopped>(_onCompanyUsersWatchStopped);
    on<AuthLastCreatedGestionnaireTempPasswordAcknowledged>(
      _onLastCreatedGestionnaireTempPasswordAcknowledged,
    );
    on<_AuthCompanyUsersRealtimeEventReceived>(_onRealtimeEventReceived);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    // If HydratedBloc already restored a cached authenticated user, keep
    // showing that optimistically instead of flashing the splash screen -
    // this call still silently revalidates against Appwrite below and
    // will correct to `unauthenticated` if the session turned out to be
    // invalid/expired.
    if (state.currentUser == null) {
      emit(state.copyWith(status: AuthStatus.loading));
    }
    final result = await getCurrentUserUseCase(const NoParams());
    result.fold(
      (exception) => emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearCurrentUser: true,
        ),
      ),
      (user) => emit(state.copyWith(status: AuthStatus.authenticated, currentUser: user)),
    );
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    final identifierValid = _Regex.email.hasMatch(event.identifier) ||
        _Regex.phone.hasMatch(event.identifier);
    if (!identifierValid) {
      emit(state.copyWith(
        status: AuthStatus.error,
        failure: const Failure(
          title: 'Erreur de validation',
          message: 'Entrez un email ou un numero de telephone valide.',
        ),
      ));
      return;
    }
    if (event.password.isEmpty) {
      emit(state.copyWith(
        status: AuthStatus.error,
        failure: const Failure(
          title: 'Erreur de validation',
          message: 'Le mot de passe est requis.',
        ),
      ));
      return;
    }

    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    final result = await loginUseCase(
      LoginParams(identifier: event.identifier, password: event.password),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        status: AuthStatus.error,
        failure: Failure.fromException(exception),
      )),
      (user) => emit(state.copyWith(status: AuthStatus.authenticated, currentUser: user)),
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;

    final result = await logoutUseCase(const NoParams());
    result.fold(
      (exception) => emit(state.copyWith(
        status: AuthStatus.error,
        failure: Failure.fromException(exception),
      )),
      (_) => emit(const AuthState(status: AuthStatus.unauthenticated)),
    );
  }

  Future<void> _onRegisterCompanyRequested(
    AuthRegisterCompanyRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!_Regex.email.hasMatch(event.adminEmail) ||
        !_Regex.email.hasMatch(event.companyContactEmail)) {
      emit(state.copyWith(
        status: AuthStatus.error,
        failure: const Failure(title: 'Erreur de validation', message: 'Email invalide.'),
      ));
      return;
    }
    if (!_Regex.phone.hasMatch(event.adminPhone) ||
        !_Regex.phone.hasMatch(event.companyContactPhone)) {
      emit(state.copyWith(
        status: AuthStatus.error,
        failure: const Failure(
          title: 'Erreur de validation',
          message: 'Numero de telephone invalide.',
        ),
      ));
      return;
    }
    if (event.password.length < 8) {
      emit(state.copyWith(
        status: AuthStatus.error,
        failure: const Failure(
          title: 'Erreur de validation',
          message: 'Le mot de passe doit contenir au moins 8 caracteres.',
        ),
      ));
      return;
    }

    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    final result = await registerCompanyAndAdminUseCase(
      RegisterCompanyAndAdminParams(
        companyName: event.companyName,
        companyAddress: event.companyAddress,
        companyContactEmail: event.companyContactEmail,
        companyContactPhone: event.companyContactPhone,
        adminFullName: event.adminFullName,
        adminEmail: event.adminEmail,
        adminPhone: event.adminPhone,
        password: event.password,
      ),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        status: AuthStatus.error,
        failure: Failure.fromException(exception),
      )),
      (user) => emit(state.copyWith(status: AuthStatus.authenticated, currentUser: user)),
    );
  }

  Future<void> _onPasswordResetOtpRequested(
    AuthPasswordResetOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    final identifierValid = _Regex.email.hasMatch(event.identifier) ||
        _Regex.phone.hasMatch(event.identifier);
    if (!identifierValid) {
      emit(state.copyWith(
        status: AuthStatus.error,
        failure: const Failure(
          title: 'Erreur de validation',
          message: 'Entrez un email ou un numero de telephone valide.',
        ),
      ));
      return;
    }

    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    final result = await requestPasswordResetOtpUseCase(
      RequestOtpParams(identifier: event.identifier),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        status: AuthStatus.error,
        failure: Failure.fromException(exception),
      )),
      (challenge) => emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        otpChallenge: challenge,
      )),
    );
  }

  Future<void> _onOtpVerifyAndResetPasswordRequested(
    AuthOtpVerifyAndResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (event.newPassword.length < 8) {
      emit(state.copyWith(
        status: AuthStatus.error,
        failure: const Failure(
          title: 'Erreur de validation',
          message: 'Le mot de passe doit contenir au moins 8 caracteres.',
        ),
      ));
      return;
    }

    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    final result = await verifyOtpAndResetPasswordUseCase(
      VerifyOtpParams(
        userId: event.userId,
        otp: event.otp,
        newPassword: event.newPassword,
      ),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        status: AuthStatus.error,
        failure: Failure.fromException(exception),
      )),
      (_) => emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        clearOtpChallenge: true,
      )),
    );
  }

  Future<void> _onCreateGestionnaireRequested(
    AuthCreateGestionnaireRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!_Regex.email.hasMatch(event.email) || !_Regex.phone.hasMatch(event.phone)) {
      emit(state.copyWith(
        status: AuthStatus.error,
        failure: const Failure(
          title: 'Erreur de validation',
          message: 'Email ou numero de telephone invalide.',
        ),
      ));
      return;
    }

    final result = await createGestionnaireAccountUseCase(
      CreateGestionnaireParams(
        fullName: event.fullName,
        email: event.email,
        phone: event.phone,
      ),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        companyUsersStatus: CompanyUsersStatus.error,
        companyUsersFailure: Failure.fromException(exception),
      )),
      (created) => emit(state.copyWith(
        companyUsersStatus: CompanyUsersStatus.loaded,
        companyUsers: [created.profile, ...state.companyUsers],
        lastCreatedGestionnaireTempPassword: created.tempPassword,
      )),
    );
  }

  Future<void> _onUpdateAccountStatusRequested(
    AuthUpdateAccountStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await updateAccountStatusUseCase(
      UpdateAccountStatusParams(userId: event.userId, status: event.status),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        companyUsersStatus: CompanyUsersStatus.error,
        companyUsersFailure: Failure.fromException(exception),
      )),
      (updated) => emit(state.copyWith(
        companyUsersStatus: CompanyUsersStatus.loaded,
        companyUsers: [
          for (final u in state.companyUsers) if (u.id == updated.id) updated else u,
        ],
      )),
    );
  }

  Future<void> _onDeleteGestionnaireRequested(
    AuthDeleteGestionnaireRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await deleteGestionnaireAccountUseCase(
      DeleteGestionnaireParams(userId: event.userId),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        companyUsersStatus: CompanyUsersStatus.error,
        companyUsersFailure: Failure.fromException(exception),
      )),
      (_) => emit(state.copyWith(
        companyUsersStatus: CompanyUsersStatus.loaded,
        companyUsers: state.companyUsers.where((u) => u.id != event.userId).toList(),
      )),
    );
  }

  Future<void> _onCompanyUsersLoadRequested(
    AuthCompanyUsersLoadRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      companyUsersStatus: CompanyUsersStatus.loading,
      clearCompanyUsersFailure: true,
    ));
    final result = await listUserProfilesByCompanyUseCase(
      ListUserProfilesParams(companyId: event.companyId),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        companyUsersStatus: CompanyUsersStatus.error,
        companyUsersFailure: Failure.fromException(exception),
      )),
      (users) => emit(state.copyWith(
        companyUsersStatus: CompanyUsersStatus.loaded,
        companyUsers: users,
      )),
    );
  }

  Future<void> _onCompanyUsersSearchRequested(
    AuthCompanyUsersSearchRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      companyUsersStatus: CompanyUsersStatus.loading,
      clearCompanyUsersFailure: true,
    ));
    final result = await searchUserProfilesUseCase(
      SearchUserProfilesParams(companyId: event.companyId, query: event.query),
    );
    result.fold(
      (exception) => emit(state.copyWith(
        companyUsersStatus: CompanyUsersStatus.error,
        companyUsersFailure: Failure.fromException(exception),
      )),
      (users) => emit(state.copyWith(
        companyUsersStatus: CompanyUsersStatus.loaded,
        companyUsers: users,
      )),
    );
  }

  Future<void> _onCompanyUsersWatchStarted(
    AuthCompanyUsersWatchStarted event,
    Emitter<AuthState> emit,
  ) async {
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = watchUserProfilesUseCase(event.companyId).listen(
      (realtimeEvent) => add(_AuthCompanyUsersRealtimeEventReceived(realtimeEvent)),
    );
  }

  Future<void> _onCompanyUsersWatchStopped(
    AuthCompanyUsersWatchStopped event,
    Emitter<AuthState> emit,
  ) async {
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  void _onLastCreatedGestionnaireTempPasswordAcknowledged(
    AuthLastCreatedGestionnaireTempPasswordAcknowledged event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(clearLastCreatedGestionnaireTempPassword: true));
  }

  void _onRealtimeEventReceived(
    _AuthCompanyUsersRealtimeEventReceived event,
    Emitter<AuthState> emit,
  ) {
    final profile = event.event.profile;
    switch (event.event.type) {
      case UserProfileEventType.created:
        if (state.companyUsers.any((u) => u.id == profile.id)) return;
        emit(state.copyWith(companyUsers: [profile, ...state.companyUsers]));
        break;
      case UserProfileEventType.updated:
        emit(state.copyWith(companyUsers: [
          for (final u in state.companyUsers) if (u.id == profile.id) profile else u,
        ]));
        break;
      case UserProfileEventType.deleted:
        emit(state.copyWith(
          companyUsers: state.companyUsers.where((u) => u.id != profile.id).toList(),
        ));
        break;
    }
  }

  @override
  Future<void> close() {
    _realtimeSubscription?.cancel();
    return super.close();
  }

  @override
  AuthState? fromJson(Map<String, dynamic> json) => AuthState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(AuthState state) => state.toJson();
}
