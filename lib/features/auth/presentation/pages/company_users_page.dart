import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/account_status.dart';
import '../../domain/entities/user_profile.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Admin/Super Admin content: list/search Gestionnaires of a company,
/// with realtime updates (cahier des charges 5.7).
///
/// Two usages:
/// - Rendered at `/gestionnaires` inside `AppShell`'s ShellRoute (no own
///   `Scaffold`/`AppBar`/search field; the shell's top bar owns search
///   via `SearchScope`) - [companyId] left `null`, defaults to the
///   current user's own company (the normal Admin case).
/// - Opened via `showSidePanel` from `CompanyDetailContent`'s manager
///   count/"voir plus" link (Super Admin viewing an arbitrary company) -
///   [companyId] passed explicitly, [showHeader] left `true` so this
///   renders its own title/search inside the panel instead of relying on
///   `AppShell`'s.
///
/// "Nouveau" (create) is only shown when [companyId] resolves to the
/// viewer's OWN company - `auth.create-gestionnaire-account` is
/// Admin-only and always creates within the caller's own company, so a
/// Super Admin viewing someone else's company would just get a 403;
/// showing the button there would be non-functional, not just
/// restricted.
class CompanyUsersPage extends StatefulWidget {
  final String searchQuery;
  final String? companyId;
  final bool showHeader;

  const CompanyUsersPage({
    super.key,
    this.searchQuery = '',
    this.companyId,
    this.showHeader = true,
  });

  @override
  State<CompanyUsersPage> createState() => _CompanyUsersPageState();
}

class _CompanyUsersPageState extends State<CompanyUsersPage> {
  String? _companyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final companyId = widget.companyId ??
        context.read<AuthBloc>().state.currentUser?.companyId;
    if (companyId != null && companyId != _companyId) {
      _companyId = companyId;
      context.read<AuthBloc>()
        ..add(AuthCompanyUsersLoadRequested(companyId: companyId))
        ..add(AuthCompanyUsersWatchStarted(companyId: companyId));
    }
  }

  @override
  void didUpdateWidget(covariant CompanyUsersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _dispatchSearch(widget.searchQuery);
    }
  }

  @override
  void dispose() {
    context.read<AuthBloc>().add(const AuthCompanyUsersWatchStopped());
    super.dispose();
  }

  void _dispatchSearch(String query) {
    final companyId = _companyId;
    if (companyId == null) return;
    if (query.trim().isEmpty) {
      context
          .read<AuthBloc>()
          .add(AuthCompanyUsersLoadRequested(companyId: companyId));
    } else {
      context.read<AuthBloc>().add(AuthCompanyUsersSearchRequested(
          companyId: companyId, query: query.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnCompany = _companyId != null &&
        _companyId == context.read<AuthBloc>().state.currentUser?.companyId;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Gestionnaires', style: AppTextStyles.headlineSm),
                if (isOwnCompany)
                  FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.gestionnaireNew),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nouveau'),
                  ),
              ],
            )
          else if (isOwnCompany)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => context.push(AppRoutes.gestionnaireNew),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau'),
              ),
            ),
          if (widget.showHeader || isOwnCompany)
            const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: BlocBuilder<AuthBloc, AuthState>(
              buildWhen: (previous, current) =>
                  previous.companyUsersStatus != current.companyUsersStatus ||
                  previous.companyUsers != current.companyUsers,
              builder: (context, state) {
                if (state.companyUsersStatus == CompanyUsersStatus.loading &&
                    state.companyUsers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.companyUsersStatus == CompanyUsersStatus.error &&
                    state.companyUsers.isEmpty) {
                  return Center(
                    child: Text(
                      state.companyUsersFailure?.message ??
                          'Une erreur est survenue.',
                      style: AppTextStyles.bodyMd,
                    ),
                  );
                }
                if (state.companyUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 40, color: AppColors.outline),
                        const SizedBox(height: AppSpacing.md),
                        Text('Aucun Gestionnaire pour le moment',
                            style: AppTextStyles.bodyMd),
                        if (isOwnCompany) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Cliquez sur "Nouveau" pour creer le premier compte.',
                            style: AppTextStyles.bodySm,
                          ),
                        ],
                      ],
                    ),
                  );
                }
                return _UsersTable(users: state.companyUsers);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersTable extends StatelessWidget {
  final List<UserProfile> users;

  const _UsersTable({required this.users});

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
                    flex: 3, child: Text('NOM', style: AppTextStyles.labelSm)),
                Expanded(
                    flex: 3,
                    child: Text('EMAIL', style: AppTextStyles.labelSm)),
                Expanded(
                    flex: 2,
                    child: Text('TELEPHONE', style: AppTextStyles.labelSm)),
                Expanded(
                    flex: 2,
                    child: Text('STATUT', style: AppTextStyles.labelSm)),
                const SizedBox(width: 96),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1, color: AppColors.surfaceContainerHighest),
              itemBuilder: (context, index) => _UserRow(user: users[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final UserProfile user;

  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final isActive = user.status == AccountStatus.active;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
              flex: 3, child: Text(user.fullName, style: AppTextStyles.bodySm)),
          Expanded(
              flex: 3, child: Text(user.email, style: AppTextStyles.bodySm)),
          Expanded(
              flex: 2, child: Text(user.phone, style: AppTextStyles.bodySm)),
          Expanded(flex: 2, child: _StatusBadge(isActive: isActive)),
          SizedBox(
            width: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: isActive ? 'Desactiver' : 'Reactiver',
                  icon: Icon(
                    isActive ? Icons.toggle_on : Icons.toggle_off_outlined,
                    color: isActive
                        ? AppColors.primaryContainer
                        : AppColors.outline,
                  ),
                  onPressed: () => context.read<AuthBloc>().add(
                        AuthUpdateAccountStatusRequested(
                          userId: user.id,
                          status: isActive
                              ? AccountStatus.inactive
                              : AccountStatus.active,
                        ),
                      ),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.error),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<AuthBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce Gestionnaire ?'),
        content: Text(
          '${user.fullName} perdra definitivement acces a la plateforme. '
          'Cette action est irreversible.',
          style: AppTextStyles.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(AuthDeleteGestionnaireRequested(userId: user.id));
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
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
