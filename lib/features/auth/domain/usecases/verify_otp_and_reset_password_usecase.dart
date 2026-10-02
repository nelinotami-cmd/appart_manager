import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpAndResetPasswordUseCase implements UseCase<void, VerifyOtpParams> {
  final AuthRepository repository;

  const VerifyOtpAndResetPasswordUseCase(this.repository);

  @override
  FutureEither<void> call(VerifyOtpParams params) =>
      repository.verifyOtpAndResetPassword(params);
}
