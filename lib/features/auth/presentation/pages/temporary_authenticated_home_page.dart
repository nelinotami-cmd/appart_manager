import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/user_role.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'login_page.dart';

/// TEMPORARY landing page shown right after a successful login or
/// registration. Cahier des charges 5.11 (dashboards) isn't built yet -
/// this exists only so the Login/Register flows have somewhere real to
/// navigate to instead of a dead end, and should be deleted/replaced the
/// moment a real per-role dashboard lands.
class TemporaryAuthenticatedHomePage extends StatelessWidget {
  static const routeName = '/home';

  const TemporaryAuthenticatedHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Appartements ERP'),
        actions: [
          IconButton(
            tooltip: 'Deconnexion',
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final user = state.currentUser;
          final roleLabel = switch (user?.role) {
            UserRole.superAdmin => 'Super Admin',
            UserRole.admin => 'Admin entreprise',
            UserRole.gestionnaire => 'Gestionnaire',
            null => '...',
          };
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.construction_rounded, size: 40, color: AppColors.outline),
                  const SizedBox(height: 16),
                  Text('Connecte(e)', style: AppTextStyles.headlineSm),
                  const SizedBox(height: 8),
                  Text(
                    '${user?.fullName ?? ''} - $roleLabel',
                    style: AppTextStyles.bodyMd,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Le tableau de bord (5.11) n\'est pas encore construit -\n'
                    'cette page est un placeholder temporaire.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySm,
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
