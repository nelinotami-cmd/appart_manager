import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/notification/presentation/widgets/notification_bell_panel.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'app_destination.dart';
import 'app_router.dart';
import 'side_panel.dart';

/// The app's single persistent navigation shell, hosting every major
/// feature (cahier des charges 5.2-5.11) behind one sidebar, with
/// Dashboard (5.11) as home.
///
/// Rendered by a `ShellRoute` in `app_router.dart` - [child] is whichever
/// nested route matched the current URL, and [currentLocation] is that
/// URL itself, used to highlight the right sidebar item and derive the
/// active destination's search behavior. Tapping a sidebar item calls
/// `context.go(destination.path)` - the URL actually changes, so the
/// browser's address bar, back/forward buttons, and refresh all reflect
/// real app state.
class AppShell extends StatefulWidget {
  final Widget child;
  final String currentLocation;
  final ValueNotifier<String> searchNotifier;

  const AppShell({
    super.key,
    required this.child,
    required this.currentLocation,
    required this.searchNotifier,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _searchController = TextEditingController();

  static final List<AppDestination> _allDestinations = [
    AppDestination(
      id: 'dashboard',
      icon: Icons.dashboard_outlined,
      label: 'Tableau de bord',
      path: AppRoutes.dashboard,
    ),
    AppDestination(
      id: 'companies',
      icon: Icons.apartment_outlined,
      label: 'Entreprises',
      path: AppRoutes.companies,
      allowedRoles: {UserRole.admin, UserRole.superAdmin},
      hasSearch: true,
      searchHint: 'Rechercher une entreprise...',
    ),
    AppDestination(
      id: 'subscriptions',
      icon: Icons.workspace_premium_outlined,
      label: 'Abonnements',
      path: AppRoutes.subscriptions,
      allowedRoles: {UserRole.superAdmin},
      hasSearch: true,
      searchHint: 'Rechercher un plan...',
    ),
    AppDestination(
      id: 'notifications',
      icon: Icons.notifications_none_rounded,
      label: 'Notifications',
      path: AppRoutes.notifications,
    ),
    AppDestination(
      id: 'services',
      icon: Icons.room_service_outlined,
      label: 'Services',
      path: AppRoutes.services,
      allowedRoles: {UserRole.admin, UserRole.superAdmin},
    ),
    AppDestination(
      id: 'locations',
      icon: Icons.place_outlined,
      label: 'Localisations',
      path: AppRoutes.locations,
      allowedRoles: {
        UserRole.admin,
        UserRole.superAdmin,
        UserRole.gestionnaire
      },
    ),
    AppDestination(
      id: 'gestionnaires',
      icon: Icons.people_outline,
      label: 'Gestionnaires',
      path: AppRoutes.gestionnaires,
      allowedRoles: {UserRole.admin, UserRole.superAdmin},
      hasSearch: true,
      searchHint: 'Rechercher un gestionnaire par nom...',
    ),
    AppDestination(
      id: 'bookings',
      icon: Icons.event_available_outlined,
      label: 'Reservations',
      path: AppRoutes.bookings,
    ),
    AppDestination(
      id: 'discounts',
      icon: Icons.percent_outlined,
      label: 'Reductions',
      path: AppRoutes.discounts,
      allowedRoles: {UserRole.admin, UserRole.superAdmin},
    ),
    AppDestination(
      id: 'tasks',
      icon: Icons.checklist_outlined,
      label: 'Taches',
      path: AppRoutes.tasks,
    ),
  ];

  List<AppDestination> _visibleDestinations(UserRole? role) =>
      _allDestinations.where((d) => d.isVisibleFor(role)).toList();

  /// The destination whose path matches (or is a parent of) the current
  /// URL - e.g. `/companies/abc123` still highlights "Entreprises" (whose
  /// own path is `/companies`). Falls back to the first visible
  /// destination if nothing matches (shouldn't normally happen, since
  /// every real route lives under some destination's path).
  AppDestination _activeDestination(List<AppDestination> destinations) {
    for (final d in destinations) {
      if (d.matches(widget.currentLocation)) return d;
    }
    return destinations.first;
  }

  void _onDestinationSelected(
      BuildContext context, AppDestination destination) {
    widget.searchNotifier.value = '';
    _searchController.clear();
    context.go(destination.path);
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
    // No explicit navigation needed here: AuthBloc emitting
    // `unauthenticated` fires the router's `refreshListenable`, and
    // `redirect` sends us to /login on its own.
  }

  /// Bottom sheet on mobile, side panel on wide - matching the same
  /// responsive rule `showSidePanel` itself already applies internally,
  /// but the bell specifically needs a bottom sheet (not a full-screen
  /// page) on mobile, so this doesn't just delegate to `showSidePanel`
  /// for both cases.
  void _openNotificationBell(BuildContext context, bool isWide) {
    void seeAll() {
      Navigator.of(context).pop();
      context.go(AppRoutes.notifications);
    }

    if (isWide) {
      showSidePanel(
        context: context,
        title: 'Notifications',
        contentBuilder: (_) => NotificationBellPanel(onSeeAll: seeAll),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: NotificationBellPanel(onSeeAll: seeAll),
      ),
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
        final active = _activeDestination(destinations);

        final isWide = MediaQuery.of(context).size.width >= 900;

        final sidebar = _Sidebar(
          destinations: destinations,
          active: active,
          onSelected: (d) {
            _onDestinationSelected(context, d);
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
              onChanged: (value) =>
                  setState(() => widget.searchNotifier.value = value),
            ),
            actions: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () => _openNotificationBell(context, isWide),
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
              Expanded(child: widget.child),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<AppDestination> destinations;
  final AppDestination active;
  final ValueChanged<AppDestination> onSelected;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.destinations,
    required this.active,
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
                for (final destination in destinations)
                  _SidebarItem(
                    icon: destination.icon,
                    label: destination.label,
                    selected: destination.id == active.id,
                    onTap: () => onSelected(destination),
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
