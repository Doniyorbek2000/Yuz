import 'package:flutter/material.dart';

import '../../features/catalog/feature_catalog.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/app_tokens.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final FeatureStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      FeatureStatus.implemented => AppColors.success,
      FeatureStatus.partial => AppColors.warning,
      FeatureStatus.notStarted => AppColors.textMuted,
      FeatureStatus.blocked => AppColors.danger,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.all(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
        child: Text(
          status.label(AppLocalizations.of(context)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}
