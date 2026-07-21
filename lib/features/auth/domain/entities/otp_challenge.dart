import 'package:equatable/equatable.dart';

/// Returned by [AuthRepository.requestPasswordResetOtp]. [userId] must be
/// supplied back (together with the code the user received) to
/// [AuthRepository.verifyOtpAndResetPassword].
class OtpChallenge extends Equatable {
  final String userId;

  /// 'email' or 'phone' - which channel the OTP code was sent through.
  final String channel;

  const OtpChallenge({required this.userId, required this.channel});

  @override
  List<Object?> get props => [userId, channel];
}
