import 'package:flutter/material.dart';

/// Color tokens from `DESIGN.md` ("Core Enterprise" system).
///
/// NOTE: `DESIGN.md`'s YAML frontmatter and its prose "Colors" section
/// disagree slightly (frontmatter: primary `#00236f`, background
/// `#faf8ff`; prose: primary `#1E3A8A`, background `#F8FAFC`). The
/// frontmatter is treated as the source of truth here since it's the
/// structured token data the rest of the doc's prose describes in
/// looser terms - flag this to whoever owns `DESIGN.md` if `#1E3A8A`
/// was actually the intended brand primary; swapping it is a one-line
/// change in this file.
class AppColors {
  AppColors._();

  static const surface = Color(0xFFFAF8FF);
  static const surfaceDim = Color(0xFFDAD9E1);
  static const surfaceBright = Color(0xFFFAF8FF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF4F3FA);
  static const surfaceContainer = Color(0xFFEEEDF4);
  static const surfaceContainerHigh = Color(0xFFE9E7EF);
  static const surfaceContainerHighest = Color(0xFFE3E1E9);

  static const onSurface = Color(0xFF1A1B21);
  static const onSurfaceVariant = Color(0xFF444651);
  static const inverseSurface = Color(0xFF2F3036);
  static const inverseOnSurface = Color(0xFFF1F0F7);

  static const outline = Color(0xFF757682);
  static const outlineVariant = Color(0xFFC5C5D3);

  static const primary = Color(0xFF00236F);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF1E3A8A);
  static const onPrimaryContainer = Color(0xFF90A8FF);
  static const inversePrimary = Color(0xFFB6C4FF);

  static const secondary = Color(0xFF505F76);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFD0E1FB);
  static const onSecondaryContainer = Color(0xFF54647A);

  static const tertiary = Color(0xFF4B1C00);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF6E2C00);
  static const onTertiaryContainer = Color(0xFFF39461);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  static const background = Color(0xFFFAF8FF);
  static const onBackground = Color(0xFF1A1B21);
  static const surfaceVariant = Color(0xFFE3E1E9);

  // Success is not defined in DESIGN.md's palette (only error/warning are
  // called out in prose, no hex given for either warning or success) -
  // this is a reasonable, low-saturation green consistent with the
  // "sparingly used status color" guidance and the same M3-style
  // structure as the error tokens above. Revisit if `DESIGN.md` is
  // updated with explicit success/warning hex values.
  static const success = Color(0xFF1B7F4C);
  static const onSuccess = Color(0xFFFFFFFF);
  static const successContainer = Color(0xFFD7F2E3);
  static const onSuccessContainer = Color(0xFF0B4A2B);
}
