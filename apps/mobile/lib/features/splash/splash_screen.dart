import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/preferences.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/brand_mark.dart';
import '../../l10n/generated/app_localizations.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.holdDuration = const Duration(milliseconds: 900)});

  final Duration holdDuration;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.holdDuration, () {
      if (!mounted) return;
      final onboarded = ref.read(onboardingCompletedProvider);
      context.go(onboarded ? '/home' : '/onboarding');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 88),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.appTitle, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.splashTagline, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
