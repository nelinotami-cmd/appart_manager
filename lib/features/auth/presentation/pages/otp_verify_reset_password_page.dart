import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_shell.dart';
import '../widgets/otp_code_input.dart';

/// Matches the reference `verify_account_screen` mockup, extended with
/// new-password fields since `verifyOtpAndResetPassword` needs the OTP
/// code AND the new password in a single call.
class OtpVerifyResetPasswordPage extends StatefulWidget {
  static const routeName = '/password-reset/verify';

  /// Email or phone the OTP was requested for - display only, passed as
  /// a query parameter (`?identifier=...`) by the router since it comes
  /// from `OtpRequestPage`'s own text field, not from `AuthState`.
  final String identifier;

  const OtpVerifyResetPasswordPage({super.key, required this.identifier});

  @override
  State<OtpVerifyResetPasswordPage> createState() => _OtpVerifyResetPasswordPageState();
}

class _OtpVerifyResetPasswordPageState extends State<OtpVerifyResetPasswordPage> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _otp = '';
  String? _localError;
  bool _submitted = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _resend() {
    context.read<AuthBloc>().add(AuthPasswordResetOtpRequested(identifier: widget.identifier));
  }

  void _submit(String userId) {
    if (_otp.length != 6) {
      setState(() => _localError = 'Entrez les 6 chiffres du code.');
      return;
    }
    if (_newPasswordController.text.length < 8) {
      setState(() => _localError = 'Le mot de passe doit contenir au moins 8 caracteres.');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _localError = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() => _localError = null);
    _submitted = true;
    context.read<AuthBloc>().add(
          AuthOtpVerifyAndResetPasswordRequested(
            userId: userId,
            otp: _otp,
            newPassword: _newPasswordController.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) => _submitted && previous.status != current.status,
      listener: (context, state) {
        if (!_submitted) return;
        if (state.status == AuthStatus.unauthenticated && state.failure == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mot de passe reinitialise. Connectez-vous.')),
          );
          context.go(AppRoutes.login);
        } else if (state.status == AuthStatus.error) {
          _submitted = false;
        }
      },
      builder: (context, state) {
        final isLoading = state.status == AuthStatus.loading;
        final userId = state.otpChallenge?.userId;

        return AuthShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primaryContainer,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Verifiez votre compte',
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineMd,
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: AppTextStyles.bodySm,
                  children: [
                    const TextSpan(text: 'Nous avons envoye un code a 6 chiffres a '),
                    TextSpan(
                      text: widget.identifier,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: '. Entrez-le ci-dessous.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_localError != null)
                AuthInlineAlert(message: _localError!)
              else if (state.status == AuthStatus.error && state.failure != null)
                AuthInlineAlert(message: state.failure!.message),
              OtpCodeInput(
                hasError: _localError != null || state.status == AuthStatus.error,
                onChanged: (value) => setState(() => _otp = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: isLoading ? null : _resend,
                  child: const Text("Vous n'avez pas recu le code ? Renvoyer"),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              Text('Nouveau mot de passe', style: AppTextStyles.labelMd),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Nouveau mot de passe',
                hint: 'Min. 8 caracteres',
                controller: _newPasswordController,
                obscureText: true,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Confirmer le mot de passe',
                hint: 'Retapez le mot de passe',
                controller: _confirmPasswordController,
                obscureText: true,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: 'Reinitialiser le mot de passe',
                isLoading: isLoading,
                onPressed: userId == null ? null : () => _submit(userId),
                trailingIcon: null,
              ),
              if (userId == null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "Session de reinitialisation expiree - redemandez un code.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.error),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
