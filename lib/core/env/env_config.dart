import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supported build flavors / environments.
enum AppFlavor { dev, preprod, prod }

/// Centralised, typed access to environment configuration.
///
/// Loaded once at app startup (see `main.dart`) via [EnvConfig.load], which
/// reads the `.env.<flavor>` file into memory using `flutter_dotenv`. No
/// secret/Appwrite ID is ever hardcoded elsewhere in the codebase.
class EnvConfig {
  EnvConfig._();

  static late final String appwriteEndpoint;
  static late final String appwriteProjectId;
  static late final String databaseId;
  static late final String companiesCollectionId;
  static late final String userProfilesCollectionId;
  static late final String subscriptionPlansCollectionId;
  static late final String notificationTemplatesCollectionId;
  static late final String notificationLogsCollectionId;
  static late final String notificationPreferencesCollectionId;

  /// THE single Appwrite Function for this entire project (see
  /// `functions/api/src/main.py`). Every feature's privileged
  /// server-side operation - Auth today, others later - is a `resource`
  /// on this SAME function; there is no per-feature function id and there
  /// must never be one (Appwrite plan function-count limit). Callers
  /// select the operation via a `resource` key in the request body (e.g.
  /// `auth.create-gestionnaire-account`) - see
  /// `AuthFunctionsRemoteDataSource`.
  static late final String apiFunctionId;

  static Future<void> load(AppFlavor flavor) async {
    final fileName = switch (flavor) {
      AppFlavor.dev => '.env.dev',
      AppFlavor.preprod => '.env.preprod',
      AppFlavor.prod => '.env.prod',
    };

    await dotenv.load(fileName: fileName);

    appwriteEndpoint = _require('APPWRITE_ENDPOINT');
    appwriteProjectId = _require('APPWRITE_PROJECT_ID');
    databaseId = _require('APPWRITE_DATABASE_ID');
    companiesCollectionId = _require('APPWRITE_COLLECTION_COMPANIES');
    userProfilesCollectionId = _require('APPWRITE_COLLECTION_USER_PROFILES');
    subscriptionPlansCollectionId =
        _require('APPWRITE_COLLECTION_SUBSCRIPTION_PLANS');
    notificationTemplatesCollectionId =
        _require('APPWRITE_COLLECTION_NOTIFICATION_TEMPLATES');
    notificationLogsCollectionId =
        _require('APPWRITE_COLLECTION_NOTIFICATION_LOGS');
    notificationPreferencesCollectionId =
        _require('APPWRITE_COLLECTION_NOTIFICATION_PREFERENCES');
    apiFunctionId = _require('APPWRITE_FUNCTION_API');
  }

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError('Missing required env var: $key');
    }
    return value;
  }
}
