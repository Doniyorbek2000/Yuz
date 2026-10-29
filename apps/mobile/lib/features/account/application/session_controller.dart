import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_models.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/yuz_api.dart';

sealed class SessionState {
  const SessionState();
}

/// This build has no API URL; accounts and cloud AI are unavailable.
final class SessionUnconfigured extends SessionState {
  const SessionUnconfigured();
}

final class SignedOut extends SessionState {
  const SignedOut();
}

final class SignedIn extends SessionState {
  const SignedIn(this.profile);

  final UserProfile profile;
}

/// The account session. Loading the profile can fail offline: the state is
/// then an AsyncError and the UI offers a retry, the stored session stays.
class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    final api = ref.watch(yuzApiProvider);
    if (api == null) return const SessionUnconfigured();
    final subscription = api.sessionExpired.listen((_) => _set(const SignedOut()));
    ref.onDispose(subscription.cancel);
    if (!await api.hasSession) return const SignedOut();
    try {
      return SignedIn(await api.me());
    } on ApiException catch (error) {
      if (error.code == ApiException.sessionExpired) return const SignedOut();
      rethrow;
    }
  }

  YuzApi get _api {
    final api = ref.read(yuzApiProvider);
    if (api == null) throw StateError('No API configured');
    return api;
  }

  Future<void> login({required String email, required String password}) async {
    await _api.login(email: email.trim(), password: password);
    _set(SignedIn(await _api.me()));
  }

  Future<void> register({
    required String email,
    required String password,
    required String? displayName,
    required String locale,
  }) async {
    await _api.register(email: email.trim(), password: password, displayName: displayName, locale: locale);
    _set(SignedIn(await _api.me()));
  }

  /// Re-reads the profile (credits, consent, premium) after server-side changes.
  Future<void> refresh() async {
    if (state.value is! SignedIn) return;
    try {
      _set(SignedIn(await _api.me()));
    } on ApiException catch (error) {
      if (error.code == ApiException.sessionExpired) {
        _set(const SignedOut());
      } else {
        debugPrint('Profile refresh failed: ${error.code}');
      }
    }
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(build);
    if (ref.mounted) state = next;
  }

  Future<void> updateDisplayName(String name) async {
    _set(SignedIn(await _api.updateProfile(displayName: name.trim())));
  }

  Future<void> grantCloudAiConsent() async {
    final current = state.value;
    if (current is! SignedIn) throw StateError('Not signed in');
    await _api.grantCloudAiConsent(current.profile.consentVersion);
    if (ref.mounted) await refresh();
  }

  Future<void> revokeCloudAiConsent() async {
    await _api.revokeCloudAiConsent();
    if (ref.mounted) await refresh();
  }

  Future<void> logout() async {
    await _api.logout();
    _set(const SignedOut());
  }

  Future<void> deleteAccount(String password) async {
    await _api.deleteAccount(password);
    _set(const SignedOut());
  }

  /// Calls outlive their screen; a disposed provider simply drops the result.
  void _set(SessionState value) {
    if (ref.mounted) state = AsyncData(value);
  }
}

final sessionControllerProvider = AsyncNotifierProvider<SessionController, SessionState>(SessionController.new);

/// The signed-in profile, or null.
final currentProfileProvider = Provider<UserProfile?>((ref) {
  final session = ref.watch(sessionControllerProvider).value;
  return session is SignedIn ? session.profile : null;
});
