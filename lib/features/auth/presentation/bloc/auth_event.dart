import 'package:equatable/equatable.dart';

import '../../domain/entities/account_status.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched once at app startup to check for an existing session.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLoginRequested extends AuthEvent {
  final String identifier;
  final String password;

  const AuthLoginRequested({required this.identifier, required this.password});

  @override
  List<Object?> get props => [identifier, password];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthRegisterCompanyRequested extends AuthEvent {
  final String companyName;
  final String companyAddress;
  final String companyContactEmail;
  final String companyContactPhone;
  final String adminFullName;
  final String adminEmail;
  final String adminPhone;
  final String password;

  const AuthRegisterCompanyRequested({
    required this.companyName,
    required this.companyAddress,
    required this.companyContactEmail,
    required this.companyContactPhone,
    required this.adminFullName,
    required this.adminEmail,
    required this.adminPhone,
    required this.password,
  });

  @override
  List<Object?> get props => [
        companyName,
        companyAddress,
        companyContactEmail,
        companyContactPhone,
        adminFullName,
        adminEmail,
        adminPhone,
        password,
      ];
}

class AuthPasswordResetOtpRequested extends AuthEvent {
  final String identifier;

  const AuthPasswordResetOtpRequested({required this.identifier});

  @override
  List<Object?> get props => [identifier];
}

class AuthOtpVerifyAndResetPasswordRequested extends AuthEvent {
  final String userId;
  final String otp;
  final String newPassword;

  const AuthOtpVerifyAndResetPasswordRequested({
    required this.userId,
    required this.otp,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [userId, otp, newPassword];
}

class AuthCreateGestionnaireRequested extends AuthEvent {
  final String fullName;
  final String email;
  final String phone;

  const AuthCreateGestionnaireRequested({
    required this.fullName,
    required this.email,
    required this.phone,
  });

  @override
  List<Object?> get props => [fullName, email, phone];
}

class AuthUpdateAccountStatusRequested extends AuthEvent {
  final String userId;
  final AccountStatus status;

  const AuthUpdateAccountStatusRequested({required this.userId, required this.status});

  @override
  List<Object?> get props => [userId, status];
}

class AuthDeleteGestionnaireRequested extends AuthEvent {
  final String userId;

  const AuthDeleteGestionnaireRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class AuthCompanyUsersLoadRequested extends AuthEvent {
  final String companyId;

  const AuthCompanyUsersLoadRequested({required this.companyId});

  @override
  List<Object?> get props => [companyId];
}

class AuthCompanyUsersSearchRequested extends AuthEvent {
  final String companyId;
  final String query;

  const AuthCompanyUsersSearchRequested({required this.companyId, required this.query});

  @override
  List<Object?> get props => [companyId, query];
}

/// Starts (or restarts) the realtime subscription for a company's
/// `user_profiles`. Internally the Bloc converts each subscription event
/// into [_AuthCompanyUsersRealtimeEventReceived].
class AuthCompanyUsersWatchStarted extends AuthEvent {
  final String companyId;

  const AuthCompanyUsersWatchStarted({required this.companyId});

  @override
  List<Object?> get props => [companyId];
}

class AuthCompanyUsersWatchStopped extends AuthEvent {
  const AuthCompanyUsersWatchStopped();
}

/// Dispatched once the Admin has seen/copied
/// `AuthState.lastCreatedGestionnaireTempPassword`, so it doesn't linger
/// in memory (or reappear) after the confirmation screen is dismissed.
class AuthLastCreatedGestionnaireTempPasswordAcknowledged extends AuthEvent {
  const AuthLastCreatedGestionnaireTempPasswordAcknowledged();
}
