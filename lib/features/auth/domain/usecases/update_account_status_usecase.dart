import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

class UpdateAccountStatusUseCase
    implements UseCase<UserProfile, UpdateAccountStatusParams> {
  final AuthRepository repository;

  const UpdateAccountStatusUseCase(this.repository);

  @override
  FutureEither<UserProfile> call(UpdateAccountStatusParams params) =>
      repository.updateAccountStatus(params);
}
