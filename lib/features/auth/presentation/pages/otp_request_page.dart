import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_shell.dart';

/// Matches the reference `password_recovery_screen` mockup: "Reset
/// Password" heading, single Email-or-Phone field, "Send Recovery Code"
/// button, "Back to Login" link.
class OtpRequestPage extends StatefulWidget {
  static const routeName = '/password-reset/request';

  const OtpRequestPage({super.key});

  @override
  State<OtpRequestPage> createState() => _OtpRequestPageState();
}

class _OtpRequestPageState extends State<OtpRequestPage> {
  final _identifierController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<AuthBloc>().add(
          AuthPasswordResetOtpRequested(identifier: _identifierController.text.trim()),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous.otpChallenge != current.otpChallenge,
      listener: (context, state) {
        if (state.otpChallenge != null) {
          final identifier = _identifierController.text.trim();
          context.pushReplacement(
            Uri(
              path: AppRoutes.passwordResetVerify,
              queryParameters: {'identifier': identifier},
            ).toString(),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state.status == AuthStatus.loading;
        return AuthShell(
          footer: Center(
            child: TextButton.icon(
              onPressed: isLoading ? null : () => context.pop(),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Retour a la connexion'),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Reinitialiser le mot de passe', style: AppTextStyles.headlineMd),
              const SizedBox(height: 4),
              Text(
                'Entrez votre email ou numero de telephone, nous vous '
                'enverrons un code a 6 chiffres.',
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.status == AuthStatus.error && state.failure != null)
                AuthInlineAlert(message: state.failure!.message),
              AppTextField(
                label: 'Email ou numero de telephone',
                hint: 'nom@entreprise.com',
                controller: _identifierController,
                prefixIcon: Icons.alternate_email,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: 'Envoyer le code',
                isLoading: isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        );
      },
    );
  }
}
