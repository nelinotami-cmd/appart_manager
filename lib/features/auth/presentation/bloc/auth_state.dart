import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/account_status.dart';
import '../../domain/entities/otp_challenge.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_role.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// Separate, secondary status for the company-users list section of the
/// screen (Admin managing Gestionnaires), so a list refresh never clobbers
/// the primary authentication status/UI.
enum CompanyUsersStatus { initial, loading, loaded, error }

class AuthState extends Equatable {
  final AuthStatus status;
  final UserProfile? currentUser;
  final Failure? failure;

  /// Set after [AuthPasswordResetOtpRequested] succeeds; consumed by the
  /// OTP-verification page.
  final OtpChallenge? otpChallenge;

  final CompanyUsersStatus companyUsersStatus;
  final List<UserProfile> companyUsers;
  final Failure? companyUsersFailure;

  /// Set once, right after `AuthCreateGestionnaireRequested` succeeds -
  /// the one-time temp password the Admin must relay to the new
  /// Gestionnaire. The UI must explicitly clear this (via
  /// `clearLastCreatedGestionnaireTempPassword`) once it has been shown,
  /// and it is intentionally excluded from [toJson] - see the note above
  /// [toJson] for why nothing but the authenticated user survives a
  /// restart.
  final String? lastCreatedGestionnaireTempPassword;

  const AuthState({
    this.status = AuthStatus.initial,
    this.currentUser,
    this.failure,
    this.otpChallenge,
    this.companyUsersStatus = CompanyUsersStatus.initial,
    this.companyUsers = const [],
    this.companyUsersFailure,
    this.lastCreatedGestionnaireTempPassword,
  });

  const AuthState.initial() : this();

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? currentUser,
    bool clearCurrentUser = false,
    Failure? failure,
    bool clearFailure = false,
    OtpChallenge? otpChallenge,
    bool clearOtpChallenge = false,
    CompanyUsersStatus? companyUsersStatus,
    List<UserProfile>? companyUsers,
    Failure? companyUsersFailure,
    bool clearCompanyUsersFailure = false,
    String? lastCreatedGestionnaireTempPassword,
    bool clearLastCreatedGestionnaireTempPassword = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      currentUser: clearCurrentUser ? null : (currentUser ?? this.currentUser),
      failure: clearFailure ? null : (failure ?? this.failure),
      otpChallenge: clearOtpChallenge ? null : (otpChallenge ?? this.otpChallenge),
      companyUsersStatus: companyUsersStatus ?? this.companyUsersStatus,
      companyUsers: companyUsers ?? this.companyUsers,
      companyUsersFailure:
          clearCompanyUsersFailure ? null : (companyUsersFailure ?? this.companyUsersFailure),
      lastCreatedGestionnaireTempPassword: clearLastCreatedGestionnaireTempPassword
          ? null
          : (lastCreatedGestionnaireTempPassword ?? this.lastCreatedGestionnaireTempPassword),
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated && currentUser != null;

  @override
  List<Object?> get props => [
        status,
        currentUser,
        failure,
        otpChallenge,
        companyUsersStatus,
        companyUsers,
        companyUsersFailure,
        lastCreatedGestionnaireTempPassword,
      ];

  // ---- HydratedBloc (de)serialization --------------------------------------
  //
  // Only the minimal "is someone logged in, and who" slice is persisted,
  // to give an instant splash-screen decision on cold start while
  // AuthCheckRequested re-validates the session against Appwrite in the
  // background. Lists/failures/OTP challenges are intentionally NOT
  // persisted (transient, and companyUsers may contain stale/sensitive
  // data across app restarts).

  Map<String, dynamic>? toJson() {
    if (currentUser == null || status != AuthStatus.authenticated) return null;
    final user = currentUser!;
    return {
      'id': user.id,
      'fullName': user.fullName,
      'email': user.email,
      'phone': user.phone,
      'role': user.role.value,
      'companyId': user.companyId,
      'status': user.status.value,
      'createdBy': user.createdBy,
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': user.updatedAt.toIso8601String(),
    };
  }

  static AuthState fromJson(Map<String, dynamic> json) {
    final user = UserProfile(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: UserRoleX.fromValue(json['role'] as String),
      companyId: json['companyId'] as String?,
      status: AccountStatusX.fromValue(json['status'] as String),
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
    return AuthState(status: AuthStatus.authenticated, currentUser: user);
  }
}
