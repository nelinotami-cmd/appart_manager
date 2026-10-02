import '../../../../core/constants/appwrite_constants.dart';
import '../../domain/entities/notification_channel.dart';
import '../../domain/entities/notification_log.dart';

class NotificationLogModel extends NotificationLog {
  const NotificationLogModel({
    required super.id,
    required super.companyId,
    required super.recipientLabel,
    required super.channel,
    required super.subject,
    required super.message,
    required super.status,
    required super.errorMessage,
    required super.createdAt,
  });

  factory NotificationLogModel.fromMap(Map<String, dynamic> map) {
    return NotificationLogModel(
      id: map[r'$id'] as String,
      companyId: map[NotificationLogAttributes.companyId] as String?,
      recipientLabel: map[NotificationLogAttributes.recipientLabel] as String,
      channel: NotificationChannelX.fromValue(map[NotificationLogAttributes.channel] as String),
      subject: map[NotificationLogAttributes.subject] as String,
      message: map[NotificationLogAttributes.message] as String,
      status: NotificationLogStatusX.fromValue(map[NotificationLogAttributes.status] as String),
      errorMessage: map[NotificationLogAttributes.errorMessage] as String?,
      createdAt: DateTime.parse(map[r'$createdAt'] as String),
    );
  }
}
