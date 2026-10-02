import 'package:equatable/equatable.dart';

import 'user_profile.dart';

/// Result of [AuthRepository.createGestionnaireAccount].
///
/// Deliberately NOT a field on [UserProfile] itself: [UserProfile] is the
/// persisted/hydrated entity (see `AuthState.toJson`), and a one-time
/// secret has no business being carried around in equality checks or
/// (even transiently) in anything that could be serialized. This wrapper
/// exists purely so the Cloud Function's one-time `tempPassword` value
/// (see `functions/api/src/main.py`, `auth.create-gestionnaire-account`)
/// reaches the UI at all - without it, the generated credential the
/// Gestionnaire actually needs to log in would be silently discarded by
/// `UserProfileMapper` (which only ever reads fields that belong to
/// [UserProfile]).
class GestionnaireCreationResult extends Equatable {
  final UserProfile profile;
  final String tempPassword;

  const GestionnaireCreationResult({
    required this.profile,
    required this.tempPassword,
  });

  @override
  List<Object?> get props => [profile, tempPassword];
}
