import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase implements UseCase<UserProfile, LoginParams> {
  final AuthRepository repository;

  const LoginUseCase(this.repository);

  @override
  FutureEither<UserProfile> call(LoginParams params) => repository.login(params);
}
