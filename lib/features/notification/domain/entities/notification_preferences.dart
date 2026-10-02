import 'package:equatable/equatable.dart';

/// One Admin's own email-notification preferences (cahier des charges
/// 5.4, extended per explicit instruction: "the email must always be
/// sent to the manager and admin of the company unless the admin opts
/// out from his view of some type"). Tied to templates rather than an
/// abstract "notification type" - 5.4 has nothing else concrete to
/// offer yet, and templates are exactly the reusable, nameable content
/// units this feature already creates.
///
/// Admin-only by design: Gestionnaires have no opt-out at all (always
/// receive) - there is deliberately no equivalent entity/screen for
/// them.
class NotificationPreferences extends Equatable {
  final String userId;
  final List<String> mutedTemplateIds;

  const NotificationPreferences({required this.userId, required this.mutedTemplateIds});

  /// The default when no preferences document exists yet (an Admin who
  /// has never opted out of anything) - full reception, nothing muted.
  factory NotificationPreferences.empty(String userId) =>
      NotificationPreferences(userId: userId, mutedTemplateIds: const []);

  bool isTemplateMuted(String templateId) => mutedTemplateIds.contains(templateId);

  @override
  List<Object?> get props => [userId, mutedTemplateIds];
}
