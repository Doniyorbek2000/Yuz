import '../../l10n/generated/app_localizations.dart';
import 'api_exception.dart';

/// User-facing text for an API, worker or client error code.
String apiErrorText(AppLocalizations l10n, String? code) {
  if (code == null) return l10n.errorUnknown;
  // Worker failures arrive as "invalid_input:<reason>".
  if (code.startsWith('invalid_input:')) {
    return switch (code.substring('invalid_input:'.length)) {
      'no_person_detected' => l10n.errorNoPerson,
      'image_too_large' => l10n.errorImageTooLarge,
      'unreadable_image' => l10n.errorUnsupportedImage,
      _ => l10n.errorProcessingFailed,
    };
  }
  return switch (code) {
    ApiException.network => l10n.errorNetwork,
    ApiException.timeout => l10n.errorTimeout,
    ApiException.sessionExpired => l10n.errorSessionExpired,
    ApiException.server || ApiException.badResponse || 'queue_unavailable' => l10n.errorServer,
    'invalid_credentials' => l10n.errorInvalidCredentials,
    'email_taken' => l10n.errorEmailTaken,
    'rate_limited' || 'http_429' => l10n.errorRateLimited,
    'invalid_password' => l10n.errorInvalidPassword,
    'insufficient_credits' => l10n.errorInsufficientCredits,
    'consent_required' || 'consent_outdated' => l10n.errorConsentRequired,
    'ai_type_unavailable' || 'provider_not_configured' => l10n.errorAiUnavailable,
    'unsupported_image' => l10n.errorUnsupportedImage,
    'image_too_large' => l10n.errorImageTooLarge,
    'processing_timeout' => l10n.errorProcessingTimeout,
    'cancelled' => l10n.errorJobCancelled,
    'file_error' => l10n.errorFile,
    'input_missing' || 'internal_error' || 'model_timeout' => l10n.errorProcessingFailed,
    _ => l10n.errorUnknown,
  };
}
