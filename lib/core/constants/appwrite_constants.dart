/// Non-secret, structural constants describing the Appwrite schema
/// (attribute keys) shared across features. Environment-specific IDs
/// (project id, database id, collection ids, function ids) live in
/// [EnvConfig], not here.
class UserProfileAttributes {
  UserProfileAttributes._();

  static const String fullName = 'fullName';
  static const String email = 'email';
  static const String phone = 'phone';
  static const String role = 'role';
  static const String companyId = 'companyId';
  static const String status = 'status';
  static const String createdBy = 'createdBy';
}

class CompanyAttributes {
  CompanyAttributes._();

  static const String name = 'name';
  static const String contactName = 'contactName';
  static const String contactEmail = 'contactEmail';
  static const String contactPhone = 'contactPhone';
  static const String address = 'address';
  static const String status = 'status';
  static const String subscriptionPlanId = 'subscriptionPlanId';
}

class SubscriptionPlanAttributes {
  SubscriptionPlanAttributes._();

  static const String name = 'name';
  static const String description = 'description';
  static const String monthlyPrice = 'monthlyPrice';
  static const String enabledFeatures = 'enabledFeatures';
}

class NotificationTemplateAttributes {
  NotificationTemplateAttributes._();

  static const String name = 'name';
  static const String message = 'message';
  static const String channel = 'channel';
}

class NotificationLogAttributes {
  NotificationLogAttributes._();

  static const String companyId = 'companyId';
  static const String recipientLabel = 'recipientLabel';
  static const String channel = 'channel';
  static const String subject = 'subject';
  static const String message = 'message';
  static const String status = 'status';
  static const String errorMessage = 'errorMessage';
}

class NotificationPreferencesAttributes {
  NotificationPreferencesAttributes._();

  static const String mutedTemplateIds = 'mutedTemplateIds';
}
