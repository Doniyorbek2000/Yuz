import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Delivery status shown in the UI. Mirrors FEATURE_MATRIX.md; a feature is
/// only routed to a working screen when it is [implemented] or [partial].
enum FeatureStatus { implemented, partial, notStarted }

enum FeatureSection { camera, editing, ai, account }

enum AppFeature {
  beautyCamera(FeatureSection.camera, FeatureStatus.partial, 1, Icons.face_retouching_natural, '/camera'),
  photoEditor(FeatureSection.editing, FeatureStatus.partial, 3, Icons.photo_filter_outlined, '/projects'),
  videoEditor(FeatureSection.editing, FeatureStatus.notStarted, 4, Icons.movie_filter_outlined, null),
  templates(FeatureSection.editing, FeatureStatus.notStarted, 6, Icons.dashboard_customize_outlined, null),
  projects(FeatureSection.editing, FeatureStatus.partial, 3, Icons.folder_open_outlined, '/projects'),
  aiPhotoshoot(FeatureSection.ai, FeatureStatus.notStarted, 6, Icons.auto_awesome_outlined, null),
  aiHairstyle(FeatureSection.ai, FeatureStatus.notStarted, 6, Icons.content_cut_outlined, null),
  aiMakeup(FeatureSection.ai, FeatureStatus.notStarted, 3, Icons.brush_outlined, null),
  aiBackground(FeatureSection.ai, FeatureStatus.notStarted, 6, Icons.wallpaper_outlined, null),
  premium(FeatureSection.account, FeatureStatus.notStarted, 7, Icons.workspace_premium_outlined, null),
  credits(FeatureSection.account, FeatureStatus.notStarted, 7, Icons.toll_outlined, null),
  profile(FeatureSection.account, FeatureStatus.notStarted, 5, Icons.person_outline, null),
  settings(FeatureSection.account, FeatureStatus.implemented, 1, Icons.tune_outlined, '/settings'),
  help(FeatureSection.account, FeatureStatus.notStarted, 8, Icons.help_outline, null);

  const AppFeature(this.section, this.status, this.phase, this.icon, this.route);

  final FeatureSection section;
  final FeatureStatus status;

  /// Roadmap phase that delivers (or delivered) the feature.
  final int phase;
  final IconData icon;

  /// Route of the working screen; null while the feature is not started.
  final String? route;

  bool get isAvailable => route != null && status != FeatureStatus.notStarted;

  String label(AppLocalizations l10n) => switch (this) {
    AppFeature.beautyCamera => l10n.featureBeautyCamera,
    AppFeature.photoEditor => l10n.featurePhotoEditor,
    AppFeature.videoEditor => l10n.featureVideoEditor,
    AppFeature.templates => l10n.featureTemplates,
    AppFeature.projects => l10n.featureProjects,
    AppFeature.aiPhotoshoot => l10n.featureAiPhotoshoot,
    AppFeature.aiHairstyle => l10n.featureAiHairstyle,
    AppFeature.aiMakeup => l10n.featureAiMakeup,
    AppFeature.aiBackground => l10n.featureAiBackground,
    AppFeature.premium => l10n.featurePremium,
    AppFeature.credits => l10n.featureCredits,
    AppFeature.profile => l10n.featureProfile,
    AppFeature.settings => l10n.featureSettings,
    AppFeature.help => l10n.featureHelp,
  };

  static List<AppFeature> inSection(FeatureSection section) =>
      values.where((feature) => feature.section == section).toList(growable: false);
}

extension FeatureSectionLabel on FeatureSection {
  String label(AppLocalizations l10n) => switch (this) {
    FeatureSection.camera => l10n.homeSectionCamera,
    FeatureSection.editing => l10n.homeSectionEditing,
    FeatureSection.ai => l10n.homeSectionAi,
    FeatureSection.account => l10n.homeSectionAccount,
  };
}

extension FeatureStatusLabel on FeatureStatus {
  String label(AppLocalizations l10n) => switch (this) {
    FeatureStatus.implemented => l10n.statusImplemented,
    FeatureStatus.partial => l10n.statusPartial,
    FeatureStatus.notStarted => l10n.statusNotStarted,
  };
}
