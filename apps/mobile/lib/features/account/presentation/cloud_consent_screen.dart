import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/session_controller.dart';
import 'account_widgets.dart';

/// Explicit, versioned consent before any photo is uploaded.
class CloudConsentScreen extends ConsumerStatefulWidget {
  const CloudConsentScreen({super.key});

  @override
  ConsumerState<CloudConsentScreen> createState() => _CloudConsentScreenState();
}

class _CloudConsentScreenState extends ConsumerState<CloudConsentScreen> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ref.read(sessionControllerProvider.notifier).grantCloudAiConsent();
      if (mounted) context.pop(true);
    } on ApiException catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final profile = ref.watch(currentProfileProvider);
    final points = [
      (Icons.upload_outlined, l10n.consentPointUpload),
      (Icons.auto_delete_outlined, l10n.consentPointDelete),
      (Icons.block_outlined, l10n.consentPointUse),
      (Icons.people_outline, l10n.consentPointPeople),
      (Icons.phone_iphone_outlined, l10n.consentPointLocal),
      (Icons.undo_outlined, l10n.consentPointRevoke),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountCloudAi)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(l10n.consentIntro, style: textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.md),
                  for (final (icon, text) in points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: AppColors.accent),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: Text(text, style: textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                  if (profile != null) Text(l10n.consentVersion(profile.consentVersion), style: textTheme.bodySmall),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => context.pop(false),
                      child: Text(l10n.consentDecline),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('consent-accept'),
                      onPressed: _busy || profile == null ? null : _accept,
                      child: Text(l10n.consentAccept),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
