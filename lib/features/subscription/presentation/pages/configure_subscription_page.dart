import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/inline_alert.dart';
import '../../domain/entities/subscription_feature.dart';
import '../../domain/entities/subscription_plan.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';

/// Matches the reference "Configurer l'Abonnement" mockups. Reached via
/// `/subscriptions/new` (create) or `/subscriptions/:planId/edit`
/// (edit), both full-screen routes outside `AppShell`'s ShellRoute.
class ConfigureSubscriptionPage extends StatefulWidget {
  final String? planId;

  const ConfigureSubscriptionPage({super.key, this.planId});

  @override
  State<ConfigureSubscriptionPage> createState() => _ConfigureSubscriptionPageState();
}

class _ConfigureSubscriptionPageState extends State<ConfigureSubscriptionPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final Set<SubscriptionFeature> _selectedFeatures = {};

  bool _initialized = false;
  String? _localError;

  bool get _isEditing => widget.planId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      context
          .read<SubscriptionBloc>()
          .add(SubscriptionDetailLoadRequested(planId: widget.planId!));
    } else {
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _populateFrom(SubscriptionPlan plan) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = plan.name;
    _descriptionController.text = plan.description;
    _priceController.text = plan.monthlyPrice.toStringAsFixed(2);
    _selectedFeatures
      ..clear()
      ..addAll(plan.enabledFeatures);
  }

  void _save() {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final price = double.tryParse(_priceController.text.trim().replaceAll(',', '.'));

    if (name.isEmpty || description.isEmpty) {
      setState(() => _localError = 'Le nom et la description sont requis.');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _localError = 'Entrez un prix mensuel valide.');
      return;
    }
    setState(() => _localError = null);

    final bloc = context.read<SubscriptionBloc>();
    if (_isEditing) {
      bloc.add(SubscriptionPlanUpdateRequested(
        planId: widget.planId!,
        name: name,
        description: description,
        monthlyPrice: price,
        enabledFeatures: _selectedFeatures.toList(),
      ));
    } else {
      bloc.add(SubscriptionPlanCreateRequested(
        name: name,
        description: description,
        monthlyPrice: price,
        enabledFeatures: _selectedFeatures.toList(),
      ));
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEditing ? 'Modifier le Plan' : 'Nouveau Plan')),
      body: BlocBuilder<SubscriptionBloc, SubscriptionState>(
        buildWhen: (previous, current) =>
            previous.detailStatus != current.detailStatus ||
            previous.currentPlan != current.currentPlan,
        builder: (context, state) {
          if (_isEditing) {
            if (state.detailStatus == SubscriptionDetailStatus.loading &&
                state.currentPlan == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.currentPlan != null) _populateFrom(state.currentPlan!);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_localError != null)
                    AppInlineAlert(message: _localError!)
                  else if (state.detailStatus == SubscriptionDetailStatus.error &&
                      state.detailFailure != null)
                    AppInlineAlert(message: state.detailFailure!.message),
                  _FormSection(
                    title: 'Informations Generales',
                    icon: Icons.edit_note,
                    children: [
                      AppTextField(
                        label: 'Nom du plan',
                        hint: 'Ex: Premium Enterprise',
                        controller: _nameController,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Description',
                        hint: 'Decrivez les avantages principaux de ce forfait...',
                        controller: _descriptionController,
                        maxLines: 4,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FormSection(
                    title: 'Structure de Prix',
                    icon: Icons.payments_outlined,
                    children: [
                      AppTextField(
                        label: 'Prix mensuel (EUR)',
                        hint: '0.00',
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FormSection(
                    title: 'Fonctionnalites',
                    icon: Icons.star_border,
                    children: [
                      for (final feature in SubscriptionFeature.values)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(feature.label, style: AppTextStyles.bodyMd),
                          value: _selectedFeatures.contains(feature),
                          onChanged: (enabled) => setState(() {
                            if (enabled) {
                              _selectedFeatures.add(feature);
                            } else {
                              _selectedFeatures.remove(feature);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IntrinsicWidth(
                        child: TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(
                        width: 220,
                        child: AppPrimaryButton(
                          label: 'Enregistrer le Plan',
                          isLoading: state.detailStatus == SubscriptionDetailStatus.loading,
                          onPressed: _save,
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

  const _FormSection({required this.title, required this.icon, required this.children});

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
