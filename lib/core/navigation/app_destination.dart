import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/user_role.dart';

/// Describes one sidebar entry (cahier des charges 5.2-5.11, plus the
/// 5.11 Dashboard as home). `AppShell` is the only place these are
/// assembled into the actual nav list - this class just describes one.
class AppDestination {
  final String id;
  final IconData icon;
  final String label;

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

  /// Builds this destination's content area. Receives the current search
  /// query (empty string if `hasSearch` is false or nothing typed yet) -
  /// most placeholder destinations simply ignore it.
  final Widget Function(BuildContext context, String searchQuery) contentBuilder;

  const AppDestination({
    required this.id,
    required this.icon,
    required this.label,
    required this.contentBuilder,
    this.allowedRoles,
    this.hasSearch = false,
    this.searchHint,
  });

  bool isVisibleFor(UserRole? role) {
    if (allowedRoles == null) return true;
    if (role == null) return false;
    return allowedRoles!.contains(role);
  }
}
