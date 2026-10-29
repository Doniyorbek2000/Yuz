import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_models.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/session_controller.dart';
import 'account_widgets.dart';

/// Saves the data export where the user chooses (system save dialog).
typedef ExportSaver = Future<bool> Function(String fileName, List<int> bytes);

final exportSaverProvider = Provider<ExportSaver>(
  (ref) => (fileName, bytes) async {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: 'application/json',
    );
    return saved != null;
  },
);

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: switch (session) {
        AsyncData(value: SessionUnconfigured()) => MessagePanel(
          icon: Icons.cloud_off_outlined,
          title: l10n.accountUnconfiguredTitle,
          body: l10n.accountUnconfiguredBody,
        ),
        AsyncData(value: SignedOut()) => MessagePanel(
          icon: Icons.person_outline,
          title: l10n.accountTitle,
          body: l10n.accountSignedOutBody,
          actions: [
            FilledButton(
              key: const ValueKey('account-sign-in'),
              onPressed: () => context.push('/account/auth'),
              child: Text(l10n.accountSignIn),
            ),
            OutlinedButton(
              key: const ValueKey('account-register'),
              onPressed: () => context.push('/account/auth?mode=register'),
              child: Text(l10n.accountCreate),
            ),
          ],
        ),
        AsyncData(value: SignedIn(:final profile)) => _ProfileView(profile: profile),
        AsyncError() => MessagePanel(
          icon: Icons.wifi_off_outlined,
          title: l10n.accountLoadFailed,
          actions: [
            FilledButton(
              onPressed: () => ref.read(sessionControllerProvider.notifier).retry(),
              child: Text(l10n.actionRetry),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ProfileView extends ConsumerStatefulWidget {
  const _ProfileView({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<_ProfileView> {
  bool _busy = false;

  SessionController get _session => ref.read(sessionControllerProvider.notifier);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleConsent(bool allow) async {
    final l10n = AppLocalizations.of(context);
    if (allow) {
      await context.push('/account/consent');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountRevokeTitle),
        content: Text(l10n.accountRevokeBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.accountRevokeConfirm)),
        ],
      ),
    );
    if (confirmed == true) await _run(_session.revokeCloudAiConsent);
  }

  Future<void> _editName() async {
    final l10n = AppLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _TextPromptDialog(
        title: l10n.accountDisplayName,
        initial: widget.profile.displayName ?? '',
        confirmLabel: l10n.actionSave,
        maxLength: 60,
      ),
    );
    if (name != null) await _run(() => _session.updateDisplayName(name));
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _run(() async {
      final api = ref.read(yuzApiProvider);
      if (api == null) return;
      final bytes = await api.exportData();
      final saved = await ref.read(exportSaverProvider)('yuz-data-export.json', bytes);
      if (saved) messenger.showSnackBar(SnackBar(content: Text(l10n.accountExportDone)));
    });
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final password = await showDialog<String>(
      context: context,
      builder: (context) => _TextPromptDialog(
        title: l10n.accountDelete,
        message: l10n.accountDeleteBody,
        label: l10n.authPassword,
        confirmLabel: l10n.accountDeleteConfirm,
        obscure: true,
        destructive: true,
      ),
    );
    if (password == null || password.isEmpty) return;
    await _run(() async {
      await _session.deleteAccount(password);
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final profile = widget.profile;
    final dateFormat = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());
    return AbsorbPointer(
      absorbing: _busy,
      child: RefreshIndicator(
        onRefresh: _session.refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                child: Text(profile.shownName.characters.first.toUpperCase()),
              ),
              title: Text(profile.shownName, style: textTheme.titleMedium),
              subtitle: Text(profile.email),
              trailing: IconButton(
                tooltip: l10n.accountDisplayName,
                icon: const Icon(Icons.edit_outlined),
                onPressed: _editName,
              ),
            ),
            const Divider(),
            ListTile(
              key: const ValueKey('account-store'),
              leading: const Icon(Icons.toll_outlined),
              title: Text(l10n.accountStore),
              subtitle: Text(
                '${l10n.accountCredits(profile.creditBalance)} · '
                '${profile.premiumActive && profile.premiumUntil != null ? l10n.accountPremiumActive(dateFormat.format(profile.premiumUntil!)) : l10n.accountPremiumInactive}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/account/store'),
            ),
            SwitchListTile(
              key: const ValueKey('account-consent'),
              secondary: const Icon(Icons.cloud_outlined),
              value: profile.cloudAiConsent,
              onChanged: _toggleConsent,
              title: Text(l10n.accountCloudAi),
              subtitle: Text(profile.cloudAiConsent ? l10n.accountCloudAiOn : l10n.accountCloudAiOff),
            ),
            const Divider(),
            ListTile(leading: const Icon(Icons.download_outlined), title: Text(l10n.accountExport), onTap: _export),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(l10n.featureHelp),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/help'),
            ),
            ListTile(
              key: const ValueKey('account-sign-out'),
              leading: const Icon(Icons.logout),
              title: Text(l10n.accountSignOut),
              onTap: () => _run(_session.logout),
            ),
            ListTile(
              key: const ValueKey('account-delete'),
              leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
              title: Text(l10n.accountDelete, style: const TextStyle(color: AppColors.danger)),
              onTap: _delete,
            ),
          ],
        ),
      ),
    );
  }
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.confirmLabel,
    this.message,
    this.label,
    this.initial = '',
    this.obscure = false,
    this.destructive = false,
    this.maxLength,
  });

  final String title;
  final String confirmLabel;
  final String? message;
  final String? label;
  final String initial;
  final bool obscure;
  final bool destructive;
  final int? maxLength;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[Text(widget.message!), const SizedBox(height: AppSpacing.md)],
            TextField(
              key: const ValueKey('prompt-field'),
              controller: _controller,
              autofocus: true,
              obscureText: widget.obscure,
              maxLength: widget.maxLength,
              decoration: InputDecoration(labelText: widget.label),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('prompt-confirm'),
          style: widget.destructive ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
