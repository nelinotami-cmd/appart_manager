import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/company.dart';
import '../../domain/entities/company_status.dart';
import '../bloc/company_bloc.dart';
import '../bloc/company_event.dart';
import '../bloc/company_state.dart';
import 'edit_company_page.dart';

/// Matches the reference company detail mockups' "General Information" +
/// "Primary Contact" + "Subscription Details" sections.
///
/// Dropped from the mockups (not in cahier des charges 5.2, and each
/// would need infrastructure/queries beyond plain CRUD+list): Quick
/// Stats (Total Users/Active Bookings/Service Utilization - these belong
/// to features that don't exist yet), Admin History/audit log, "View
/// Invoices" (billing isn't built).
///
/// Split into two widgets on purpose:
/// - [CompanyDetailContent] has no `Scaffold`/`AppBar` - safe to embed
///   directly as `AppShell` content (this is what an Admin's "Entreprises"
///   destination uses for their own single company).
/// - [CompanyDetailPage] is a thin `Scaffold` wrapper around it, for
///   standalone push navigation (this is what `CompaniesListPage` pushes
///   to when a Super Admin taps a row).
///
/// Embedding [CompanyDetailPage] (with its own `Scaffold`) directly as
/// `AppShell` content used to be exactly this file's bug: a `Scaffold`
/// nested inside another `Scaffold`'s body (itself inside a `Row`'s
/// `Expanded`) is a well-known source of "Cannot hit test a render box
/// with no size" / mouse-tracker assertion failures in Flutter - nested
/// Scaffolds don't compose cleanly without explicit sizing. Always reach
/// for [CompanyDetailContent] when embedding, [CompanyDetailPage] only
/// when pushing a real new route.
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
  @override
  void initState() {
    super.initState();
    context
        .read<CompanyBloc>()
        .add(CompanyDetailLoadRequested(companyId: widget.companyId));
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
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EditCompanyPage(companyId: company.id),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Modifier'),
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
                  title: 'Abonnement',
                  icon: Icons.workspace_premium_outlined,
                  child: _InfoRow(
                    label: 'Plan actuel',
                    value: company.subscriptionPlanId ?? 'Aucun plan assigne',
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
                      FilledButton(
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
