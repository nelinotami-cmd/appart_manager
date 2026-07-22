import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../company/domain/entities/company.dart';
import '../../../company/domain/usecases/list_companies_by_plan_id_usecase.dart';
import '../../domain/entities/subscription_plan.dart';

/// Matches the reference "Supprimer l'Abonnement" mockups: impacted
/// companies listed up front, type-the-plan-name-to-confirm before the
/// destructive button enables. The impact list is fetched once, right
/// before showing the dialog (via `ListCompaniesByPlanIdUseCase` - a
/// plain read, not a privileged call - see `CompanyRepository`'s doc
/// comment) rather than a dedicated "preview" Cloud Function resource.
///
/// Returns `true` from `showDialog` if the user confirmed and deletion
/// should proceed; the caller is responsible for actually dispatching
/// `SubscriptionPlanDeleteRequested` afterward.
Future<bool?> showDeletePlanDialog({
  required BuildContext context,
  required SubscriptionPlan plan,
  required ListCompaniesByPlanIdUseCase listCompaniesByPlanIdUseCase,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => _DeletePlanDialogContent(
      plan: plan,
      listCompaniesByPlanIdUseCase: listCompaniesByPlanIdUseCase,
    ),
  );
}

class _DeletePlanDialogContent extends StatefulWidget {
  final SubscriptionPlan plan;
  final ListCompaniesByPlanIdUseCase listCompaniesByPlanIdUseCase;

  const _DeletePlanDialogContent({
    required this.plan,
    required this.listCompaniesByPlanIdUseCase,
  });

  @override
  State<_DeletePlanDialogContent> createState() => _DeletePlanDialogContentState();
}

class _DeletePlanDialogContentState extends State<_DeletePlanDialogContent> {
  final _confirmController = TextEditingController();
  bool _loadingImpact = true;
  List<Company> _impactedCompanies = const [];

  @override
  void initState() {
    super.initState();
    _loadImpact();
  }

  Future<void> _loadImpact() async {
    final result = await widget.listCompaniesByPlanIdUseCase(widget.plan.id);
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _loadingImpact = false),
      (companies) => setState(() {
        _impactedCompanies = companies;
        _loadingImpact = false;
      }),
    );
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = _confirmController.text.trim() == widget.plan.name;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.large)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error),
          const SizedBox(width: 8),
          const Expanded(child: Text("Supprimer l'Abonnement")),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cette action est irreversible et affecte les entreprises actives.',
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.standard),
                ),
                child: Text.rich(
                  TextSpan(
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.onErrorContainer),
                    children: [
                      const TextSpan(text: 'Vous etes sur le point de supprimer le plan "'),
                      TextSpan(
                        text: widget.plan.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: '". '),
                      if (!_loadingImpact)
                        TextSpan(
                          text: '${_impactedCompanies.length} entreprise(s)',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      const TextSpan(
                        text: ' perdront leur plan actuel immediatement (elles ne seront '
                            'pas supprimees, seulement sans plan assigne).',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loadingImpact)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_impactedCompanies.isNotEmpty) ...[
                Text('ENTREPRISES IMPACTEES', style: AppTextStyles.labelSm),
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _impactedCompanies.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) => Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.standard),
                      ),
                      child: Text(_impactedCompanies[index].name, style: AppTextStyles.bodySm),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                'Pour confirmer, saisissez le nom du plan ci-dessous :',
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: 8),
              AppTextField(
                hint: widget.plan.name,
                controller: _confirmController,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: confirmed ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Supprimer Definitivement'),
        ),
      ],
    );
  }
}
