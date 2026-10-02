import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/account_status.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

/// Read-only manager preview shown in the side panel opened from
/// `CompanyDetailContent`'s "Voir plus" link - deliberately NOT the full
/// `CompanyUsersPage`: no create/activate/delete actions live here at
/// all. "No gestionnaire action can be carried out outside of the
/// Gestionnaires tab" - this view exists purely to preview who's on the
/// team and hand off to the real management screen, via the single
/// "Aller a Gestionnaires" button, which closes this panel and switches
/// the shell to the actual `/gestionnaires` destination.
///
/// Shows name, phone and status only (no email, no row actions) - the
/// panel is narrow by design (a side overlay, not a full page), and a
/// dense read-only list is what actually fits it well.
class CompanyManagersPreview extends StatefulWidget {
  final String companyId;

  const CompanyManagersPreview({super.key, required this.companyId});

  @override
  State<CompanyManagersPreview> createState() => _CompanyManagersPreviewState();
}

class _CompanyManagersPreviewState extends State<CompanyManagersPreview> {
  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>()
      ..add(AuthCompanyUsersLoadRequested(companyId: widget.companyId))
      ..add(AuthCompanyUsersWatchStarted(companyId: widget.companyId));
  }

  @override
  void dispose() {
    context.read<AuthBloc>().add(const AuthCompanyUsersWatchStopped());
    super.dispose();
  }

  void _goToGestionnaires(BuildContext context) {
    Navigator.of(context).pop();
    context.go(AppRoutes.gestionnaires);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      state.companyUsersFailure?.message ??
                          'Une erreur est survenue.',
                      style: AppTextStyles.bodyMd,
                    ),
                  ),
                );
              }
              if (state.companyUsers.isEmpty) {
                return Center(
                  child: Text('Aucun Gestionnaire pour le moment',
                      style: AppTextStyles.bodyMd),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: state.companyUsers.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, color: AppColors.surfaceContainerHighest),
                itemBuilder: (context, index) =>
                    _ManagerRow(user: state.companyUsers[index]),
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
              child: FilledButton.icon(
                onPressed: () => _goToGestionnaires(context),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Aller a Gestionnaires'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ManagerRow extends StatelessWidget {
  final UserProfile user;

  const _ManagerRow({required this.user});

  /// A handful of distinct, saturated colors that read well with white
  /// text - picked deterministically from the user's id (not
  /// `Random()`), so each manager keeps the same "profile picture"
  /// color across rebuilds/reopenings instead of reshuffling every time.
  static const _avatarPalette = [
    Color(0xFF3F51B5),
    Color(0xFF009688),
    Color(0xFFE91E63),
    Color(0xFF8E24AA),
    Color(0xFFF4511E),
    Color(0xFF00897B),
    Color(0xFF3949AB),
    Color(0xFFD81B60),
    Color(0xFF6D4C41),
    Color(0xFF546E7A),
  ];

  Color get _avatarColor =>
      _avatarPalette[user.id.hashCode.abs() % _avatarPalette.length];

  String get _initial =>
      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    final isActive = user.status == AccountStatus.active;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _avatarColor,
            child: Text(
              _initial,
              style: AppTextStyles.labelMd.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: AppTextStyles.bodyMd),
                const SizedBox(height: 2),
                Text(user.phone, style: AppTextStyles.bodySm),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.successContainer
                  : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              isActive ? 'Actif' : 'Inactif',
              style: AppTextStyles.labelSm.copyWith(
                color: isActive
                    ? AppColors.onSuccessContainer
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
