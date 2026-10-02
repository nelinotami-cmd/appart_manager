import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'core/di/service_locator.dart';
import 'core/env/env_config.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/company/presentation/bloc/company_bloc.dart';
import 'features/notification/domain/services/local_reminder_scheduler.dart';
import 'features/notification/presentation/bloc/notification_bloc.dart';
import 'features/subscription/presentation/bloc/subscription_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Removes the `#` from web URLs.
  usePathUrlStrategy();

  // Flavor selection.
  const flavorName = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  final flavor = switch (flavorName) {
    'preprod' => AppFlavor.preprod,
    'prod' => AppFlavor.prod,
    _ => AppFlavor.dev,
  };

  await EnvConfig.load(flavor);

  // Hydrated Bloc storage.
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorage.webStorageDirectory
        : await getApplicationDocumentsDirectory(),
  );

  await initServiceLocator();

  // Local notifications are not supported by
  // flutter_local_notifications on Web.
  //
  // Do not initialize or request notification permissions on Web,
  // otherwise native notification initialization can interfere with
  // application startup.
  if (!kIsWeb) {
    final localReminderScheduler = sl<LocalReminderScheduler>();

    await localReminderScheduler.initialize();
    await localReminderScheduler.requestPermission();
  }

  // Created once here so the router and widget tree use the same
  // AuthBloc instance.
  final authBloc = sl<AuthBloc>()..add(const AuthCheckRequested());
  final router = buildAppRouter(authBloc);

  runApp(
    AppartementsErpApp(
      authBloc: authBloc,
      router: router,
    ),
  );
}

class AppartementsErpApp extends StatelessWidget {
  final AuthBloc authBloc;
  final GoRouter router;

  const AppartementsErpApp({
    super.key,
    required this.authBloc,
    required this.router,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<CompanyBloc>(
          create: (_) => sl<CompanyBloc>(),
        ),
        BlocProvider<SubscriptionBloc>(
          create: (_) => sl<SubscriptionBloc>(),
        ),
        BlocProvider<NotificationBloc>(
          create: (_) => sl<NotificationBloc>(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Appartements ERP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) {
          return BlocBuilder<AuthBloc, AuthState>(
            bloc: authBloc,
            buildWhen: (previous, current) => previous.status != current.status,
            builder: (context, authState) {
              final isResolving = authState.status == AuthStatus.initial ||
                  authState.status == AuthStatus.loading;

              if (isResolving) {
                return const _LoadingOverlay();
              }

              return child ?? const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
