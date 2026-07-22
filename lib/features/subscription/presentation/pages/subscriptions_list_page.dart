import 'package:appartements_erp/features/subscription/domain/entities/subscription_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/subscription_plan.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import 'configure_subscription_page.dart';
import 'subscription_detail_page.dart';

/// Matches the reference `Gestion des Abonnements` mockups' plan list.
///
/// Dropped (not in cahier des charges 5.3, and each needs infrastructure
/// beyond CRUD+list): Plans Actifs/Total Clients/MRR/Retention stat
/// cards, "Analyse des Tendances" chart, "Besoin d'aide" consultant
/// widget, per-plan "entreprises actives" usage bar (would need an
/// aggregate count query per plan on every list render).
///
/// Hosted inside `AppShell`; search driven externally via [searchQuery],
/// same pattern as `CompanyUsersPage`/`CompaniesListPage`.
class SubscriptionsListPage extends StatefulWidget {
  final String searchQuery;

  const SubscriptionsListPage({super.key, this.searchQuery = ''});

  @override
  State<SubscriptionsListPage> createState() => _SubscriptionsListPageState();
}

class _SubscriptionsListPageState extends State<SubscriptionsListPage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      context.read<SubscriptionBloc>()
        ..add(const SubscriptionListLoadRequested())
        ..add(const SubscriptionListWatchStarted());
    }
  }

  @override
  void didUpdateWidget(covariant SubscriptionsListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      final query = widget.searchQuery.trim();
      if (query.isEmpty) {
        context
            .read<SubscriptionBloc>()
            .add(const SubscriptionListLoadRequested());
      } else {
        context
            .read<SubscriptionBloc>()
            .add(SubscriptionSearchRequested(query: query));
      }
    }
  }

  @override
  void dispose() {
    context.read<SubscriptionBloc>().add(const SubscriptionListWatchStopped());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gestion des Abonnements',
                        style: AppTextStyles.headlineMd),
                    const SizedBox(height: 4),
                    Text(
                      'Configurez les forfaits tarifaires proposes aux entreprises.',
                      style: AppTextStyles.bodySm,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ConfigureSubscriptionPage()),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter un Plan'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: BlocBuilder<SubscriptionBloc, SubscriptionState>(
              buildWhen: (previous, current) =>
                  previous.listStatus != current.listStatus ||
                  previous.plans != current.plans,
              builder: (context, state) {
                if (state.listStatus == SubscriptionListStatus.loading &&
                    state.plans.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.listStatus == SubscriptionListStatus.error &&
                    state.plans.isEmpty) {
                  return Center(
                    child: Text(
                      state.listFailure?.message ?? 'Une erreur est survenue.',
                      style: AppTextStyles.bodyMd,
                    ),
                  );
                }
                if (state.plans.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_outlined,
                            size: 40, color: AppColors.outline),
                        const SizedBox(height: AppSpacing.md),
                        Text('Aucun plan cree pour le moment',
                            style: AppTextStyles.bodyMd),
                      ],
                    ),
                  );
                }
                return isWide
                    ? _PlansTable(plans: state.plans)
                    : ListView.separated(
                        itemCount: state.plans.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) =>
                            _PlanCard(plan: state.plans[index]),
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlansTable extends StatelessWidget {
  final List<SubscriptionPlan> plans;

  const _PlansTable({required this.plans});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('NOM DU PLAN', style: AppTextStyles.labelSm)),
                Expanded(
                    flex: 4,
                    child:
                        Text('FONCTIONNALITES', style: AppTextStyles.labelSm)),
                Expanded(
                    flex: 2,
                    child: Text('PRIX MENSUEL', style: AppTextStyles.labelSm)),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: plans.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1, color: AppColors.surfaceContainerHighest),
              itemBuilder: (context, index) {
                final plan = plans[index];
                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            SubscriptionDetailPage(planId: plan.id)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(plan.name, style: AppTextStyles.bodyMd),
                              Text(plan.description,
                                  style: AppTextStyles.bodySm),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final feature in plan.enabledFeatures)
                                _FeatureChip(label: feature.label),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${plan.monthlyPrice.toStringAsFixed(2)} EUR',
                            style: AppTextStyles.bodyMd,
                          ),
                        ),
                        const SizedBox(
                          width: 48,
                          child: Icon(Icons.chevron_right,
                              size: 18, color: AppColors.outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;

  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.large),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => SubscriptionDetailPage(planId: plan.id)),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: AppColors.surfaceContainerHighest),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(plan.name, style: AppTextStyles.bodyMd)),
                  Text('${plan.monthlyPrice.toStringAsFixed(2)} EUR',
                      style: AppTextStyles.bodyMd),
                ],
              ),
              const SizedBox(height: 4),
              Text(plan.description, style: AppTextStyles.bodySm),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final feature in plan.enabledFeatures)
                    _FeatureChip(label: feature.label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;

  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm
            .copyWith(color: AppColors.onSecondaryContainer),
      ),
    );
  }
}
