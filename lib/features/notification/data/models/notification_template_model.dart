import '../../../../core/constants/appwrite_constants.dart';
import '../../domain/entities/notification_channel.dart';
import '../../domain/entities/notification_template.dart';

class NotificationTemplateModel extends NotificationTemplate {
  const NotificationTemplateModel({
    required super.id,
    required super.name,
    required super.message,
    required super.channel,
    required super.createdAt,
    required super.updatedAt,
  });

  factory NotificationTemplateModel.fromMap(Map<String, dynamic> map) {
    return NotificationTemplateModel(
      id: map[r'$id'] as String,
      name: map[NotificationTemplateAttributes.name] as String,
      message: map[NotificationTemplateAttributes.message] as String,
      channel: NotificationChannelX.fromValue(
        map[NotificationTemplateAttributes.channel] as String,
      ),
      createdAt: DateTime.parse(map[r'$createdAt'] as String),
      updatedAt: DateTime.parse(map[r'$updatedAt'] as String),
    );
  }
}
