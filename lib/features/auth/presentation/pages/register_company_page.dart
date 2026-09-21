import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_shell.dart';

enum _RegisterStep { company, admin, security }

/// 3-step wizard (Company/Admin/Security). The backend's
/// `registerCompanyAndAdmin` use case is a single atomic call, so this
/// stays a local, client-side wizard that only dispatches to `AuthBloc`
/// on the final step.
///
/// Navigation is go_router-based: on successful registration, `AuthBloc`
/// emitting `authenticated` fires the router's `redirect`, sending us to
/// `/dashboard` automatically - this page doesn't navigate on success
/// itself. "Deja un compte ?" pops back to wherever this was pushed from
/// (normally `/login`).
class RegisterCompanyPage extends StatefulWidget {
  static const routeName = '/register-company';

  const RegisterCompanyPage({super.key});

  @override
  State<RegisterCompanyPage> createState() => _RegisterCompanyPageState();
}

class _RegisterCompanyPageState extends State<RegisterCompanyPage> {
  _RegisterStep _step = _RegisterStep.company;
  String? _localError;

  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyPhoneController = TextEditingController();

  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPhoneController = TextEditingController();

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _companyEmailController.dispose();
    _companyPhoneController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goNext() {
    setState(() => _localError = null);
    switch (_step) {
      case _RegisterStep.company:
        if (_companyNameController.text.trim().isEmpty ||
            _companyAddressController.text.trim().isEmpty ||
            _companyEmailController.text.trim().isEmpty ||
            _companyPhoneController.text.trim().isEmpty) {
          setState(() => _localError = 'Tous les champs sont requis.');
          return;
        }
        setState(() => _step = _RegisterStep.admin);
        break;
      case _RegisterStep.admin:
        if (_adminNameController.text.trim().isEmpty ||
            _adminEmailController.text.trim().isEmpty ||
            _adminPhoneController.text.trim().isEmpty) {
          setState(() => _localError = 'Tous les champs sont requis.');
          return;
        }
        setState(() => _step = _RegisterStep.security);
        break;
      case _RegisterStep.security:
        _submit();
        break;
    }
  }

  void _goBack() {
    setState(() {
      _localError = null;
      _step = switch (_step) {
        _RegisterStep.company => _RegisterStep.company,
        _RegisterStep.admin => _RegisterStep.company,
        _RegisterStep.security => _RegisterStep.admin,
      };
    });
  }

  void _submit() {
    if (_passwordController.text.length < 8) {
      setState(() => _localError = 'Le mot de passe doit contenir au moins 8 caracteres.');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _localError = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() => _localError = null);
    context.read<AuthBloc>().add(
          AuthRegisterCompanyRequested(
            companyName: _companyNameController.text.trim(),
            companyAddress: _companyAddressController.text.trim(),
            companyContactEmail: _companyEmailController.text.trim(),
            companyContactPhone: _companyPhoneController.text.trim(),
            adminFullName: _adminNameController.text.trim(),
            adminEmail: _adminEmailController.text.trim(),
            adminPhone: _adminPhoneController.text.trim(),
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
          maxWidth: 520,
          footer: Center(
            child: TextButton(
              onPressed: isLoading ? null : () => context.pop(),
              child: const Text('Deja un compte ? Se connecter'),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RegisterStepper(current: _step),
              const SizedBox(height: AppSpacing.lg),
              _buildStepHeading(),
              const SizedBox(height: AppSpacing.lg),
              if (_localError != null)
                AuthInlineAlert(message: _localError!)
              else if (state.status == AuthStatus.error && state.failure != null)
                AuthInlineAlert(message: state.failure!.message),
              _buildStepFields(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  if (_step != _RegisterStep.company) ...[
                    Expanded(
                      child: AppSecondaryButton(
                        label: 'Retour',
                        onPressed: isLoading ? null : _goBack,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    flex: 2,
                    child: AppPrimaryButton(
                      label: _step == _RegisterStep.security ? 'Creer le compte' : 'Suivant',
                      isLoading: isLoading,
                      onPressed: _goNext,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepHeading() {
    final (title, subtitle) = switch (_step) {
      _RegisterStep.company => (
          "Inscrire l'entreprise",
          "Commencons par les informations principales de l'entreprise.",
        ),
      _RegisterStep.admin => (
          'Compte Administrateur',
          'Vos informations en tant qu\'Admin de cette entreprise.',
        ),
      _RegisterStep.security => (
          'Securite du compte',
          'Choisissez un mot de passe pour vous connecter.',
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.headlineMd),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTextStyles.bodySm),
      ],
    );
  }

  Widget _buildStepFields() {
    switch (_step) {
      case _RegisterStep.company:
        return Column(
          children: [
            AppTextField(
              label: "Nom de l'entreprise",
              hint: 'Ex. Residences Biyem-Assi SARL',
              controller: _companyNameController,
              prefixIcon: Icons.apartment_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Adresse',
              hint: 'Ex. Rue 1.234, Biyem-Assi, Yaounde',
              controller: _companyAddressController,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Email de contact',
              hint: 'contact@entreprise.com',
              controller: _companyEmailController,
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Telephone de contact',
              hint: '+237 6XX XXX XXX',
              controller: _companyPhoneController,
              prefixIcon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
            ),
          ],
        );
      case _RegisterStep.admin:
        return Column(
          children: [
            AppTextField(
              label: 'Nom complet',
              hint: 'Ex. Jean Dupont',
              controller: _adminNameController,
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Email professionnel',
              hint: 'jean@entreprise.com',
              controller: _adminEmailController,
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Numero de telephone',
              hint: '+237 6XX XXX XXX',
              controller: _adminPhoneController,
              prefixIcon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
            ),
          ],
        );
      case _RegisterStep.security:
        return Column(
          children: [
            AppTextField(
              label: 'Mot de passe',
              hint: 'Min. 8 caracteres',
              controller: _passwordController,
              obscureText: true,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Confirmer le mot de passe',
              hint: 'Retapez le mot de passe',
              controller: _confirmPasswordController,
              obscureText: true,
            ),
          ],
        );
    }
  }
}

/// Horizontal 3-circle stepper (`DESIGN.md` "Steppers" spec): completed
/// steps solid primary with a checkmark, the active step outlined
/// primary, future steps neutral gray.
class _RegisterStepper extends StatelessWidget {
  final _RegisterStep current;

  const _RegisterStepper({required this.current});

  @override
  Widget build(BuildContext context) {
    const steps = [
      (_RegisterStep.company, Icons.apartment_outlined, 'ENTREPRISE'),
      (_RegisterStep.admin, Icons.person_outline, 'ADMIN'),
      (_RegisterStep.security, Icons.shield_outlined, 'SECURITE'),
    ];

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _StepCircle(
            icon: steps[i].$2,
            label: steps[i].$3,
            state: _stateFor(steps[i].$1),
          ),
          if (i != steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 20),
                color: _stateFor(steps[i].$1) == _StepState.done
                    ? AppColors.primaryContainer
                    : AppColors.outlineVariant,
              ),
            ),
        ],
      ],
    );
  }

  _StepState _stateFor(_RegisterStep step) {
    if (step.index < current.index) return _StepState.done;
    if (step.index == current.index) return _StepState.active;
    return _StepState.upcoming;
  }
}

enum _StepState { done, active, upcoming }

class _StepCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final _StepState state;

  const _StepCircle({required this.icon, required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final Border? border;
    switch (state) {
      case _StepState.done:
        background = AppColors.primaryContainer;
        foreground = Colors.white;
        border = null;
        break;
      case _StepState.active:
        background = Colors.white;
        foreground = AppColors.primaryContainer;
        border = Border.all(color: AppColors.primaryContainer, width: 2);
        break;
      case _StepState.upcoming:
        background = AppColors.surfaceContainerHigh;
        foreground = AppColors.outline;
        border = null;
        break;
    }

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle, border: border),
          child: Icon(
            state == _StepState.done ? Icons.check : icon,
            color: foreground,
            size: 20,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: state == _StepState.upcoming ? AppColors.outline : AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
