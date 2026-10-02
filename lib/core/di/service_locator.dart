import 'package:appwrite/appwrite.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../env/env_config.dart';

import '../../features/auth/data/datasources/auth_account_remote_datasource.dart';
import '../../features/auth/data/datasources/auth_functions_remote_datasource.dart';
import '../../features/auth/data/datasources/user_profile_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/create_gestionnaire_account_usecase.dart';
import '../../features/auth/domain/usecases/delete_gestionnaire_account_usecase.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/get_user_profile_by_id_usecase.dart';
import '../../features/auth/domain/usecases/list_user_profiles_by_company_usecase.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/register_company_and_admin_usecase.dart';
import '../../features/auth/domain/usecases/request_password_reset_otp_usecase.dart';
import '../../features/auth/domain/usecases/search_user_profiles_usecase.dart';
import '../../features/auth/domain/usecases/update_account_status_usecase.dart';
import '../../features/auth/domain/usecases/verify_otp_and_reset_password_usecase.dart';
import '../../features/auth/domain/usecases/watch_user_profiles_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

import '../../features/company/data/datasources/company_functions_remote_datasource.dart';
import '../../features/company/data/datasources/company_remote_datasource.dart';
import '../../features/company/data/repositories/company_repository_impl.dart';
import '../../features/company/domain/repositories/company_repository.dart';
import '../../features/company/domain/usecases/assign_subscription_plan_usecase.dart';
import '../../features/company/domain/usecases/get_company_by_id_usecase.dart';
import '../../features/company/domain/usecases/list_companies_by_plan_id_usecase.dart';
import '../../features/company/domain/usecases/list_companies_usecase.dart';
import '../../features/company/domain/usecases/search_companies_usecase.dart';
import '../../features/company/domain/usecases/update_company_profile_usecase.dart';
import '../../features/company/domain/usecases/update_company_status_usecase.dart';
import '../../features/company/domain/usecases/watch_companies_usecase.dart';
import '../../features/company/presentation/bloc/company_bloc.dart';

import '../../features/notification/data/services/local_reminder_scheduler_impl.dart';
import '../../features/notification/domain/services/local_reminder_scheduler.dart';

import '../../features/subscription/data/datasources/subscription_functions_remote_datasource.dart';
import '../../features/subscription/data/datasources/subscription_remote_datasource.dart';
import '../../features/subscription/data/repositories/subscription_repository_impl.dart';
import '../../features/subscription/domain/repositories/subscription_repository.dart';
import '../../features/subscription/domain/usecases/create_plan_usecase.dart';
import '../../features/subscription/domain/usecases/delete_plan_usecase.dart';
import '../../features/subscription/domain/usecases/get_plan_by_id_usecase.dart';
import '../../features/subscription/domain/usecases/list_plans_usecase.dart';
import '../../features/subscription/domain/usecases/search_plans_usecase.dart';
import '../../features/subscription/domain/usecases/update_plan_usecase.dart';
import '../../features/subscription/domain/usecases/watch_plans_usecase.dart';
import '../../features/subscription/presentation/bloc/subscription_bloc.dart';

import '../../features/notification/data/datasources/notification_functions_remote_datasource.dart';
import '../../features/notification/data/datasources/notification_remote_datasource.dart';
import '../../features/notification/data/repositories/notification_repository_impl.dart';
import '../../features/notification/domain/repositories/notification_repository.dart';
import '../../features/notification/domain/usecases/create_notification_template_usecase.dart';
import '../../features/notification/domain/usecases/delete_notification_template_usecase.dart';
import '../../features/notification/domain/usecases/get_my_notification_preferences_usecase.dart';
import '../../features/notification/domain/usecases/get_notification_template_by_id_usecase.dart';
import '../../features/notification/domain/usecases/list_notification_logs_usecase.dart';
import '../../features/notification/domain/usecases/list_notification_templates_usecase.dart';
import '../../features/notification/domain/usecases/search_notification_templates_usecase.dart';
import '../../features/notification/domain/usecases/send_test_email_usecase.dart';
import '../../features/notification/domain/usecases/set_muted_template_ids_usecase.dart';
import '../../features/notification/domain/usecases/update_notification_template_usecase.dart';
import '../../features/notification/domain/usecases/watch_notification_templates_usecase.dart';
import '../../features/notification/presentation/bloc/notification_bloc.dart';

/// App-wide GetIt instance.
final GetIt sl = GetIt.instance;

/// Call once at app startup, after [EnvConfig.load].
Future<void> initServiceLocator() async {
  _initAppwriteCore();
  await _initNotificationFeature();
  _initCompanyFeature();
  _initAuthFeature();
  _initSubscriptionFeature();
}

/// Registers the raw Appwrite SDK services shared by every feature.
void _initAppwriteCore() {
  sl.registerLazySingleton<Client>(
    () => Client()
      ..setEndpoint(EnvConfig.appwriteEndpoint)
      ..setProject(EnvConfig.appwriteProjectId)
      ..setSelfSigned(status: true),
  );

  sl.registerLazySingleton<Account>(
    () => Account(sl<Client>()),
  );

  sl.registerLazySingleton<Databases>(
    () => Databases(sl<Client>()),
  );

  sl.registerLazySingleton<Functions>(
    () => Functions(sl<Client>()),
  );

  sl.registerLazySingleton<Realtime>(
    () => Realtime(sl<Client>()),
  );
}

/// Notification feature dependencies.
Future<void> _initNotificationFeature() async {
  final prefs = await SharedPreferences.getInstance();

  sl.registerLazySingleton<FlutterLocalNotificationsPlugin>(
    FlutterLocalNotificationsPlugin.new,
  );

  sl.registerLazySingleton<SharedPreferences>(
    () => prefs,
  );

  sl.registerLazySingleton<LocalReminderScheduler>(
    () => LocalReminderSchedulerImpl(
      plugin: sl<FlutterLocalNotificationsPlugin>(),
      prefs: sl<SharedPreferences>(),
    ),
  );

  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(
      databases: sl(),
      realtime: sl(),
      account: sl(),
    ),
  );

  sl.registerLazySingleton<NotificationFunctionsRemoteDataSource>(
    () => NotificationFunctionsRemoteDataSourceImpl(
      functions: sl(),
    ),
  );

  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(
      remoteDataSource: sl(),
      functionsDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<CreateNotificationTemplateUseCase>(
    () => CreateNotificationTemplateUseCase(sl()),
  );

  sl.registerLazySingleton<UpdateNotificationTemplateUseCase>(
    () => UpdateNotificationTemplateUseCase(sl()),
  );

  sl.registerLazySingleton<DeleteNotificationTemplateUseCase>(
    () => DeleteNotificationTemplateUseCase(sl()),
  );

  sl.registerLazySingleton<GetNotificationTemplateByIdUseCase>(
    () => GetNotificationTemplateByIdUseCase(sl()),
  );

  sl.registerLazySingleton<ListNotificationTemplatesUseCase>(
    () => ListNotificationTemplatesUseCase(sl()),
  );

  sl.registerLazySingleton<SearchNotificationTemplatesUseCase>(
    () => SearchNotificationTemplatesUseCase(sl()),
  );

  sl.registerLazySingleton<WatchNotificationTemplatesUseCase>(
    () => WatchNotificationTemplatesUseCase(sl()),
  );

  sl.registerLazySingleton<ListNotificationLogsUseCase>(
    () => ListNotificationLogsUseCase(sl()),
  );

  sl.registerLazySingleton<SendTestEmailUseCase>(
    () => SendTestEmailUseCase(sl()),
  );

  sl.registerLazySingleton<GetMyNotificationPreferencesUseCase>(
    () => GetMyNotificationPreferencesUseCase(sl()),
  );

  sl.registerLazySingleton<SetMutedTemplateIdsUseCase>(
    () => SetMutedTemplateIdsUseCase(sl()),
  );

  sl.registerFactory(
    () => NotificationBloc(
      createTemplateUseCase: sl(),
      updateTemplateUseCase: sl(),
      deleteTemplateUseCase: sl(),
      getTemplateByIdUseCase: sl(),
      listTemplatesUseCase: sl(),
      searchTemplatesUseCase: sl(),
      watchTemplatesUseCase: sl(),
      listLogsUseCase: sl(),
      sendTestEmailUseCase: sl(),
      getMyPreferencesUseCase: sl(),
      setMutedTemplateIdsUseCase: sl(),
    ),
  );
}

/// Company feature.
void _initCompanyFeature() {
  sl.registerLazySingleton<CompanyRemoteDataSource>(
    () => CompanyRemoteDataSourceImpl(
      databases: sl<Databases>(),
      realtime: sl<Realtime>(),
    ),
  );

  sl.registerLazySingleton<CompanyFunctionsRemoteDataSource>(
    () => CompanyFunctionsRemoteDataSourceImpl(
      functions: sl<Functions>(),
    ),
  );

  sl.registerLazySingleton<CompanyRepository>(
    () => CompanyRepositoryImpl(
      remoteDataSource: sl<CompanyRemoteDataSource>(),
      functionsDataSource: sl<CompanyFunctionsRemoteDataSource>(),
    ),
  );

  sl.registerLazySingleton(
    () => GetCompanyByIdUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => UpdateCompanyProfileUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => UpdateCompanyStatusUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => AssignSubscriptionPlanUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => ListCompaniesUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => SearchCompaniesUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => WatchCompaniesUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => ListCompaniesByPlanIdUseCase(sl()),
  );

  sl.registerFactory(
    () => CompanyBloc(
      getCompanyByIdUseCase: sl(),
      updateCompanyProfileUseCase: sl(),
      updateCompanyStatusUseCase: sl(),
      assignSubscriptionPlanUseCase: sl(),
      listCompaniesUseCase: sl(),
      searchCompaniesUseCase: sl(),
      watchCompaniesUseCase: sl(),
    ),
  );
}

/// Subscription feature.
void _initSubscriptionFeature() {
  sl.registerLazySingleton<SubscriptionRemoteDataSource>(
    () => SubscriptionRemoteDataSourceImpl(
      databases: sl<Databases>(),
      realtime: sl<Realtime>(),
    ),
  );

  sl.registerLazySingleton<SubscriptionFunctionsRemoteDataSource>(
    () => SubscriptionFunctionsRemoteDataSourceImpl(
      functions: sl<Functions>(),
    ),
  );

  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(
      remoteDataSource: sl<SubscriptionRemoteDataSource>(),
      functionsDataSource: sl<SubscriptionFunctionsRemoteDataSource>(),
    ),
  );

  sl.registerLazySingleton(
    () => CreatePlanUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => UpdatePlanUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => DeletePlanUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => GetPlanByIdUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => ListPlansUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => SearchPlansUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => WatchPlansUseCase(sl()),
  );

  sl.registerFactory(
    () => SubscriptionBloc(
      createPlanUseCase: sl(),
      updatePlanUseCase: sl(),
      deletePlanUseCase: sl(),
      getPlanByIdUseCase: sl(),
      listPlansUseCase: sl(),
      searchPlansUseCase: sl(),
      watchPlansUseCase: sl(),
    ),
  );
}

void _initAuthFeature() {
  // Datasources

  sl.registerLazySingleton<AuthAccountRemoteDataSource>(
    () => AuthAccountRemoteDataSourceImpl(
      account: sl<Account>(),
    ),
  );

  sl.registerLazySingleton<AuthFunctionsRemoteDataSource>(
    () => AuthFunctionsRemoteDataSourceImpl(
      functions: sl<Functions>(),
    ),
  );

  sl.registerLazySingleton<UserProfileRemoteDataSource>(
    () => UserProfileRemoteDataSourceImpl(
      databases: sl<Databases>(),
      realtime: sl<Realtime>(),
    ),
  );

  // Repository

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      accountDataSource: sl<AuthAccountRemoteDataSource>(),
      functionsDataSource: sl<AuthFunctionsRemoteDataSource>(),
      userProfileDataSource: sl<UserProfileRemoteDataSource>(),
    ),
  );

  // Use cases

  sl.registerLazySingleton(
    () => RegisterCompanyAndAdminUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => LoginUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => LogoutUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => GetCurrentUserUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => RequestPasswordResetOtpUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => VerifyOtpAndResetPasswordUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => CreateGestionnaireAccountUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => UpdateAccountStatusUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => DeleteGestionnaireAccountUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => GetUserProfileByIdUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => ListUserProfilesByCompanyUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => SearchUserProfilesUseCase(sl()),
  );

  sl.registerLazySingleton(
    () => WatchUserProfilesUseCase(sl()),
  );

  // Controller

  sl.registerFactory(
    () => AuthBloc(
      registerCompanyAndAdminUseCase: sl(),
      loginUseCase: sl(),
      logoutUseCase: sl(),
      getCurrentUserUseCase: sl(),
      requestPasswordResetOtpUseCase: sl(),
      verifyOtpAndResetPasswordUseCase: sl(),
      createGestionnaireAccountUseCase: sl(),
      updateAccountStatusUseCase: sl(),
      deleteGestionnaireAccountUseCase: sl(),
      getUserProfileByIdUseCase: sl(),
      listUserProfilesByCompanyUseCase: sl(),
      searchUserProfilesUseCase: sl(),
      watchUserProfilesUseCase: sl(),
    ),
  );
}
