import 'package:equatable/equatable.dart';

import 'user_profile.dart';

enum UserProfileEventType { created, updated, deleted }

/// Emitted by [AuthRepository.watchUserProfiles] realtime stream.
class UserProfileRealtimeEvent extends Equatable {
  final UserProfileEventType type;
  final UserProfile profile;

  const UserProfileRealtimeEvent({required this.type, required this.profile});

  @override
  List<Object?> get props => [type, profile];
}
