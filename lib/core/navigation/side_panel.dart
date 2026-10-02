import 'package:flutter/material.dart';

/// Shows [contentBuilder]'s content as a responsive "detail panel" rather
/// than a full route navigation:
///
/// - **Wide screens** (>= 900px, matching `AppShell`'s own breakpoint):
///   slides in from the right as an overlay panel beside the current
///   page (which stays visible, dimmed, behind a scrim), dismissible by
///   tapping the scrim or the close (X) button. This is what "open a
///   side view instead of a new pop up page" means in practice - the
///   underlying page (e.g. company detail) never disappears.
/// - **Narrow screens (mobile)**: there's no room for a true side panel,
///   so this falls back to a full-screen page - but with a leading
///   back-arrow `IconButton` placed before the title (via `AppBar.leading`,
///   which Material always positions before `title`), per the explicit
///   requirement that mobile still needs a clear way back.
///
/// Deliberately built by hand rather than via a package: Flutter has no
/// built-in "side sheet" widget (unlike `showBottomSheet`), so this is a
/// custom `PageRoute` with a transparent barrier on wide screens and an
/// opaque one on mobile.
Future<T?> showSidePanel<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder contentBuilder,
  double panelWidth = 460,
}) {
  final isWide = MediaQuery.of(context).size.width >= 900;

  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: !isWide,
      barrierDismissible: isWide,
      barrierColor: isWide ? Colors.black54 : null,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        final scaffold = _SidePanelScaffold(
          title: title,
          isWide: isWide,
          child: Builder(builder: contentBuilder),
        );

        if (!isWide) return scaffold;

        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 8,
            child: SizedBox(
              width: panelWidth,
              height: double.infinity,
              child: scaffold,
            ),
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    ),
  );
}

class _SidePanelScaffold extends StatelessWidget {
  final String title;
  final bool isWide;
  final Widget child;

  const _SidePanelScaffold(
      {required this.title, required this.isWide, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // Mobile: a real back arrow, since this fully replaces the
        // screen. Wide: a close (X), since the underlying page is still
        // visible right behind this overlay - "close" reads more
        // correctly than "back" there, but either way it's the leading
        // icon, positioned before the title by AppBar itself.
        leading: IconButton(
          icon: Icon(isWide ? Icons.close : Icons.arrow_back),
          tooltip: isWide ? 'Fermer' : 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
      ),
      body: child,
    );
  }
}
