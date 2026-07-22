import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Labeled text field matching `DESIGN.md`'s "Form Fields" spec: label
/// above the field, 1px outline border, primary-color focus ring,
/// error-colored border + trailing icon when [errorText] is set.
///
/// Deliberately a thin wrapper around [TextField] (not [TextFormField])
/// - there is no [Form]/validator wiring here by project convention;
/// callers own their [controller] and decide what, if anything, counts
/// as an error to display.
class AppTextField extends StatefulWidget {
  final String? label;
  final String hint;
  final TextEditingController controller;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final int maxLines;

  const AppTextField({
    super.key,
    this.label,
    required this.hint,
    required this.controller,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.errorText,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty) ...[
          Text(widget.label!, style: AppTextStyles.labelMd),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          style: AppTextStyles.bodyMd,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 20, color: AppColors.outline),
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.outline,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
