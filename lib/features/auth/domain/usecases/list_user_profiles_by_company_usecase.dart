import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

class ListUserProfilesByCompanyUseCase
    implements UseCase<List<UserProfile>, ListUserProfilesParams> {
  final AuthRepository repository;

  const ListUserProfilesByCompanyUseCase(this.repository);

  @override
  FutureEither<List<UserProfile>> call(ListUserProfilesParams params) =>
      repository.listUserProfilesByCompany(params);
}
