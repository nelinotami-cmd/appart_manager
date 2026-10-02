import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/notification_channel.dart';
import '../../domain/entities/notification_log.dart';
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';

/// Content for the app-bar notification bell: a paginated scroll of
/// `NotificationLog` entries with a "Voir tout" button at the bottom.
/// Container-agnostic on purpose - `AppShell` decides whether this shows
/// inside a `showModalBottomSheet` (mobile) or a `showSidePanel` (wide);
/// this widget only knows how to render and paginate the list itself.
class NotificationBellPanel extends StatefulWidget {
  final VoidCallback onSeeAll;

  const NotificationBellPanel({super.key, required this.onSeeAll});

  @override
  State<NotificationBellPanel> createState() => _NotificationBellPanelState();
}

class _NotificationBellPanelState extends State<NotificationBellPanel> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context
        .read<NotificationBloc>()
        .add(const NotificationLogListLoadRequested());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      context
          .read<NotificationBloc>()
          .add(const NotificationLogListLoadMoreRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: BlocBuilder<NotificationBloc, NotificationState>(
            buildWhen: (previous, current) =>
                previous.logsStatus != current.logsStatus ||
                previous.logs != current.logs,
            builder: (context, state) {
              if (state.logsStatus == NotificationLogsStatus.loading &&
                  state.logs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (state.logsStatus == NotificationLogsStatus.error &&
                  state.logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    state.logsFailure?.message ?? 'Une erreur est survenue.',
                    style: AppTextStyles.bodyMd,
                  ),
                );
              }
              if (state.logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text('Aucune notification pour le moment',
                      style: AppTextStyles.bodyMd),
                );
              }
              return ListView.separated(
                controller: _scrollController,
                shrinkWrap: true,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: state.logs.length + (state.logsHasMore ? 1 : 0),
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index >= state.logs.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  return _BellLogRow(log: state.logs[index]);
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onSeeAll,
                child: const Text('Voir tout'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BellLogRow extends StatelessWidget {
  final NotificationLog log;

  const _BellLogRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final isSent = log.status == NotificationLogStatus.sent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isSent ? Icons.check_circle_outline : Icons.error_outline,
          size: 18,
          color: isSent ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(log.subject, style: AppTextStyles.bodyMd),
              const SizedBox(height: 2),
              Text('${log.channel.label} - ${log.recipientLabel}',
                  style: AppTextStyles.bodySm),
            ],
          ),
        ),
      ],
    );
  }
}
