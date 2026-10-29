import 'package:flutter/material.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

void showErrorSnack(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  final text = error is ApiException ? apiErrorText(l10n, error.code) : l10n.errorUnknown;
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Centered icon, title, body and optional actions for empty or blocked states.
class MessagePanel extends StatelessWidget {
  const MessagePanel({required this.icon, required this.title, this.body, this.actions = const [], super.key});

  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: textTheme.titleLarge, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(body!, style: textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
