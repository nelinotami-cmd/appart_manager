import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Inline alert banner (`DESIGN.md` "Feedback > Inline Alerts") - soft
/// background tint placed directly above the relevant content. Generic
/// across features (originally Auth-only as `AuthInlineAlert`) - surfaces
/// a `Failure.message` without mapping it to any particular form field,
/// since backends here don't report field-level errors.
class AppInlineAlert extends StatelessWidget {
  final String message;
  final bool isError;

  const AppInlineAlert({super.key, required this.message, this.isError = true});

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

/// Backward-compatible alias so existing Auth pages built against
/// `AuthInlineAlert` keep working without an edit to every call site.
typedef AuthInlineAlert = AppInlineAlert;
