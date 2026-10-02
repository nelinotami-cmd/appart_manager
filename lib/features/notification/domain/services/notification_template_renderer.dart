/// Renders a template's `{{placeholder}}` tokens using [variables].
///
/// This is the answer to "how do templates adapt to booking info (date,
/// price, time...)": the notification feature stays completely blind to
/// what a booking, a task, or any future entity even IS - it only knows
/// how to replace `{{key}}` with `variables[key].toString()`. Whichever
/// feature is actually sending a notification (5.8 Bookings, 5.10
/// Taches, once they exist) decides what keys it offers and how each
/// value formats itself - a price, a date, whatever - by what it passes
/// in. That value can be a plain pre-formatted `String`, or a small
/// custom class with its own `toString()` override (e.g. a
/// `_BookingAmount` that knows how to render itself as "12 500 FCFA") -
/// this function only ever calls `.toString()` on it and never cares
/// which.
///
/// An Admin writes something like:
/// `"Le paiement de {{amount}} pour la reservation {{bookingId}} est du le {{dueDate}}."`
/// and a future feature calls:
/// `renderNotificationTemplate(template.message, {
///   'amount': someMoneyFormatter,
///   'bookingId': booking.id,
///   'dueDate': someDateFormatter,
/// })`
///
/// Deliberately NOT an abstract "notification context" class with one
/// combined `toString()`: that pattern can only prepend/append a
/// formatted blob to a template, not let the Admin control WHERE each
/// value appears in their own wording - placeholders solve that
/// directly. A missing key is left as the literal `{{key}}` text rather
/// than throwing, so a template referencing a variable a given send call
/// forgot to provide fails visibly (in the delivered message) rather
/// than crashing whatever's sending it.
String renderNotificationTemplate(String template, Map<String, Object?> variables) {
  var rendered = template;
  for (final entry in variables.entries) {
    rendered = rendered.replaceAll('{{${entry.key}}}', entry.value?.toString() ?? '');
  }
  return rendered;
}

/// Extracts every `{{placeholder}}` key referenced in [template], in the
/// order they first appear - used by the template editor to show an
/// Admin which placeholders their own message currently references,
/// without the notification feature needing to know whether any of them
/// are "real" (defined by whichever feature eventually sends this
/// template) or just typos.
List<String> extractTemplatePlaceholders(String template) {
  final matches = RegExp(r'\{\{(\w+)\}\}').allMatches(template);
  final seen = <String>{};
  final ordered = <String>[];
  for (final match in matches) {
    final key = match.group(1)!;
    if (seen.add(key)) ordered.add(key);
  }
  return ordered;
}
