import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/status_badge.dart';
import '../../l10n/generated/app_localizations.dart';
import 'feature_catalog.dart';

/// Honest destination for features that are not part of this build.
class FeatureUnavailableScreen extends StatelessWidget {
  const FeatureUnavailableScreen({required this.feature, super.key});

  final AppFeature feature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(feature.label(l10n))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(feature.icon, size: 56, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              StatusBadge(status: feature.status),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.featureUnavailableTitle, style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                feature.status == FeatureStatus.blocked
                    ? l10n.featureBlockedBody(feature.label(l10n))
                    : l10n.featureUnavailableBody(feature.label(l10n), feature.phase),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
