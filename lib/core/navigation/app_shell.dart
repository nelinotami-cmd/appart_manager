import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/company_users_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/company/presentation/pages/companies_list_page.dart';
import '../../features/company/presentation/pages/company_detail_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/subscription/presentation/pages/subscriptions_list_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'app_destination.dart';
import 'feature_placeholder_page.dart';

/// The app's single persistent navigation shell, hosting every major
/// feature (cahier des charges 5.2-5.11) behind one sidebar, with
/// Dashboard (5.11) as home. This is what every post-login/post-
/// registration flow now lands on, replacing the earlier
/// `TemporaryAuthenticatedHomePage` stand-in.
///
/// Search is contextual: the top bar owns one search field, but what it
/// searches (and whether it's even enabled) depends on the active
/// destination (`AppDestination.hasSearch`/`searchHint`) - most
/// destinations don't have a search behavior wired up yet (either
/// because the feature itself isn't built, or because it has no
/// meaningful search target), so the field simply disables itself rather
/// than silently doing nothing when typed into.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  late final List<AppDestination> _allDestinations = [
    AppDestination(
      id: 'dashboard',
      icon: Icons.dashboard_outlined,
      label: 'Tableau de bord',
      contentBuilder: (context, query) => const DashboardPage(),
    ),
    AppDestination(
      id: 'companies',
      icon: Icons.apartment_outlined,
      label: 'Entreprises',
      allowedRoles: {UserRole.admin, UserRole.superAdmin},
      hasSearch: true,
      searchHint: 'Rechercher une entreprise...',
      // Admin only has one company - skip the list entirely and go
      // straight to its detail view (the search field above is
      // effectively inert for Admin, since `CompanyDetailPage` has no use
      // for a query - a minor, accepted cosmetic tradeoff rather than
      // making `hasSearch` role-conditional for one destination).
      contentBuilder: (context, query) {
        // .read(), not .watch(): this closure runs mid-build, invoked from
        // AppShell's own build method rather than being a widget's build
        // method itself - AppShell's outer BlocBuilder already reactively
        // watches role changes (see its buildWhen), so this only ever
        // needs the current value, not a second independent subscription.
        final authState = context.read<AuthBloc>().state;
        if (authState.currentUser?.role == UserRole.admin) {
          final companyId = authState.currentUser?.companyId;
          if (companyId == null) return const SizedBox.shrink();
          return CompanyDetailContent(companyId: companyId);
        }
        return CompaniesListPage(searchQuery: query);
      },
    ),
    AppDestination(
      id: 'subscriptions',
      icon: Icons.workspace_premium_outlined,
      label: 'Abonnements',
      allowedRoles: {UserRole.superAdmin},
      hasSearch: true,
      searchHint: 'Rechercher un plan...',
      contentBuilder: (context, query) =>
          SubscriptionsListPage(searchQuery: query),
    ),
    AppDestination(
      id: 'notifications',
      icon: Icons.notifications_none_rounded,
      label: 'Notifications',
      contentBuilder: (context, query) => const FeaturePlaceholderPage(
        featureLabel: 'Notifications',
        cahierDesChargesSection: '5.4',
      ),
    ),
    AppDestination(
      id: 'services',
      icon: Icons.room_service_outlined,
      label: 'Services',
      allowedRoles: {UserRole.admin, UserRole.superAdmin},
      contentBuilder: (context, query) => const FeaturePlaceholderPage(
        featureLabel: 'Services',
        cahierDesChargesSection: '5.5',
      ),
    ),
    AppDestination(
      id: 'locations',
      icon: Icons.place_outlined,
      label: 'Localisations',
      allowedRoles: {
        UserRole.admin,
        UserRole.superAdmin,
        UserRole.gestionnaire
      },
      contentBuilder: (context, query) => const FeaturePlaceholderPage(
        featureLabel: 'Localisations',
        cahierDesChargesSection: '5.6',
      ),
    ),
    AppDestination(
      id: 'gestionnaires',
      icon: Icons.people_outline,
      label: 'Gestionnaires',
      allowedRoles: {UserRole.admin, UserRole.superAdmin},
      hasSearch: true,
      searchHint: 'Rechercher un gestionnaire par nom...',
      contentBuilder: (context, query) => CompanyUsersPage(searchQuery: query),
    ),
    AppDestination(
      id: 'bookings',
      icon: Icons.event_available_outlined,
      label: 'Reservations',
      contentBuilder: (context, query) => const FeaturePlaceholderPage(
        featureLabel: 'Reservations',
        cahierDesChargesSection: '5.8',
      ),
    ),
    AppDestination(
      id: 'discounts',
      icon: Icons.percent_outlined,
      label: 'Reductions',
      allowedRoles: {UserRole.admin, UserRole.superAdmin},
      contentBuilder: (context, query) => const FeaturePlaceholderPage(
        featureLabel: 'Reductions',
        cahierDesChargesSection: '5.9',
      ),
    ),
    AppDestination(
      id: 'tasks',
      icon: Icons.checklist_outlined,
      label: 'Taches',
      contentBuilder: (context, query) => const FeaturePlaceholderPage(
        featureLabel: 'Taches',
        cahierDesChargesSection: '5.10',
      ),
    ),
  ];

  List<AppDestination> _visibleDestinations(UserRole? role) =>
      _allDestinations.where((d) => d.isVisibleFor(role)).toList();

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se deconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Deconnexion'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    context.read<AuthBloc>().add(const AuthLogoutRequested());
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) =>
          previous.currentUser?.role != current.currentUser?.role,
      builder: (context, state) {
        final role = state.currentUser?.role;
        final destinations = _visibleDestinations(role);
        final selectedIndex = _selectedIndex.clamp(0, destinations.length - 1);
        final active = destinations[selectedIndex];

        final isWide = MediaQuery.of(context).size.width >= 900;

        final sidebar = _Sidebar(
          destinations: destinations,
          selectedIndex: selectedIndex,
          onSelected: (i) {
            _onDestinationSelected(i);
            if (!isWide) Navigator.of(context).pop(); // close the Drawer
          },
          onLogout: () => _logout(context),
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          drawer: isWide ? null : Drawer(child: sidebar),
          appBar: AppBar(
            leading: isWide
                ? null
                : Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
            titleSpacing: isWide ? AppSpacing.lg : null,
            title: _TopBarSearch(
              key: ValueKey(active.id),
              controller: _searchController,
              enabled: active.hasSearch,
              hint: active.searchHint ?? 'Recherche non disponible ici',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            actions: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Notifications (5.4) - pas encore construit.')),
                  );
                },
              ),
              const SizedBox(width: 4),
              _ProfileMenu(onLogout: () => _logout(context)),
              const SizedBox(width: AppSpacing.md),
            ],
          ),
          body: Row(
            children: [
              if (isWide) SizedBox(width: 260, child: sidebar),
              if (isWide)
                const VerticalDivider(
                    width: 1, color: AppColors.surfaceContainerHighest),
              Expanded(child: active.contentBuilder(context, _searchQuery)),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Appartements ERP', style: AppTextStyles.headlineSm),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: [
                for (var i = 0; i < destinations.length; i++)
                  _SidebarItem(
                    icon: destinations[i].icon,
                    label: destinations[i].label,
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceContainerHighest),
          // Logout: always last, deliberately visually separated from the
          // feature list above (destructive-adjacent action, not just
          // another destination) and already fully wired to AuthBloc.
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: _SidebarItem(
              icon: Icons.logout,
              label: 'Deconnexion',
              selected: false,
              onTap: onLogout,
              iconColor: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? AppColors.primaryContainer.withOpacity(0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.standard),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.standard),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: iconColor ??
                      (selected
                          ? AppColors.primaryContainer
                          : AppColors.outline),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  label,
                  style: AppTextStyles.bodySm.copyWith(
                    color: iconColor ??
                        (selected
                            ? AppColors.primaryContainer
                            : AppColors.onSurface),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarSearch extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String hint;
  final ValueChanged<String> onChanged;

  const _TopBarSearch({
    super.key,
    required this.controller,
    required this.enabled,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: TextField(
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        style: AppTextStyles.bodySm,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: AppColors.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  final VoidCallback onLogout;

  const _ProfileMenu({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) =>
          previous.currentUser != current.currentUser,
      builder: (context, state) {
        final name = state.currentUser?.fullName ?? '';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        return PopupMenuButton<String>(
          tooltip: 'Profil',
          onSelected: (value) {
            if (value == 'logout') onLogout();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Text(name, style: AppTextStyles.labelMd),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Deconnexion'),
                ],
              ),
            ),
          ],
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              initial,
              style: AppTextStyles.labelMd.copyWith(color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}
