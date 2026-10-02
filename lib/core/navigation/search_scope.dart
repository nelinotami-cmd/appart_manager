import 'package:flutter/widgets.dart';

/// Propagates the shell's top-bar search query down to whichever route
/// GoRouter renders for the current destination, without coupling
/// content widgets to how/where that text field lives (it lives in
/// `AppShell`'s `AppBar`, one level up from any individual route).
///
/// `AppShell` owns and updates the [ValueNotifier]; searchable pages
/// (`CompaniesListPage`, `CompanyUsersPage`, `SubscriptionsListPage`)
/// read it via [SearchScope.of] inside their route's `builder` callback
/// in `app_router.dart` and pass it into their existing `searchQuery`
/// constructor parameter - the pages themselves are unchanged from
/// before, only where that value comes from changed.
class SearchScope extends InheritedNotifier<ValueNotifier<String>> {
  const SearchScope({
    super.key,
    required ValueNotifier<String> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static String of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SearchScope>();
    return scope?.notifier?.value ?? '';
  }
}
