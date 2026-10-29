import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_config.dart';
import 'token_store.dart';
import 'yuz_api.dart';

final apiBaseUriProvider = Provider<Uri?>((ref) => parseApiBaseUrl(configuredApiUrl));

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Null when this build has no API configured: account and cloud AI screens
/// then explain that instead of failing.
final yuzApiProvider = Provider<YuzApi?>((ref) {
  final baseUri = ref.watch(apiBaseUriProvider);
  if (baseUri == null) return null;
  final api = YuzApi(baseUri: baseUri, tokens: ref.watch(tokenStoreProvider));
  ref.onDispose(api.close);
  return api;
});
