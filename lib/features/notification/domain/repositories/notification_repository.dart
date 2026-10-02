import 'package:equatable/equatable.dart';

import '../../../../core/typedefs/future_either.dart';
import '../entities/notification_channel.dart';
import '../entities/notification_log.dart';
import '../entities/notification_preferences.dart';
import '../entities/notification_template.dart';
import '../entities/notification_template_realtime_event.dart';

/// Domain contract for feature 5.4 (Gestion des notifications).
///
/// Templates: writes (create/update/delete) are Admin/Super Admin-only
/// privileged Cloud Function resources; reads are plain client calls -
/// every template document is created with `read(users)` permission,
/// the same reasoning as `subscription_plans` (the catalog isn't
/// sensitive, and any role may eventually need to read a template's
/// content once 5.8/5.10 reference one).
///
/// Logs: read-only from the client's perspective for now - entries are
/// written server-side, as a side effect of `sendTestEmail` today and of
/// 5.8/5.10's own send calls later, never created directly by the
/// client. No realtime here (unlike templates) - a history list doesn't
/// need live updates the way an active management list does; scope
/// deliberately kept to what 5.4 needs today.
abstract class NotificationRepository {
  FutureEither<NotificationTemplate> createTemplate(CreateTemplateParams params);

  FutureEither<NotificationTemplate> updateTemplate(UpdateTemplateParams params);

  FutureEither<bool> deleteTemplate(String templateId);

  FutureEither<NotificationTemplate> getTemplateById(String templateId);

  FutureEither<List<NotificationTemplate>> listTemplates({int limit = 25, int offset = 0});

  FutureEither<List<NotificationTemplate>> searchTemplates(String query);

  Stream<NotificationTemplateRealtimeEvent> watchTemplates();

  FutureEither<List<NotificationLog>> listLogs({int limit = 25, int offset = 0});

  /// Sends a one-off test email to the CALLER themselves (an existing
  /// Appwrite user - Admin or Super Admin), purely to verify the SMTP
  /// provider + `_send_email` pipeline actually works end to end. Not a
  /// template send - [subject]/[message] are ad-hoc. Writes a
  /// `NotificationLog` entry either way (sent or failed).
  FutureEither<bool> sendTestEmail({required String subject, required String message});

  /// The caller's own preferences (Admin only - a Gestionnaire calling
  /// this gets an error from the backend, see `main.py`). Returns
  /// [NotificationPreferences.empty] if no preferences document exists
  /// yet, rather than an error - "never opted out of anything" is a
  /// perfectly normal, common state, not a failure.
  FutureEither<NotificationPreferences> getMyPreferences();

  /// Replaces the caller's full muted-template list (Admin only).
  FutureEither<NotificationPreferences> setMutedTemplateIds(List<String> templateIds);
}

class CreateTemplateParams extends Equatable {
  final String name;
  final String message;
  final NotificationChannel channel;

  const CreateTemplateParams({required this.name, required this.message, required this.channel});

  @override
  List<Object?> get props => [name, message, channel];
}

class UpdateTemplateParams extends Equatable {
  final String templateId;
  final String name;
  final String message;
  final NotificationChannel channel;

  const UpdateTemplateParams({
    required this.templateId,
    required this.name,
    required this.message,
    required this.channel,
  });

  @override
  List<Object?> get props => [templateId, name, message, channel];
}
