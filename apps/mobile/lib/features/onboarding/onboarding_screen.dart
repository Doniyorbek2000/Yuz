import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/preferences.dart';
import '../../core/theme/app_tokens.dart';
import '../../l10n/generated/app_localizations.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingCompletedProvider.notifier).set(true);
    if (mounted) context.go('/permissions?next=/home');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = [
      (Icons.face_retouching_natural, l10n.onboardingTitle1, l10n.onboardingBody1),
      (Icons.lock_outline_rounded, l10n.onboardingTitle2, l10n.onboardingBody2),
      (Icons.tune_rounded, l10n.onboardingTitle3, l10n.onboardingBody3),
    ];
    final isLast = _page == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(onPressed: _finish, child: Text(l10n.actionSkip)),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) {
                    final (icon, title, body) = pages[index];
                    return _OnboardingPage(icon: icon, title: title, body: body);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: AppDurations.medium,
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.accent : AppColors.outline,
                        borderRadius: const BorderRadius.all(AppRadii.pill),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: isLast
                    ? _finish
                    : () => _pageController.nextPage(duration: AppDurations.slow, curve: Curves.easeOutCubic),
                child: Text(isLast ? l10n.actionGetStarted : l10n.actionNext),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.accent.withValues(alpha: 0.35), AppColors.background]),
            ),
            child: Icon(icon, size: 64, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(title, textAlign: TextAlign.center, style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(body, textAlign: TextAlign.center, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
