import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/side_panel.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
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
import '../widgets/company_managers_preview.dart';

/// Matches the reference company detail mockups' "General Information" +
/// "Primary Contact" + "Subscription Details" sections, extended with:
///
/// - A "Gestionnaires" section showing the company's manager count, with
///   a "Voir plus" link that opens the full list in a [showSidePanel]
///   overlay (desktop) / full-screen-with-back-arrow (mobile) instead of
///   navigating away - the underlying company detail page never
///   disappears on desktop.
/// - An inline "Assigner un plan" picker in the "Abonnement" section,
///   shown ONLY when the company currently has no plan - visible to
///   Admin and Super Admin alike (both roles can set an *initial* plan;
///   changing an already-assigned plan stays Super-Admin-only via
///   `EditCompanyPage`, enforced server-side in
///   `company.assign-subscription-plan`).
///
/// Split into two widgets:
/// - [CompanyDetailContent] has no `Scaffold`/`AppBar` - rendered at
///   `/companies` (Admin) or `/companies/:companyId` (Super Admin)
///   inside `AppShell`'s ShellRoute.
/// - [CompanyDetailPage] is a thin `Scaffold` wrapper, kept for any
///   future standalone-push use case; nothing in the router currently
///   routes to it directly.
///
/// Every non-flex button here is wrapped in `IntrinsicWidth` - a Flutter
/// (web/DDC) layout quirk where `OutlinedButton`/`FilledButton`'s
/// internal `_InputPadding` can't handle the unbounded width Row's first
/// measurement pass gives non-flex children, causing "BoxConstraints
/// forces an infinite width" crashes. Do not remove these wrappers.
class CompanyDetailPage extends StatelessWidget {
  final String companyId;

  const CompanyDetailPage({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Detail de l'entreprise")),
      body: CompanyDetailContent(companyId: companyId),
    );
  }
}

class CompanyDetailContent extends StatefulWidget {
  final String companyId;

  const CompanyDetailContent({super.key, required this.companyId});

  @override
  State<CompanyDetailContent> createState() => _CompanyDetailContentState();
}

class _CompanyDetailContentState extends State<CompanyDetailContent> {
  String? _planToAssign;

  @override
  void initState() {
    super.initState();
    context
        .read<CompanyBloc>()
        .add(CompanyDetailLoadRequested(companyId: widget.companyId));
    // Manager count for this company - reuses the exact same AuthBloc
    // mechanism the "Gestionnaires" sidebar tab uses, just pointed at
    // THIS page's company rather than (necessarily) the viewer's own.
    context
        .read<AuthBloc>()
        .add(AuthCompanyUsersLoadRequested(companyId: widget.companyId));
    // Needed for the "Assigner un plan" picker, which can't know ahead
    // of time whether the company will turn out to have no plan yet.
    context.read<SubscriptionBloc>().add(const SubscriptionListLoadRequested());
  }

  void _openManagers(BuildContext context, Company company) {
    showSidePanel(
      context: context,
      title: 'Gestionnaires - ${company.name}',
      contentBuilder: (_) => CompanyManagersPreview(companyId: company.id),
    );
  }

  void _assignPlan(Company company) {
    if (_planToAssign == null) return;
    context.read<CompanyBloc>().add(
          CompanyPlanAssignRequested(
              companyId: company.id, subscriptionPlanId: _planToAssign),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = context.watch<AuthBloc>().state.currentUser?.role ==
        UserRole.superAdmin;

    return BlocBuilder<CompanyBloc, CompanyState>(
      buildWhen: (previous, current) =>
          previous.detailStatus != current.detailStatus ||
          previous.currentCompany != current.currentCompany,
      builder: (context, state) {
        if (state.detailStatus == CompanyDetailStatus.loading &&
            state.currentCompany == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.detailStatus == CompanyDetailStatus.error &&
            state.currentCompany == null) {
          return Center(
            child: Text(
              state.detailFailure?.message ?? 'Une erreur est survenue.',
              style: AppTextStyles.bodyMd,
            ),
          );
        }
        final company = state.currentCompany;
        if (company == null) return const SizedBox.shrink();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(company.name, style: AppTextStyles.headlineMd),
                          const SizedBox(width: AppSpacing.sm),
                          _StatusBadge(company: company),
                        ],
                      ),
                    ),
                    IntrinsicWidth(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push(AppRoutes.companyEdit(company.id)),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Modifier'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  title: 'Informations Generales',
                  icon: Icons.info_outline,
                  child: _InfoRow(label: 'Adresse', value: company.address),
                ),
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: 'Contact Principal',
                  icon: Icons.person_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Nom', value: company.contactName),
                      _InfoRow(label: 'Email', value: company.contactEmail),
                      _InfoRow(label: 'Telephone', value: company.contactPhone),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: 'Gestionnaires',
                  icon: Icons.people_outline,
                  child: BlocBuilder<AuthBloc, AuthState>(
                    buildWhen: (previous, current) =>
                        previous.companyUsers != current.companyUsers ||
                        previous.companyUsersStatus !=
                            current.companyUsersStatus,
                    builder: (context, authState) {
                      final isLoadingCount = authState.companyUsersStatus ==
                              CompanyUsersStatus.loading &&
                          authState.companyUsers.isEmpty;
                      return Row(
                        children: [
                          Expanded(
                            child: isLoadingCount
                                ? Text('Chargement...',
                                    style: AppTextStyles.bodyMd)
                                : Text(
                                    '${authState.companyUsers.length} gestionnaire(s)',
                                    style: AppTextStyles.bodyMd,
                                  ),
                          ),
                          TextButton(
                            onPressed: () => _openManagers(context, company),
                            child: const Text('Voir plus'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: 'Abonnement',
                  icon: Icons.workspace_premium_outlined,
                  child: company.subscriptionPlanId != null
                      ? _InfoRow(
                          label: 'Plan actuel',
                          value: company.subscriptionPlanId!)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Aucun plan assigne.',
                                style: AppTextStyles.bodyMd),
                            const SizedBox(height: AppSpacing.md),
                            BlocBuilder<SubscriptionBloc, SubscriptionState>(
                              buildWhen: (previous, current) =>
                                  previous.plans != current.plans,
                              builder: (context, subState) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _planToAssign,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          hintText: 'Choisir un plan',
                                        ),
                                        items: [
                                          for (final SubscriptionPlan plan
                                              in subState.plans)
                                            DropdownMenuItem(
                                              value: plan.id,
                                              child: Text(plan.name),
                                            ),
                                        ],
                                        onChanged: (value) => setState(
                                            () => _planToAssign = value),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    IntrinsicWidth(
                                      child: FilledButton(
                                        onPressed: _planToAssign == null
                                            ? null
                                            : () => _assignPlan(company),
                                        child: const Text('Assigner'),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                ),
                if (isSuperAdmin) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          company.status == CompanyStatus.active
                              ? "Desactiver bloque immediatement l'acces de tous les comptes de cette entreprise."
                              : "Reactiver l'entreprise (les comptes individuellement desactives auparavant restent desactives).",
                          style: AppTextStyles.bodySm,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      IntrinsicWidth(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                company.status == CompanyStatus.active
                                    ? AppColors.error
                                    : AppColors.primaryContainer,
                          ),
                          onPressed: () => context.read<CompanyBloc>().add(
                                CompanyStatusUpdateRequested(
                                  companyId: company.id,
                                  activate:
                                      company.status != CompanyStatus.active,
                                ),
                              ),
                          child: Text(
                            company.status == CompanyStatus.active
                                ? 'Desactiver'
                                : 'Reactiver',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section(
      {required this.title, required this.icon, required this.child});

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
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.labelSm),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.bodyMd),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Company company;

  const _StatusBadge({required this.company});

  @override
  Widget build(BuildContext context) {
    final isActive = company.status == CompanyStatus.active;
    final bg =
        isActive ? AppColors.successContainer : AppColors.surfaceContainerHigh;
    final fg =
        isActive ? AppColors.onSuccessContainer : AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(
        isActive ? 'Actif' : 'Inactif',
        style: AppTextStyles.labelSm.copyWith(color: fg),
      ),
    );
  }
}
