import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/no_params.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUserUseCase implements UseCase<UserProfile, NoParams> {
  final AuthRepository repository;

  const GetCurrentUserUseCase(this.repository);

  @override
  FutureEither<UserProfile> call(NoParams params) => repository.getCurrentUser();
}
