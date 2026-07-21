import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';

/// Shared page chrome for every Auth screen: centered card on the
/// `AppColors.background` canvas, brand mark above it, optional footer
/// slot below (e.g. "Don't have an account? Sign up").
///
/// Standardized as a single layout across Login/Register/OTP screens -
/// the source reference mockups mixed a plain centered-card style with a
/// decorative navy split-panel style across different screens, which
/// `DESIGN.md` itself doesn't call for (no split-panel hero pattern is
/// described anywhere in the token doc) - one consistent shell reads as
/// a coherent product rather than several different demos stitched
/// together.
class AuthShell extends StatelessWidget {
  final Widget child;
  final Widget? footer;
  final double maxWidth;

  const AuthShell({
    super.key,
    required this.child,
    this.footer,
    this.maxWidth = 440,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      border: Border.all(color: AppColors.surfaceContainerHighest),
                    ),
                    child: child,
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Appartements ERP', style: AppTextStyles.headlineMd),
      ],
    );
  }
}

/// Inline alert banner (`DESIGN.md` "Feedback > Inline Alerts") - soft
/// background tint placed directly above the relevant content. Used to
/// surface `Failure.message` from `AuthState` without mapping it to any
/// particular form field (the backend doesn't report field-level errors).
class AuthInlineAlert extends StatelessWidget {
  final String message;
  final bool isError;

  const AuthInlineAlert({super.key, required this.message, this.isError = true});

  @override
  Widget build(BuildContext context) {
    final bg = isError ? AppColors.errorContainer : AppColors.successContainer;
    final fg = isError ? AppColors.onErrorContainer : AppColors.onSuccessContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.standard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: AppTextStyles.bodySm.copyWith(color: fg))),
        ],
      ),
    );
  }
}
