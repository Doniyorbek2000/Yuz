import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/status_badge.dart';
import '../../l10n/generated/app_localizations.dart';
import '../catalog/feature_catalog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const BrandMark(size: 40),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(l10n.homeGreeting, style: textTheme.headlineSmall)),
                    IconButton(
                      tooltip: l10n.settingsTitle,
                      onPressed: () => context.push('/settings'),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverToBoxAdapter(child: _CameraHeroCard()),
            ),
            for (final section in FeatureSection.values.where((s) => s != FeatureSection.camera)) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
                sliver: SliverToBoxAdapter(child: Text(section.label(l10n), style: textTheme.titleMedium)),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisExtent: 112,
                  ),
                  itemCount: AppFeature.inSection(section).length,
                  itemBuilder: (context, index) => FeatureTile(feature: AppFeature.inSection(section)[index]),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }
}

class _CameraHeroCard extends StatelessWidget {
  const _CameraHeroCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    const feature = AppFeature.beautyCamera;
    return Material(
      borderRadius: const BorderRadius.all(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      color: AppColors.surface,
      child: InkWell(
        onTap: () => context.push(feature.route!),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent.withValues(alpha: 0.28), AppColors.surface],
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StatusBadge(status: FeatureStatus.partial),
                    const SizedBox(height: AppSpacing.sm),
                    Text(feature.label(l10n), style: textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(l10n.featureBeautyCameraSubtitle, style: textTheme.bodyMedium),
                  ],
                ),
              ),
              const CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                child: Icon(Icons.photo_camera_front_rounded, size: 30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  const FeatureTile({required this.feature, super.key});

  final AppFeature feature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = feature.isAvailable;
    final foreground = available ? AppColors.textPrimary : AppColors.textMuted;
    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.all(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => available ? context.push(feature.route!) : context.push('/unavailable/${feature.name}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(feature.icon, color: foreground),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: StatusBadge(status: feature.status),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                feature.label(l10n),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
