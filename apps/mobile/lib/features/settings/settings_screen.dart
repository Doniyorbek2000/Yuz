import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/storage/preferences.dart';
import '../../core/theme/app_tokens.dart';
import '../../l10n/generated/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final performanceOverlay = ref.watch(performanceOverlayProvider);
    final languages = <(String?, String)>[
      (null, l10n.settingsLanguageSystem),
      ('uz', l10n.languageUzbek),
      ('ru', l10n.languageRussian),
      ('en', l10n.languageEnglish),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsLanguage),
          RadioGroup<String?>(
            groupValue: locale?.languageCode,
            onChanged: (code) => ref.read(localeProvider.notifier).select(code),
            child: Column(
              children: [
                for (final (code, label) in languages)
                  RadioListTile<String?>(value: code, title: Text(label), key: ValueKey('locale-${code ?? 'system'}')),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            value: performanceOverlay,
            onChanged: (value) => ref.read(performanceOverlayProvider.notifier).set(value),
            title: Text(l10n.settingsPerformanceOverlay),
            subtitle: Text(l10n.settingsPerformanceOverlaySubtitle),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.settingsPrivacy),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.replay_outlined),
            title: Text(l10n.settingsResetOnboarding),
            onTap: () async {
              await ref.read(onboardingCompletedProvider.notifier).set(false);
              if (context.mounted) context.go('/onboarding');
            },
          ),
          const Divider(),
          _SectionHeader(l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.appTitle),
            subtitle: Text(l10n.settingsVersion(AppInfo.version)),
            onTap: () =>
                showLicensePage(context: context, applicationName: l10n.appTitle, applicationVersion: AppInfo.version),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xs),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.accent)),
  );
}
