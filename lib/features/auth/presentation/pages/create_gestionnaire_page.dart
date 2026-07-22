import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../widgets/auth_shell.dart';

/// Matches the reference `create_new_user_screen` mockup's form card
/// (Full Name / Work Email / Phone Number), with two deliberate
/// differences from the mockup:
///
/// 1. No sidebar/app-shell navigation (Dashboard/Users/Security/Logs) -
///    that belongs to the not-yet-built dashboard feature (5.11); this
///    page is reachable only from `CompanyUsersPage` for now, wrapped in
///    a plain `AppBar` instead.
/// 2. No "Account Permission" selector - every account this screen
///    creates is a Gestionnaire (cahier des charges 5.7 gives Admin no
///    choice of role here), so showing a dropdown with only one
///    possible value would be decorative at best, misleading at worst.
class CreateGestionnairePage extends StatefulWidget {
  static const routeName = '/company/users/new';

  const CreateGestionnairePage({super.key});

  @override
  State<CreateGestionnairePage> createState() => _CreateGestionnairePageState();
}

class _CreateGestionnairePageState extends State<CreateGestionnairePage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    _submitted = true;
    context.read<AuthBloc>().add(
          AuthCreateGestionnaireRequested(
            fullName: _fullNameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
          ),
        );
  }

  Future<void> _showTempPasswordDialog(BuildContext context, String tempPassword) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.large)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 8),
            const Text('Compte cree'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Communiquez ce mot de passe temporaire au Gestionnaire des '
              'maintenant - il ne sera plus jamais affiche.',
              style: AppTextStyles.bodySm,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.standard),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      tempPassword,
                      style: AppTextStyles.bodyMd.copyWith(fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ]),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copier',
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tempPassword));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copie dans le presse-papiers.')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          AppPrimaryButton(
            label: "J'ai note le mot de passe",
            trailingIcon: null,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    context.read<AuthBloc>().add(const AuthLastCreatedGestionnaireTempPasswordAcknowledged());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nouveau Gestionnaire')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            _submitted &&
            previous.lastCreatedGestionnaireTempPassword !=
                current.lastCreatedGestionnaireTempPassword,
        listener: (context, state) {
          final tempPassword = state.lastCreatedGestionnaireTempPassword;
          if (tempPassword != null) {
            _submitted = false;
            _showTempPasswordDialog(context, tempPassword);
          }
        },
        builder: (context, state) {
          final isLoading = _submitted && state.companyUsersStatus == CompanyUsersStatus.loading;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Creer un nouveau Gestionnaire', style: AppTextStyles.headlineMd),
                    const SizedBox(height: 4),
                    Text(
                      "Configurez l'acces d'un membre de l'equipe operationnelle. "
                      'Tous les champs sont requis.',
                      style: AppTextStyles.bodySm,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppRadius.large),
                        border: Border.all(color: AppColors.surfaceContainerHighest),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_submitted &&
                              state.companyUsersStatus == CompanyUsersStatus.error &&
                              state.companyUsersFailure != null)
                            AuthInlineAlert(message: state.companyUsersFailure!.message),
                          AppTextField(
                            label: 'Nom complet',
                            hint: 'Ex. Jean Dupont',
                            controller: _fullNameController,
                            prefixIcon: Icons.person_outline,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            label: 'Email professionnel',
                            hint: 'gestionnaire@entreprise.com',
                            controller: _emailController,
                            prefixIcon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            label: 'Numero de telephone',
                            hint: '+237 6XX XXX XXX',
                            controller: _phoneController,
                            prefixIcon: Icons.call_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                                child: const Text('Annuler'),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              SizedBox(
                                width: 220,
                                child: AppPrimaryButton(
                                  label: 'Generer le compte',
                                  isLoading: isLoading,
                                  onPressed: _submit,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
