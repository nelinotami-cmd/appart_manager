import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Content shown for a sidebar destination whose feature (5.3-5.6, 5.8-
/// 5.10 as of this writing) hasn't been built yet. Exists so the sidebar
/// can show every feature from cahier des charges 5.2-5.11 now, without
/// each one being a dead end or a raw "not found" - swap this out for the
/// real feature content as each one gets built.
class FeaturePlaceholderPage extends StatelessWidget {
  final String featureLabel;
  final String cahierDesChargesSection;

  const FeaturePlaceholderPage({
    super.key,
    required this.featureLabel,
    required this.cahierDesChargesSection,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_rounded, size: 40, color: AppColors.outline),
            const SizedBox(height: AppSpacing.md),
            Text(featureLabel, style: AppTextStyles.headlineSm),
            const SizedBox(height: 4),
            Text(
              'Section $cahierDesChargesSection - pas encore construite.',
              style: AppTextStyles.bodySm,
            ),
          ],
        ),
      ),
    );
  }
}
