import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/generated/app_localizations.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = [
      (Icons.memory_outlined, l10n.privacyOnDeviceTitle, l10n.privacyOnDeviceBody),
      (Icons.sd_storage_outlined, l10n.privacyStorageTitle, l10n.privacyStorageBody),
      (Icons.cloud_outlined, l10n.privacyCloudTitle, l10n.privacyCloudBody),
      (Icons.delete_outline, l10n.privacyDeletionTitle, l10n.privacyDeletionBody),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final (icon, title, body) = sections[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(body, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
