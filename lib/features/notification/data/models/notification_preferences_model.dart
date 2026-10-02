import '../../../../core/constants/appwrite_constants.dart';
import '../../domain/entities/notification_preferences.dart';

class NotificationPreferencesModel extends NotificationPreferences {
  const NotificationPreferencesModel({required super.userId, required super.mutedTemplateIds});

  factory NotificationPreferencesModel.fromMap(Map<String, dynamic> map) {
    final raw = (map[NotificationPreferencesAttributes.mutedTemplateIds] as List?) ?? const [];
    return NotificationPreferencesModel(
      userId: map[r'$id'] as String,
      mutedTemplateIds: raw.cast<String>(),
    );
  }
}
