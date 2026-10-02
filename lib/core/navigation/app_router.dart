import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/company_users_page.dart';
import '../../features/auth/presentation/pages/create_gestionnaire_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_request_page.dart';
import '../../features/auth/presentation/pages/otp_verify_reset_password_page.dart';
import '../../features/auth/presentation/pages/register_company_page.dart';
import '../../features/company/presentation/pages/companies_list_page.dart';
import '../../features/company/presentation/pages/company_detail_page.dart';
import '../../features/company/presentation/pages/edit_company_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/notification/presentation/pages/configure_notification_template_page.dart';
import '../../features/notification/presentation/pages/notifications_page.dart';
import '../../features/subscription/presentation/pages/configure_subscription_page.dart';
import '../../features/subscription/presentation/pages/subscription_detail_page.dart';
import '../../features/subscription/presentation/pages/subscriptions_list_page.dart';
import 'app_shell.dart';
import 'feature_placeholder_page.dart';
import 'search_scope.dart';

/// Every real route path in the app, named centrally so no page ever
/// hand-writes a path string. Two kinds of members here:
/// - Bare `String` constants for routes with no parameters.
/// - Functions (`companyDetail(id)`, ...) that build a concrete,
///   navigable path with a real id substituted in - used at
///   `context.go`/`context.push` call sites. The route *definitions* in
///   [buildAppRouter] below use the literal `:paramName` go_router syntax
///   instead, which is a different (related but not identical) string.
class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const registerCompany = '/register-company';
  static const passwordResetRequest = '/password-reset/request';
  static const passwordResetVerify = '/password-reset/verify';

  static const dashboard = '/dashboard';
  static const companies = '/companies';
  static String companyDetail(String id) => '/companies/$id';
  static String companyEdit(String id) => '/companies/$id/edit';

  static const subscriptions = '/subscriptions';
  static const subscriptionNew = '/subscriptions/new';
  static String subscriptionDetail(String id) => '/subscriptions/$id';
  static String subscriptionEdit(String id) => '/subscriptions/$id/edit';

  static const notifications = '/notifications';
  static const notificationTemplateNew = '/notifications/new';
  static String notificationTemplateEdit(String id) =>
      '/notifications/$id/edit';
  static const services = '/services';
  static const locations = '/locations';
  static const gestionnaires = '/gestionnaires';
  static const gestionnaireNew = '/gestionnaires/new';
  static const bookings = '/bookings';
  static const discounts = '/discounts';
  static const tasks = '/tasks';

  static const _publicPaths = {
    login,
    registerCompany,
    passwordResetRequest,
    passwordResetVerify,
  };

  static bool isPublic(String location) => _publicPaths.any(
        (p) => location == p || location.startsWith('$p?'),
      );
}

/// Bridges a Bloc's `Stream` to go_router's `refreshListenable`, so the
/// router re-evaluates `redirect` every time auth state changes (login,
/// logout, the initial session check completing) - the standard pattern
/// from go_router's own documentation for Bloc/Stream-backed auth
/// gating, since `GoRouter` otherwise only re-evaluates `redirect` on
/// navigation, not on arbitrary app state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Builds the app's single [GoRouter].
///
/// [authBloc] must be the SAME instance provided to the widget tree via
/// `BlocProvider<AuthBloc>.value` in `main.dart` - the router is
/// constructed once, before the widget tree exists, so `redirect` needs a
/// direct reference to react to auth state rather than a `context`
/// lookup (which isn't available yet at router-construction time).
GoRouter buildAppRouter(AuthBloc authBloc) {
  // Owned by the router closure, not any single widget: AppShell reads
  // and updates this on every keystroke in its top-bar search field; any
  // route rendered inside the shell reads the current value via
  // `SearchScope.of(context)` in its own `builder` below. Cleared back to
  // empty by `AppShell` whenever the selected destination changes (see
  // its own source) so switching sections doesn't leak a stale query.
  final searchNotifier = ValueNotifier<String>('');

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final location = state.matchedLocation;

      // Auth status still being established (cold start / warm-start
      // revalidation with no cached user): deliberately do NOT redirect
      // anywhere here. A loading state is not a "place" in the app - it
      // has no business being a URL, bookmarkable, or something the back
      // button can land on. Whatever location we're already at (or
      // `initialLocation` on a cold start) stays exactly as-is in the
      // address bar; `main.dart`'s `MaterialApp.builder` shows a loading
      // overlay purely visually, in place, until this resolves - then
      // `refreshListenable` fires again and this callback re-evaluates
      // for real.
      if (authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.loading) {
        return null;
      }

      final isAuthenticated = authState.isAuthenticated;
      final isPublicRoute = AppRoutes.isPublic(location);

      if (!isAuthenticated && !isPublicRoute) return AppRoutes.login;
      if (isAuthenticated && isPublicRoute) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginPage()),
      GoRoute(
        path: AppRoutes.registerCompany,
        builder: (context, state) => const RegisterCompanyPage(),
      ),
      GoRoute(
        path: AppRoutes.passwordResetRequest,
        builder: (context, state) => const OtpRequestPage(),
      ),
      GoRoute(
        path: AppRoutes.passwordResetVerify,
        builder: (context, state) => OtpVerifyResetPasswordPage(
          identifier: state.uri.queryParameters['identifier'] ?? '',
        ),
      ),

      // Persistent-sidebar section - every route below stays inside
      // AppShell (sidebar + top bar never unmount while navigating
      // between them) - INCLUDING create/edit sub-pages
      // (companies/:id/edit, subscriptions/new, subscriptions/:id/edit,
      // gestionnaires/new): these used to be standalone full-screen
      // routes outside the shell, which hid the sidebar entirely on wide
      // screens - wrong, the sidebar must stay visible everywhere once
      // authenticated, matching how "Entreprises" and every other
      // destination already behaves. Each of these pages still has its
      // own Scaffold/AppBar/back-button for its own sub-title, which now
      // renders inside AppShell's content area rather than replacing the
      // whole screen.
      ShellRoute(
        builder: (context, state, child) => AppShell(
          currentLocation: state.matchedLocation,
          searchNotifier: searchNotifier,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/companies/:companyId/edit',
            builder: (context, state) => EditCompanyPage(
              companyId: state.pathParameters['companyId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.subscriptionNew,
            builder: (context, state) => const ConfigureSubscriptionPage(),
          ),
          GoRoute(
            path: '/subscriptions/:planId/edit',
            builder: (context, state) => ConfigureSubscriptionPage(
              planId: state.pathParameters['planId'],
            ),
          ),
          GoRoute(
            path: AppRoutes.gestionnaireNew,
            builder: (context, state) => const CreateGestionnairePage(),
          ),
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.companies,
            builder: (context, state) {
              // Admin only has one company - skip the list entirely and
              // go straight to its detail view (no search behavior for
              // this case; the search field stays visually present but
              // effectively inert, an accepted minor cosmetic tradeoff).
              final authState = context.read<AuthBloc>().state;
              if (authState.currentUser?.role == UserRole.admin) {
                final companyId = authState.currentUser?.companyId;
                if (companyId == null) return const SizedBox.shrink();
                return CompanyDetailContent(companyId: companyId);
              }
              return CompaniesListPage(searchQuery: SearchScope.of(context));
            },
          ),
          GoRoute(
            path: '/companies/:companyId',
            builder: (context, state) => CompanyDetailContent(
              companyId: state.pathParameters['companyId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.subscriptions,
            builder: (context, state) =>
                SubscriptionsListPage(searchQuery: SearchScope.of(context)),
          ),
          GoRoute(
            path: '/subscriptions/:planId',
            builder: (context, state) => SubscriptionDetailPage(
              planId: state.pathParameters['planId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.gestionnaires,
            builder: (context, state) =>
                CompanyUsersPage(searchQuery: SearchScope.of(context)),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: AppRoutes.notificationTemplateNew,
            builder: (context, state) =>
                const ConfigureNotificationTemplatePage(),
          ),
          GoRoute(
            path: '/notifications/:templateId/edit',
            builder: (context, state) => ConfigureNotificationTemplatePage(
              templateId: state.pathParameters['templateId'],
            ),
          ),
          GoRoute(
            path: AppRoutes.services,
            builder: (context, state) => const FeaturePlaceholderPage(
              featureLabel: 'Services',
              cahierDesChargesSection: '5.5',
            ),
          ),
          GoRoute(
            path: AppRoutes.locations,
            builder: (context, state) => const FeaturePlaceholderPage(
              featureLabel: 'Localisations',
              cahierDesChargesSection: '5.6',
            ),
          ),
          GoRoute(
            path: AppRoutes.bookings,
            builder: (context, state) => const FeaturePlaceholderPage(
              featureLabel: 'Reservations',
              cahierDesChargesSection: '5.8',
            ),
          ),
          GoRoute(
            path: AppRoutes.discounts,
            builder: (context, state) => const FeaturePlaceholderPage(
              featureLabel: 'Reductions',
              cahierDesChargesSection: '5.9',
            ),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            builder: (context, state) => const FeaturePlaceholderPage(
              featureLabel: 'Taches',
              cahierDesChargesSection: '5.10',
            ),
          ),
        ],
      ),
    ],
  );
}
