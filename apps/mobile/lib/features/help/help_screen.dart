import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/generated/app_localizations.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final entries = [
      (l10n.helpUploadQ, l10n.helpUploadA),
      (l10n.helpCreditsQ, l10n.helpCreditsA),
      (l10n.helpBlockedQ, l10n.helpBlockedA),
      (l10n.helpDeleteQ, l10n.helpDeleteA),
      (l10n.helpCameraQ, l10n.helpCameraA),
      (l10n.helpSavedQ, l10n.helpSavedA),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featureHelp)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(l10n.helpIntro, style: textTheme.bodyLarge),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (question, answer) in entries)
            ExpansionTile(
              title: Text(question, style: textTheme.titleSmall),
              childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(answer, style: textTheme.bodyMedium)],
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.settingsPrivacy),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/privacy'),
          ),
        ],
      ),
    );
  }
}
