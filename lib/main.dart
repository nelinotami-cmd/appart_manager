import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'core/di/service_locator.dart';
import 'core/env/env_config.dart';
import 'core/navigation/app_shell.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/company/presentation/bloc/company_bloc.dart';
import 'features/subscription/presentation/bloc/subscription_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flavor selection: pass `--dart-define=FLAVOR=preprod` (or `prod`) at
  // build time; defaults to dev for local runs.
  const flavorName = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  final flavor = switch (flavorName) {
    'preprod' => AppFlavor.preprod,
    'prod' => AppFlavor.prod,
    _ => AppFlavor.dev,
  };

  await EnvConfig.load(flavor);

  // hydrated_bloc ^9.1.5 (pinned in pubspec.yaml) exposes
  // `HydratedStorage.webStorageDirectory` for web and expects a plain
  // `Directory` otherwise. The `HydratedStorageDirectory` wrapper class
  // used in some hydrated_bloc examples online is a 10.x-only API - do
  // not use it unless pubspec.yaml is bumped to `hydrated_bloc: ^10.0.0`
  // (and flutter_bloc/bloc bumped to a matching major version too).
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorage.webStorageDirectory
        : await getApplicationDocumentsDirectory(),
  );

  await initServiceLocator();

  runApp(const AppartementsErpApp());
}

class AppartementsErpApp extends StatelessWidget {
  const AppartementsErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>()..add(const AuthCheckRequested()),
        ),
        BlocProvider<CompanyBloc>(create: (_) => sl<CompanyBloc>()),
        BlocProvider<SubscriptionBloc>(create: (_) => sl<SubscriptionBloc>()),
        // Additional feature Blocs are registered here as they are
        // generated (locations, meubles, ...).
      ],
      child: MaterialApp(
        title: 'Appartements ERP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _AuthGate(),
      ),
    );
  }
}

/// Root splash/routing gate: waits for `AuthCheckRequested` (dispatched
/// once above) to resolve, then shows `LoginPage` or the (temporary)
/// authenticated landing page accordingly. `HydratedBloc` may already
/// have restored a cached `currentUser` before the network check
/// completes - that's used here to skip the spinner on a likely-valid
/// warm start, while `AuthCheckRequested`'s own result is still what
/// ultimately decides `authenticated` vs `unauthenticated`.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) {
        return switch (state.status) {
          AuthStatus.authenticated => const AppShell(),
          AuthStatus.unauthenticated || AuthStatus.error => const LoginPage(),
          AuthStatus.initial || AuthStatus.loading => const _SplashScreen(),
        };
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
