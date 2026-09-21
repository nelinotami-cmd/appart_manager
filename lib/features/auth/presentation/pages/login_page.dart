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

/// Matches the reference `login_screen` mockup: brand mark, "Email or
/// Phone" + "Password" fields, primary Login button, "Forgot password?"
/// and "Don't have an account?" links.
///
/// The mockup also shows "OR CONTINUING WITH / Microsoft / Okta" SSO
/// buttons - omitted here since cahier des charges 5.1 specifies
/// email/phone + password + OTP only, no OAuth/SSO provider.
///
/// Navigation is go_router-based: on successful login, `AuthBloc`
/// emitting `authenticated` fires the router's `refreshListenable`, and
/// its `redirect` callback sends us to `/dashboard` on its own - this
/// page does not navigate on success itself, only on the two explicit
/// links below.
class LoginPage extends StatefulWidget {
  static const routeName = '/login';

  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<AuthBloc>().add(
          AuthLoginRequested(
            identifier: _identifierController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state.status == AuthStatus.loading;
        return AuthShell(
          footer: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                Text("Pas encore de compte ? ", style: AppTextStyles.bodySm),
                GestureDetector(
                  onTap: isLoading ? null : () => context.push(AppRoutes.registerCompany),
                  child: Text(
                    'Inscrire mon entreprise',
                    style: AppTextStyles.bodySm.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Connexion', style: AppTextStyles.headlineMd),
              const SizedBox(height: 4),
              Text(
                'Accedez a votre espace de gestion.',
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.status == AuthStatus.error && state.failure != null)
                AuthInlineAlert(message: state.failure!.message),
              AppTextField(
                label: 'Email ou telephone',
                hint: 'nom@entreprise.com',
                controller: _identifierController,
                prefixIcon: Icons.person_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mot de passe', style: AppTextStyles.labelMd),
                  GestureDetector(
                    onTap: isLoading
                        ? null
                        : () => context.push(AppRoutes.passwordResetRequest),
                    child: Text(
                      'Mot de passe oublie ?',
                      style: AppTextStyles.bodySm.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AppTextField(
                hint: '••••••••',
                controller: _passwordController,
                obscureText: true,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: 'Se connecter',
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
