import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/inline_alert.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../subscription/domain/entities/subscription_plan.dart';
import '../../../subscription/presentation/bloc/subscription_bloc.dart';
import '../../../subscription/presentation/bloc/subscription_event.dart';
import '../../../subscription/presentation/bloc/subscription_state.dart';
import '../../domain/entities/company.dart';
import '../../domain/entities/company_status.dart';
import '../bloc/company_bloc.dart';
import '../bloc/company_event.dart';
import '../bloc/company_state.dart';

/// Matches the reference "Modifier l'Entreprise" mockups' General
/// Information + Primary Contact sections. Two deliberate differences:
///
/// 1. No "Company Logo" field/upload - not in cahier des charges 5.2,
///    and would need an entirely new Storage bucket/permissions/upload
///    flow beyond CRUD+list.
/// 2. "Enterprise Status" toggle and "Subscription Plan" dropdown are
///    only shown to Super Admin - both are backed by separate,
///    Super-Admin-only Cloud Function resources (`company.update-status`,
///    `company.assign-subscription-plan`); an Admin editing their own
///    company only ever sees/touches the profile fields.
///
/// One "Sauvegarder" button still fires all changed operations (profile,
/// and - Super Admin only - status/plan) in one go, matching the
/// mockups' single-save UX even though the backend treats them as three
/// distinct privileged calls.
class EditCompanyPage extends StatefulWidget {
  final String companyId;

  const EditCompanyPage({super.key, required this.companyId});

  @override
  State<EditCompanyPage> createState() => _EditCompanyPageState();
}

class _EditCompanyPageState extends State<EditCompanyPage> {
  final _nameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _initialized = false;
  bool _isActive = true;
  String? _selectedPlanId;
  String? _localError;

  @override
  void initState() {
    super.initState();
    context
        .read<CompanyBloc>()
        .add(CompanyDetailLoadRequested(companyId: widget.companyId));
    if (context.read<AuthBloc>().state.currentUser?.role ==
        UserRole.superAdmin) {
      context
          .read<SubscriptionBloc>()
          .add(const SubscriptionListLoadRequested());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _populateFrom(Company company) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = company.name;
    _contactNameController.text = company.contactName;
    _contactEmailController.text = company.contactEmail;
    _contactPhoneController.text = company.contactPhone;
    _addressController.text = company.address;
    _isActive = company.status == CompanyStatus.active;
    _selectedPlanId = company.subscriptionPlanId;
  }

  void _save(Company original, bool isSuperAdmin) {
    if (_nameController.text.trim().isEmpty ||
        _contactNameController.text.trim().isEmpty ||
        _contactEmailController.text.trim().isEmpty ||
        _contactPhoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      setState(() => _localError = 'Tous les champs sont requis.');
      return;
    }
    setState(() => _localError = null);

    final bloc = context.read<CompanyBloc>();
    bloc.add(CompanyProfileUpdateRequested(
      companyId: original.id,
      name: _nameController.text.trim(),
      contactName: _contactNameController.text.trim(),
      contactEmail: _contactEmailController.text.trim(),
      contactPhone: _contactPhoneController.text.trim(),
      address: _addressController.text.trim(),
    ));

    if (isSuperAdmin) {
      final wasActive = original.status == CompanyStatus.active;
      if (_isActive != wasActive) {
        bloc.add(CompanyStatusUpdateRequested(
            companyId: original.id, activate: _isActive));
      }
      if (_selectedPlanId != original.subscriptionPlanId) {
        bloc.add(CompanyPlanAssignRequested(
          companyId: original.id,
          subscriptionPlanId: _selectedPlanId,
        ));
      }
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = context.watch<AuthBloc>().state.currentUser?.role ==
        UserRole.superAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Modifier l'entreprise")),
      body: BlocBuilder<CompanyBloc, CompanyState>(
        buildWhen: (previous, current) =>
            previous.detailStatus != current.detailStatus ||
            previous.currentCompany != current.currentCompany,
        builder: (context, state) {
          final company = state.currentCompany;
          if (state.detailStatus == CompanyDetailStatus.loading &&
              company == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (company == null) return const SizedBox.shrink();
          _populateFrom(company);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_localError != null)
                    AppInlineAlert(message: _localError!)
                  else if (state.detailStatus == CompanyDetailStatus.error &&
                      state.detailFailure != null)
                    AppInlineAlert(message: state.detailFailure!.message),
                  _FormSection(
                    title: 'Informations Generales',
                    icon: Icons.info_outline,
                    children: [
                      AppTextField(
                        label: "Nom de l'entreprise",
                        hint: '',
                        controller: _nameController,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Adresse',
                        hint: '',
                        controller: _addressController,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FormSection(
                    title: 'Contact Principal',
                    icon: Icons.person_outline,
                    children: [
                      AppTextField(
                        label: 'Nom du contact',
                        hint: '',
                        controller: _contactNameController,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Email',
                        hint: '',
                        controller: _contactEmailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Telephone',
                        hint: '',
                        controller: _contactPhoneController,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                  if (isSuperAdmin) ...[
                    const SizedBox(height: AppSpacing.md),
                    _FormSection(
                      title: 'Parametres operationnels',
                      icon: Icons.settings_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _isActive
                                    ? 'Entreprise active'
                                    : 'Entreprise inactive',
                                style: AppTextStyles.bodyMd,
                              ),
                            ),
                            Switch(
                              value: _isActive,
                              onChanged: (value) =>
                                  setState(() => _isActive = value),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text("Plan d'abonnement", style: AppTextStyles.labelMd),
                        const SizedBox(height: 8),
                        BlocBuilder<SubscriptionBloc, SubscriptionState>(
                          buildWhen: (previous, current) =>
                              previous.plans != current.plans,
                          builder: (context, subState) {
                            final plans = subState.plans;
                            return DropdownButtonFormField<String?>(
                              value: _selectedPlanId,
                              decoration: const InputDecoration(isDense: true),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Aucun plan'),
                                ),
                                for (final SubscriptionPlan plan in plans)
                                  DropdownMenuItem<String?>(
                                    value: plan.id,
                                    child: Text(plan.name),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _selectedPlanId = value),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(
                        width: 200,
                        child: AppPrimaryButton(
                          label: 'Sauvegarder',
                          isLoading:
                              state.detailStatus == CompanyDetailStatus.loading,
                          onPressed: () => _save(company, isSuperAdmin),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FormSection(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.outline),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTextStyles.labelMd),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}
