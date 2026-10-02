import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/user_role.dart';

/// Describes one sidebar entry (cahier des charges 5.2-5.11, plus the
/// 5.11 Dashboard as home).
///
/// Content is no longer built here directly - [path] is a real go_router
/// route inside `AppRouter`'s route tree, and GoRouter itself decides
/// which widget to render for the current URL. This class exists purely
/// to drive the sidebar UI: which icon/label to show, which roles see
/// it, and which URL tapping it navigates to (`context.go(path)`).
class AppDestination {
  final String id;
  final IconData icon;
  final String label;
  final String path;

  /// `null` = visible to every role. Non-null = only these roles see it
  /// in the sidebar at all (server-side authorization is enforced
  /// independently by each feature's own backend - this is purely about
  /// not showing a Gestionnaire a menu item that would just 403 them).
  final Set<UserRole>? allowedRoles;

  /// Whether the top bar's search field applies to this destination at
  /// all. When `false`, the search field is disabled while this
  /// destination is active (see `AppShell`).
  final bool hasSearch;
  final String? searchHint;

  const AppDestination({
    required this.id,
    required this.icon,
    required this.label,
    required this.path,
    this.allowedRoles,
    this.hasSearch = false,
    this.searchHint,
  });

  bool isVisibleFor(UserRole? role) {
    if (allowedRoles == null) return true;
    if (role == null) return false;
    return allowedRoles!.contains(role);
  }

  /// Whether [location] (the current route's URL) belongs to this
  /// destination, for sidebar highlighting. Matches the destination's own
  /// path and any of its sub-paths (e.g. `/companies/abc123` still
  /// highlights the "Entreprises" item whose path is `/companies`), but
  /// not another destination's path that happens to share a prefix.
  bool matches(String location) {
    if (location == path) return true;
    return location.startsWith('$path/');
  }
}
