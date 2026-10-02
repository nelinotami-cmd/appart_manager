import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/inline_alert.dart';
import '../../domain/entities/notification_channel.dart';
import '../../domain/entities/notification_template.dart';
import '../../domain/services/notification_template_renderer.dart';
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';

/// One form for both create and edit - [templateId] null means create.
/// Reached via `/notifications/new` or `/notifications/:id/edit`, both
/// inside `AppShell`'s ShellRoute (sidebar stays visible), matching the
/// company/subscription/gestionnaire create-edit pages.
class ConfigureNotificationTemplatePage extends StatefulWidget {
  final String? templateId;

  const ConfigureNotificationTemplatePage({super.key, this.templateId});

  @override
  State<ConfigureNotificationTemplatePage> createState() =>
      _ConfigureNotificationTemplatePageState();
}

class _ConfigureNotificationTemplatePageState
    extends State<ConfigureNotificationTemplatePage> {
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();
  NotificationChannel _channel = NotificationChannel.email;

  bool _initialized = false;
  String? _localError;

  bool get _isEditing => widget.templateId != null;

  List<String> get _currentPlaceholders =>
      extractTemplatePlaceholders(_messageController.text);

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      context.read<NotificationBloc>().add(
          NotificationTemplateDetailLoadRequested(
              templateId: widget.templateId!));
    } else {
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _populateFrom(NotificationTemplate template) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = template.name;
    _messageController.text = template.message;
    _channel = template.channel;
  }

  void _save() {
    final name = _nameController.text.trim();
    final message = _messageController.text.trim();
    if (name.isEmpty || message.isEmpty) {
      setState(() => _localError = 'Le nom et le message sont requis.');
      return;
    }
    setState(() => _localError = null);

    final bloc = context.read<NotificationBloc>();
    if (_isEditing) {
      bloc.add(NotificationTemplateUpdateRequested(
        templateId: widget.templateId!,
        name: name,
        message: message,
        channel: _channel,
      ));
    } else {
      bloc.add(
        NotificationTemplateCreateRequested(
            name: name, message: message, channel: _channel),
      );
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: Text(_isEditing ? 'Modifier le modele' : 'Nouveau modele')),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        buildWhen: (previous, current) =>
            previous.detailStatus != current.detailStatus ||
            previous.currentTemplate != current.currentTemplate,
        builder: (context, state) {
          if (_isEditing) {
            if (state.detailStatus == NotificationDetailStatus.loading &&
                state.currentTemplate == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.currentTemplate != null)
              _populateFrom(state.currentTemplate!);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_localError != null)
                    AppInlineAlert(message: _localError!)
                  else if (state.detailStatus ==
                          NotificationDetailStatus.error &&
                      state.detailFailure != null)
                    AppInlineAlert(message: state.detailFailure!.message),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      border:
                          Border.all(color: AppColors.surfaceContainerHighest),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          label: 'Nom du modele',
                          hint: 'Ex: Rappel de paiement',
                          controller: _nameController,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('Canal', style: AppTextStyles.labelMd),
                        const SizedBox(height: 8),
                        SegmentedButton<NotificationChannel>(
                          segments: [
                            for (final channel in NotificationChannel.values)
                              ButtonSegment(
                                  value: channel, label: Text(channel.label)),
                          ],
                          selected: {_channel},
                          onSelectionChanged: (selection) =>
                              setState(() => _channel = selection.first),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'Message',
                          hint:
                              'Contenu du modele... Ex: Le paiement de {{amount}} '
                              'est du le {{dueDate}}.',
                          controller: _messageController,
                          maxLines: 6,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Utilisez {{cle}} pour inserer une valeur fournie plus tard '
                          '(date, montant, etc.) - la fonctionnalite qui enverra ce '
                          "modele (reservations, taches...) definira les cles reelles "
                          'disponibles.',
                          style: AppTextStyles.bodySm,
                        ),
                        if (_currentPlaceholders.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final placeholder in _currentPlaceholders)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: AppColors.secondaryContainer,
                                  label: Text(
                                    '{{$placeholder}}',
                                    style: AppTextStyles.labelSm.copyWith(
                                      color: AppColors.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
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
                        width: 200,
                        child: AppPrimaryButton(
                          label: 'Sauvegarder',
                          isLoading: state.detailStatus ==
                              NotificationDetailStatus.loading,
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
