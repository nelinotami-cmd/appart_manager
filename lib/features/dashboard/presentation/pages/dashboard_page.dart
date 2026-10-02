import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Cahier des charges 5.11: "Dashboards - Super Admin, Admin entreprise,
/// Gestionnaire." Content is deliberately minimal for now (a welcome
/// card, not the full per-role metrics/quick-actions the spec describes)
/// since those metrics come from features that don't exist yet
/// (bookings, tasks, subscriptions) - this gives the shell a real home
/// instead of another placeholder, and should grow into the actual
/// per-role dashboard content as 5.3/5.8/5.9/5.10 land.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state.currentUser;
        final roleLabel = switch (user?.role) {
          UserRole.superAdmin => 'Super Admin',
          UserRole.admin => 'Admin entreprise',
          UserRole.gestionnaire => 'Gestionnaire',
          null => '',
        };
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bonjour, ${user?.fullName ?? ''}', style: AppTextStyles.headlineMd),
              const SizedBox(height: 4),
              Text(roleLabel, style: AppTextStyles.bodySm),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(color: AppColors.surfaceContainerHighest),
                ),
                child: Row(
                  children: [
                    Icon(Icons.dashboard_outlined, color: AppColors.outline),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Les indicateurs par role (occupation, reservations en '
                        'cours, taches du jour, ...) arriveront au fur et a '
                        'mesure que les modules correspondants seront '
                        'construits.',
                        style: AppTextStyles.bodySm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
