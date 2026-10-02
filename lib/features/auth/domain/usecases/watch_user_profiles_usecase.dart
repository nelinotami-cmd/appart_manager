import '../entities/user_profile_realtime_event.dart';
import '../repositories/auth_repository.dart';

/// Realtime use cases return a [Stream] directly rather than a
/// [FutureEither] - there is no single terminal result to await, and
/// stream-level errors are handled by the Bloc's subscription.
class WatchUserProfilesUseCase {
  final AuthRepository repository;

  const WatchUserProfilesUseCase(this.repository);

  Stream<UserProfileRealtimeEvent> call(String companyId) =>
      repository.watchUserProfiles(companyId);
}
