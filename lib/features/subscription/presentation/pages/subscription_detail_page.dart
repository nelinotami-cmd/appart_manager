import 'package:appartements_erp/features/subscription/domain/entities/subscription_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../company/domain/usecases/list_companies_by_plan_id_usecase.dart';
import '../../domain/entities/subscription_plan.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../widgets/delete_plan_dialog.dart';
import 'configure_subscription_page.dart';

/// Matches the reference "Details de l'Abonnement" mockups' Tarification
/// + Fonctionnalites sections.
///
/// Dropped (not in cahier des charges 5.3, and each needs
/// infrastructure beyond CRUD+list): the "Entreprises" panel listing
/// companies on this plan (kept only inside the delete-confirmation
/// dialog, where it's actually load-bearing for the decision being
/// made), usage activity chart, activity/audit log.
class SubscriptionDetailPage extends StatefulWidget {
  final String planId;

  const SubscriptionDetailPage({super.key, required this.planId});

  @override
  State<SubscriptionDetailPage> createState() => _SubscriptionDetailPageState();
}

class _SubscriptionDetailPageState extends State<SubscriptionDetailPage> {
  @override
  void initState() {
    super.initState();
    context
        .read<SubscriptionBloc>()
        .add(SubscriptionDetailLoadRequested(planId: widget.planId));
  }

  Future<void> _delete(SubscriptionPlan plan) async {
    final confirmed = await showDeletePlanDialog(
      context: context,
      plan: plan,
      listCompaniesByPlanIdUseCase: sl<ListCompaniesByPlanIdUseCase>(),
    );
    if (confirmed != true || !mounted) return;

    context
        .read<SubscriptionBloc>()
        .add(SubscriptionPlanDeleteRequested(planId: plan.id));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plan supprime.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Details de l'Abonnement")),
      body: BlocBuilder<SubscriptionBloc, SubscriptionState>(
        buildWhen: (previous, current) =>
            previous.detailStatus != current.detailStatus ||
            previous.currentPlan != current.currentPlan,
        builder: (context, state) {
          if (state.detailStatus == SubscriptionDetailStatus.loading &&
              state.currentPlan == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.detailStatus == SubscriptionDetailStatus.error &&
              state.currentPlan == null) {
            return Center(
              child: Text(
                state.detailFailure?.message ?? 'Une erreur est survenue.',
                style: AppTextStyles.bodyMd,
              ),
            );
          }
          final plan = state.currentPlan;
          if (plan == null) return const SizedBox.shrink();

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
                        child: Text(plan.name, style: AppTextStyles.headlineMd),
                      ),
                      // Wrapped in IntrinsicWidth: see the note in
                      // company_detail_page.dart - same Row-measurement
                      // quirk with OutlinedButton's internal _InputPadding.
                      IntrinsicWidth(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ConfigureSubscriptionPage(planId: plan.id),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Modifier'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IntrinsicWidth(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error),
                          onPressed: () => _delete(plan),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Supprimer'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(plan.description, style: AppTextStyles.bodySm),
                  const SizedBox(height: AppSpacing.lg),
                  _Section(
                    title: 'Tarification',
                    icon: Icons.payments_outlined,
                    child: Row(
                      children: [
                        Expanded(
                          child: _PriceTile(
                            label: 'PRIX MENSUEL',
                            value:
                                '${plan.monthlyPrice.toStringAsFixed(2)} EUR / mois',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _PriceTile(
                            label: 'PRIX ANNUEL (REMISE 15%)',
                            value:
                                '${plan.annualPrice.toStringAsFixed(2)} EUR / an',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Fonctionnalites Activees',
                    icon: Icons.tune,
                    child: plan.enabledFeatures.isEmpty
                        ? Text('Aucune fonctionnalite activee.',
                            style: AppTextStyles.bodySm)
                        : Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final feature in plan.enabledFeatures)
                                Chip(
                                  avatar: const Icon(Icons.check, size: 16),
                                  label: Text(feature.label),
                                ),
                            ],
                          ),
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

class _PriceTile extends StatelessWidget {
  final String label;
  final String value;

  const _PriceTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSm),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.headlineSm),
        ],
      ),
    );
  }
}
