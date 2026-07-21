import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

class SearchUserProfilesUseCase
    implements UseCase<List<UserProfile>, SearchUserProfilesParams> {
  final AuthRepository repository;

  const SearchUserProfilesUseCase(this.repository);

  @override
  FutureEither<List<UserProfile>> call(SearchUserProfilesParams params) =>
      repository.searchUserProfiles(params);
}
