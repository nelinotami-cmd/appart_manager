import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

class RegisterCompanyAndAdminUseCase
    implements UseCase<UserProfile, RegisterCompanyAndAdminParams> {
  final AuthRepository repository;

  const RegisterCompanyAndAdminUseCase(this.repository);

  @override
  FutureEither<UserProfile> call(RegisterCompanyAndAdminParams params) =>
      repository.registerCompanyAndAdmin(params);
}
