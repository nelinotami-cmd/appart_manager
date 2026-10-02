import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/side_panel.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/inline_alert.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/notification_channel.dart';
import '../../domain/entities/notification_log.dart';
import '../../domain/entities/notification_template.dart';
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';

enum _NotificationsTab { templates, history }

/// Matches this project's established list-page pattern (see
/// `CompaniesListPage`/`SubscriptionsListPage`): responsive table/cards,
/// a create action, rendered inside `AppShell`'s ShellRoute at
/// `/notifications`.
///
/// Two extras beyond plain CRUD+list, both explicitly requested:
/// - "Envoyer un test" - a one-off test email to the current user, to
///   verify the SMTP + `_send_email` pipeline actually works before any
///   real feature (5.8/5.10) depends on it.
/// - An Admin-only "Preferences" entry point (muted templates) - hidden
///   entirely for Gestionnaire/Super Admin, since only an Admin has
///   anything to configure here (Gestionnaires always receive, Super
///   Admin isn't a company-notification recipient at all).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  _NotificationsTab _tab = _NotificationsTab.templates;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      context.read<NotificationBloc>()
        ..add(const NotificationTemplateListLoadRequested())
        ..add(const NotificationTemplateListWatchStarted());
    }
  }

  @override
  void dispose() {
    context
        .read<NotificationBloc>()
        .add(const NotificationTemplateListWatchStopped());
    super.dispose();
  }

  void _openTestEmailDialog(BuildContext context) {
    showDialog<void>(
        context: context, builder: (_) => const _SendTestEmailDialog());
  }

  void _openPreferences(BuildContext context) {
    showSidePanel(
      context: context,
      title: 'Preferences de notification',
      contentBuilder: (_) => const _NotificationPreferencesPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        context.watch<AuthBloc>().state.currentUser?.role == UserRole.admin;

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
                    Text('Notifications', style: AppTextStyles.headlineMd),
                    const SizedBox(height: 4),
                    Text(
                      'Modeles de notification et historique des envois.',
                      style: AppTextStyles.bodySm,
                    ),
                  ],
                ),
              ),
              if (isAdmin) ...[
                IntrinsicWidth(
                  child: OutlinedButton.icon(
                    onPressed: () => _openPreferences(context),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Preferences'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              IntrinsicWidth(
                child: OutlinedButton.icon(
                  onPressed: () => _openTestEmailDialog(context),
                  icon: const Icon(Icons.send_outlined, size: 16),
                  label: const Text('Envoyer un test'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IntrinsicWidth(
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.notificationTemplateNew),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouveau modele'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<_NotificationsTab>(
            segments: const [
              ButtonSegment(
                  value: _NotificationsTab.templates, label: Text('Modeles')),
              ButtonSegment(
                  value: _NotificationsTab.history, label: Text('Historique')),
            ],
            selected: {_tab},
            onSelectionChanged: (selection) {
              setState(() => _tab = selection.first);
              if (_tab == _NotificationsTab.history) {
                context
                    .read<NotificationBloc>()
                    .add(const NotificationLogListLoadRequested());
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _tab == _NotificationsTab.templates
                ? const _TemplatesList()
                : const _HistoryList(),
          ),
        ],
      ),
    );
  }
}

class _TemplatesList extends StatelessWidget {
  const _TemplatesList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationBloc, NotificationState>(
      buildWhen: (previous, current) =>
          previous.listStatus != current.listStatus ||
          previous.templates != current.templates,
      builder: (context, state) {
        if (state.listStatus == NotificationListStatus.loading &&
            state.templates.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.listStatus == NotificationListStatus.error &&
            state.templates.isEmpty) {
          return Center(
            child: Text(
              state.listFailure?.message ?? 'Une erreur est survenue.',
              style: AppTextStyles.bodyMd,
            ),
          );
        }
        if (state.templates.isEmpty) {
          return Center(
            child: Text('Aucun modele cree pour le moment',
                style: AppTextStyles.bodyMd),
          );
        }
        return ListView.separated(
          itemCount: state.templates.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) =>
              _TemplateCard(template: state.templates[index]),
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final NotificationTemplate template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(template.name, style: AppTextStyles.bodyMd),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.standard),
                      ),
                      child: Text(
                        template.channel.label,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  template.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm,
                ),
              ],
            ),
          ),
          IntrinsicWidth(
            child: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () =>
                  context.push(AppRoutes.notificationTemplateEdit(template.id)),
            ),
          ),
          IntrinsicWidth(
            child: IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.error),
              onPressed: () => context.read<NotificationBloc>().add(
                  NotificationTemplateDeleteRequested(templateId: template.id)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationBloc, NotificationState>(
      buildWhen: (previous, current) =>
          previous.logsStatus != current.logsStatus ||
          previous.logs != current.logs,
      builder: (context, state) {
        if (state.logsStatus == NotificationLogsStatus.loading &&
            state.logs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.logsStatus == NotificationLogsStatus.error &&
            state.logs.isEmpty) {
          return Center(
            child: Text(
              state.logsFailure?.message ?? 'Une erreur est survenue.',
              style: AppTextStyles.bodyMd,
            ),
          );
        }
        if (state.logs.isEmpty) {
          return Center(
            child: Text('Aucune notification envoyee pour le moment',
                style: AppTextStyles.bodyMd),
          );
        }
        return ListView.separated(
          itemCount: state.logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => _LogCard(log: state.logs[index]),
        );
      },
    );
  }
}

class _LogCard extends StatelessWidget {
  final NotificationLog log;

  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final isSent = log.status == NotificationLogStatus.sent;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.subject, style: AppTextStyles.bodyMd),
                const SizedBox(height: 2),
                Text('${log.channel.label} - ${log.recipientLabel}',
                    style: AppTextStyles.bodySm),
                if (!isSent && log.errorMessage != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.errorMessage!,
                    style:
                        AppTextStyles.bodySm.copyWith(color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isSent
                  ? AppColors.successContainer
                  : AppColors.errorContainer,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              isSent ? 'Envoye' : 'Echec',
              style: AppTextStyles.labelSm.copyWith(
                color: isSent
                    ? AppColors.onSuccessContainer
                    : AppColors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendTestEmailDialog extends StatefulWidget {
  const _SendTestEmailDialog();

  @override
  State<_SendTestEmailDialog> createState() => _SendTestEmailDialogState();
}

class _SendTestEmailDialogState extends State<_SendTestEmailDialog> {
  final _subjectController = TextEditingController(text: 'Email de test');
  final _messageController = TextEditingController(
    text: 'Ceci est un email de test pour verifier la configuration.',
  );

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NotificationBloc, NotificationState>(
      listenWhen: (previous, current) =>
          previous.sendTestStatus != current.sendTestStatus,
      listener: (context, state) {
        if (state.sendTestStatus == NotificationSendTestStatus.sent) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email de test envoye.')),
          );
        }
      },
      builder: (context, state) {
        final isSending =
            state.sendTestStatus == NotificationSendTestStatus.sending;
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.large)),
          title: const Text('Envoyer un email de test'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.sendTestStatus == NotificationSendTestStatus.error &&
                    state.sendTestFailure != null)
                  AppInlineAlert(message: state.sendTestFailure!.message),
                Text(
                  'Envoye a votre propre adresse, pour verifier que la configuration SMTP fonctionne.',
                  style: AppTextStyles.bodySm,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                    label: 'Sujet', hint: '', controller: _subjectController),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Message',
                  hint: '',
                  controller: _messageController,
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            AppPrimaryButton(
              label: 'Envoyer',
              isLoading: isSending,
              onPressed: () => context.read<NotificationBloc>().add(
                    NotificationTestEmailSendRequested(
                      subject: _subjectController.text.trim(),
                      message: _messageController.text.trim(),
                    ),
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationPreferencesPanel extends StatefulWidget {
  const _NotificationPreferencesPanel();

  @override
  State<_NotificationPreferencesPanel> createState() =>
      _NotificationPreferencesPanelState();
}

class _NotificationPreferencesPanelState
    extends State<_NotificationPreferencesPanel> {
  Set<String> _muted = {};
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>()
      ..add(const NotificationPreferencesLoadRequested())
      ..add(const NotificationTemplateListLoadRequested());
  }

  void _toggle(String templateId, bool muted) {
    setState(() {
      if (muted) {
        _muted.add(templateId);
      } else {
        _muted.remove(templateId);
      }
    });
    context.read<NotificationBloc>().add(
        NotificationMutedTemplateIdsSetRequested(
            mutedTemplateIds: _muted.toList()));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationBloc, NotificationState>(
      buildWhen: (previous, current) =>
          previous.preferencesStatus != current.preferencesStatus ||
          previous.preferences != current.preferences ||
          previous.templates != current.templates,
      builder: (context, state) {
        if (state.preferencesStatus == NotificationPreferencesStatus.loading &&
            state.preferences == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!_initialized && state.preferences != null) {
          _initialized = true;
          _muted = state.preferences!.mutedTemplateIds.toSet();
        }
        if (state.templates.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Aucun modele a configurer pour le moment.',
                style: AppTextStyles.bodyMd,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                'Desactivez les modeles dont vous ne voulez plus recevoir les emails. '
                'Les gestionnaires continuent de les recevoir dans tous les cas.',
                style: AppTextStyles.bodySm,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final template in state.templates)
              SwitchListTile(
                title: Text(template.name, style: AppTextStyles.bodyMd),
                subtitle: Text(
                  _muted.contains(template.id) ? 'Desactive' : 'Actif',
                  style: AppTextStyles.bodySm,
                ),
                value: !_muted.contains(template.id),
                onChanged: (receiving) => _toggle(template.id, !receiving),
              ),
          ],
        );
      },
    );
  }
}
