import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

/// Params is a plain [String] (the user id) - no dedicated Params class
/// needed for a single-field input.
class GetUserProfileByIdUseCase implements UseCase<UserProfile, String> {
  final AuthRepository repository;

  const GetUserProfileByIdUseCase(this.repository);

  @override
  FutureEither<UserProfile> call(String userId) =>
      repository.getUserProfileById(userId);
}
