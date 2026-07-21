import 'package:appwrite/appwrite.dart';
import 'package:get_it/get_it.dart';

import '../env/env_config.dart';
import '../../features/company/data/datasources/company_remote_datasource.dart';
import '../../features/company/data/repositories/company_repository_impl.dart';
import '../../features/company/domain/repositories/company_repository.dart';
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

/// App-wide GetIt instance. Every feature registers its dependencies here
/// (not in feature-scoped locators) via the `_initXxxFeature` functions
/// below, all invoked from [initServiceLocator].
final GetIt sl = GetIt.instance;

/// Call once at app startup, after [EnvConfig.load].
Future<void> initServiceLocator() async {
  _initAppwriteCore();
  _initCompanyFeature();
  _initAuthFeature();
}

/// Registers the raw Appwrite SDK services shared by every feature.
/// Presentation and Domain never see these directly - only Data-layer
/// datasources depend on them.
void _initAppwriteCore() {
  sl.registerLazySingleton<Client>(
    () => Client()
      ..setEndpoint(EnvConfig.appwriteEndpoint)
      ..setProject(EnvConfig.appwriteProjectId)
      ..setSelfSigned(status: true), // dev-only; remove/guard for prod builds
  );

  sl.registerLazySingleton<Account>(() => Account(sl<Client>()));
  sl.registerLazySingleton<Databases>(() => Databases(sl<Client>()));
  sl.registerLazySingleton<Functions>(() => Functions(sl<Client>()));
  sl.registerLazySingleton<Realtime>(() => Realtime(sl<Client>()));
}

/// Company feature is intentionally minimal at this stage: it exists only
/// to support the `companyId` relationship created during Auth's
/// "register company + admin" flow (see cahier des charges 5.1 & 5.2).
/// Full Company CRUD/activation (5.2) will extend this registration when
/// that feature is implemented.
void _initCompanyFeature() {
  sl.registerLazySingleton<CompanyRemoteDataSource>(
    () => CompanyRemoteDataSourceImpl(databases: sl<Databases>()),
  );

  sl.registerLazySingleton<CompanyRepository>(
    () => CompanyRepositoryImpl(remoteDataSource: sl<CompanyRemoteDataSource>()),
  );
}

void _initAuthFeature() {
  // Datasources
  sl.registerLazySingleton<AuthAccountRemoteDataSource>(
    () => AuthAccountRemoteDataSourceImpl(account: sl<Account>()),
  );
  sl.registerLazySingleton<AuthFunctionsRemoteDataSource>(
    () => AuthFunctionsRemoteDataSourceImpl(functions: sl<Functions>()),
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
  sl.registerLazySingleton(() => RegisterCompanyAndAdminUseCase(sl()));
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => RequestPasswordResetOtpUseCase(sl()));
  sl.registerLazySingleton(() => VerifyOtpAndResetPasswordUseCase(sl()));
  sl.registerLazySingleton(() => CreateGestionnaireAccountUseCase(sl()));
  sl.registerLazySingleton(() => UpdateAccountStatusUseCase(sl()));
  sl.registerLazySingleton(() => DeleteGestionnaireAccountUseCase(sl()));
  sl.registerLazySingleton(() => GetUserProfileByIdUseCase(sl()));
  sl.registerLazySingleton(() => ListUserProfilesByCompanyUseCase(sl()));
  sl.registerLazySingleton(() => SearchUserProfilesUseCase(sl()));
  sl.registerLazySingleton(() => WatchUserProfilesUseCase(sl()));

  // Controller (factory: a fresh AuthBloc per navigation to the auth flow;
  // swap to a singleton registration if a single app-lifetime instance is
  // preferred once routing is designed).
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
