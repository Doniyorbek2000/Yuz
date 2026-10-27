import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import 'camera_permission_service.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({required this.next, super.key});

  /// Route to continue to after the user decides.
  final String next;

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> with WidgetsBindingObserver {
  CameraPermissionState? _state;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from system settings: re-check.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await ref.read(cameraPermissionServiceProvider).status();
    if (!mounted) return;
    setState(() => _state = status);
    if (status == CameraPermissionState.granted && widget.next == '/camera') context.go('/camera');
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    final status = await ref.read(cameraPermissionServiceProvider).request();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _state = status;
    });
    if (status == CameraPermissionState.granted) context.go(widget.next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final blocked = _state == CameraPermissionState.permanentlyDenied || _state == CameraPermissionState.restricted;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => context.go(widget.next == '/camera' ? '/home' : widget.next),
                  child: Text(l10n.actionSkip),
                ),
              ),
              const Spacer(),
              const Icon(Icons.photo_camera_front_outlined, size: 72, color: AppColors.accent),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.permissionTitle, textAlign: TextAlign.center, style: textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.permissionBody, textAlign: TextAlign.center, style: textTheme.bodyMedium),
              if (_state == CameraPermissionState.denied || blocked) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  blocked ? l10n.permissionPermanentlyDenied : l10n.permissionDenied,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.warning),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _busy || _state == null
                    ? null
                    : blocked
                    ? () => ref.read(cameraPermissionServiceProvider).openSystemSettings()
                    : _request,
                child: Text(blocked ? l10n.actionOpenSettings : l10n.permissionGrant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
