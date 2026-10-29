import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_models.dart';
import '../../../core/api/api_providers.dart';
import 'session_controller.dart';

/// Balance and history; re-fetched whenever the session changes.
final creditsProvider = FutureProvider.autoDispose<CreditsSummary?>((ref) async {
  final api = ref.watch(yuzApiProvider);
  if (api == null || ref.watch(currentProfileProvider) == null) return null;
  return api.credits();
});

final storeProductsProvider = FutureProvider.autoDispose<List<StoreProduct>>((ref) async {
  final api = ref.watch(yuzApiProvider);
  if (api == null || ref.watch(currentProfileProvider) == null) return const [];
  return api.products();
});

final aiPricingProvider = FutureProvider.autoDispose<Map<AiJobType, AiPrice>>((ref) async {
  final api = ref.watch(yuzApiProvider);
  if (api == null || ref.watch(currentProfileProvider) == null) return const {};
  return api.pricing();
});
