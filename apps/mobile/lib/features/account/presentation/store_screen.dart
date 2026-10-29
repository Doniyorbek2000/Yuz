import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_models.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/feature_catalog.dart';
import '../application/account_data.dart';
import '../application/session_controller.dart';
import 'account_widgets.dart';

/// Balance, prices, history and store products. Purchases stay disabled
/// until store products and server-side receipt verification are set up.
class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.accountStore)),
        body: MessagePanel(icon: Icons.person_outline, title: l10n.accountSignedOutBody),
      );
    }
    final credits = ref.watch(creditsProvider);
    final products = ref.watch(storeProductsProvider).value ?? const <StoreProduct>[];
    final pricing = ref.watch(aiPricingProvider).value ?? const <AiJobType, AiPrice>{};
    final purchasable = products.any((product) => product.platforms.isNotEmpty);
    final dateFormat = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountStore)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(creditsProvider);
          ref.invalidate(storeProductsProvider);
          await ref.read(sessionControllerProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.storeBalance, style: textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      l10n.accountCredits(credits.value?.balance ?? profile.creditBalance),
                      key: const ValueKey('store-balance'),
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      profile.premiumActive && profile.premiumUntil != null
                          ? l10n.accountPremiumActive(dateFormat.format(profile.premiumUntil!))
                          : l10n.accountPremiumInactive,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (!purchasable)
              Card(
                key: const ValueKey('store-blocked'),
                color: AppColors.surfaceRaised,
                child: ListTile(
                  leading: const Icon(Icons.lock_clock_outlined, color: AppColors.warning),
                  title: Text(l10n.storeBlockedTitle),
                  subtitle: Text(l10n.storeBlockedBody),
                ),
              ),
            for (final product in products)
              ListTile(
                leading: Icon(
                  product.kind == StoreProductKind.premium ? Icons.workspace_premium_outlined : Icons.toll_outlined,
                ),
                title: Text(
                  product.kind == StoreProductKind.premium
                      ? l10n.storePremium(product.premiumDays ?? 0)
                      : l10n.accountCredits(product.credits ?? 0),
                ),
                // Store purchase flow is BLOCKED (no store credentials); never fake a sale.
                trailing: OutlinedButton(onPressed: null, child: Text(l10n.storeUnavailable)),
              ),
            if (pricing.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.storePrices, style: textTheme.titleMedium),
              for (final MapEntry(key: type, value: price) in pricing.entries)
                ListTile(
                  dense: true,
                  title: Text(_featureFor(type).label(l10n)),
                  subtitle: price.enabled ? null : Text(l10n.statusBlocked),
                  trailing: Text(l10n.accountCredits(price.cost)),
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(l10n.storeHistory, style: textTheme.titleMedium),
            switch (credits) {
              AsyncData(value: final summary?) when summary.entries.isNotEmpty => Column(
                children: [
                  for (final entry in summary.entries)
                    ListTile(
                      dense: true,
                      title: Text(_kindLabel(l10n, entry.kind)),
                      subtitle: Text(dateFormat.format(entry.createdAt)),
                      trailing: Text(
                        entry.amount > 0 ? '+${entry.amount}' : '${entry.amount}',
                        style: textTheme.titleSmall?.copyWith(
                          color: entry.amount > 0 ? AppColors.success : AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              AsyncError() => ListTile(
                title: Text(l10n.accountLoadFailed),
                trailing: TextButton(onPressed: () => ref.invalidate(creditsProvider), child: Text(l10n.actionRetry)),
              ),
              AsyncLoading() => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              _ => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(l10n.storeHistoryEmpty, style: textTheme.bodyMedium),
              ),
            },
          ],
        ),
      ),
    );
  }

  static AppFeature _featureFor(AiJobType type) => switch (type) {
    AiJobType.photoshoot => AppFeature.aiPhotoshoot,
    AiJobType.hairstyle => AppFeature.aiHairstyle,
    AiJobType.makeup => AppFeature.aiMakeup,
    AiJobType.background => AppFeature.aiBackground,
  };

  static String _kindLabel(AppLocalizations l10n, CreditEntryKind kind) => switch (kind) {
    CreditEntryKind.welcome => l10n.creditKindWelcome,
    CreditEntryKind.purchase => l10n.creditKindPurchase,
    CreditEntryKind.spend => l10n.creditKindSpend,
    CreditEntryKind.refund => l10n.creditKindRefund,
    CreditEntryKind.adjustment || CreditEntryKind.unknown => l10n.creditKindAdjustment,
  };
}
