import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/otp_challenge.dart';
import '../repositories/auth_repository.dart';

class RequestPasswordResetOtpUseCase
    implements UseCase<OtpChallenge, RequestOtpParams> {
  final AuthRepository repository;

  const RequestPasswordResetOtpUseCase(this.repository);

  @override
  FutureEither<OtpChallenge> call(RequestOtpParams params) =>
      repository.requestPasswordResetOtp(params);
}
