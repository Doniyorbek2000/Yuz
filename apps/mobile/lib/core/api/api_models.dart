import 'package:flutter/foundation.dart';

import 'api_exception.dart';

T _field<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is T) return value;
  throw ApiException(ApiException.badResponse, message: 'field "$key" has the wrong type');
}

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.locale,
    required this.creditBalance,
    required this.premiumActive,
    required this.premiumUntil,
    required this.cloudAiConsent,
    required this.consentVersion,
  });

  factory UserProfile.fromJson(Map<String, Object?> json) {
    final consent = json['cloudAiConsent'];
    final consentMap = consent is Map ? consent.cast<String, Object?>() : const <String, Object?>{};
    return UserProfile(
      id: _field<String>(json, 'id'),
      email: _field<String>(json, 'email'),
      displayName: json['displayName'] as String?,
      locale: json['locale'] as String? ?? 'uz',
      creditBalance: _field<num>(json, 'creditBalance').toInt(),
      premiumActive: json['premiumActive'] == true,
      premiumUntil: _date(json['premiumUntil']),
      cloudAiConsent: consentMap['active'] == true,
      consentVersion: consentMap['currentVersion'] as String? ?? '',
    );
  }

  final String id;
  final String email;
  final String? displayName;
  final String locale;
  final int creditBalance;
  final bool premiumActive;
  final DateTime? premiumUntil;
  final bool cloudAiConsent;

  /// The consent text version the server currently requires.
  final String consentVersion;

  String get shownName => (displayName?.trim().isNotEmpty ?? false) ? displayName!.trim() : email;
}

enum CreditEntryKind { welcome, purchase, spend, refund, adjustment, unknown }

@immutable
class CreditEntry {
  const CreditEntry({required this.amount, required this.kind, required this.createdAt});

  factory CreditEntry.fromJson(Map<String, Object?> json) => CreditEntry(
    amount: _field<num>(json, 'amount').toInt(),
    kind: CreditEntryKind.values.firstWhere(
      (kind) => kind.name.toUpperCase() == json['kind'],
      orElse: () => CreditEntryKind.unknown,
    ),
    createdAt: _date(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
  );

  final int amount;
  final CreditEntryKind kind;
  final DateTime createdAt;
}

@immutable
class CreditsSummary {
  const CreditsSummary({required this.balance, required this.entries});

  factory CreditsSummary.fromJson(Map<String, Object?> json) => CreditsSummary(
    balance: _field<num>(json, 'balance').toInt(),
    entries: [
      for (final entry in json['entries'] as List? ?? const [])
        if (entry is Map) CreditEntry.fromJson(entry.cast<String, Object?>()),
    ],
  );

  final int balance;
  final List<CreditEntry> entries;
}

/// Wire names match the backend's AiJobType enum.
enum AiJobType {
  photoshoot('PHOTOSHOOT'),
  hairstyle('HAIRSTYLE'),
  makeup('MAKEUP'),
  background('BACKGROUND');

  const AiJobType(this.wire);

  final String wire;

  static AiJobType? fromWire(Object? value) => values.where((type) => type.wire == value).firstOrNull;
}

@immutable
class AiPrice {
  const AiPrice({required this.cost, required this.enabled});

  final int cost;

  /// False while no worker serves the type; the API refuses such jobs.
  final bool enabled;
}

Map<AiJobType, AiPrice> parsePricing(Map<String, Object?> json) => {
  for (final MapEntry(:key, :value) in json.entries)
    if (AiJobType.fromWire(key) case final type? when value is Map)
      type: AiPrice(cost: (value['cost'] as num? ?? 0).toInt(), enabled: value['enabled'] == true),
};

enum AiJobStatus {
  queued,
  running,
  succeeded,
  failed,
  cancelled;

  bool get isFinal => this == succeeded || this == failed || this == cancelled;
}

@immutable
class AiJob {
  const AiJob({
    required this.id,
    required this.type,
    required this.status,
    required this.cost,
    required this.error,
    required this.hasResult,
    required this.createdAt,
  });

  factory AiJob.fromJson(Map<String, Object?> json) {
    final status = AiJobStatus.values.where((s) => s.name.toUpperCase() == json['status']).firstOrNull;
    final type = AiJobType.fromWire(json['type']);
    if (status == null || type == null) {
      throw const ApiException(ApiException.badResponse, message: 'unknown job status or type');
    }
    return AiJob(
      id: _field<String>(json, 'id'),
      type: type,
      status: status,
      cost: _field<num>(json, 'cost').toInt(),
      error: json['error'] as String?,
      hasResult: json['hasResult'] == true,
      createdAt: _date(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final AiJobType type;
  final AiJobStatus status;
  final int cost;

  /// Failure reason reported by the worker (e.g. "invalid_input:no_person_detected").
  final String? error;
  final bool hasResult;
  final DateTime createdAt;
}

enum StoreProductKind { credits, premium }

@immutable
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.kind,
    required this.credits,
    required this.premiumDays,
    required this.platforms,
  });

  factory StoreProduct.fromJson(Map<String, Object?> json) => StoreProduct(
    id: _field<String>(json, 'id'),
    kind: json['kind'] == 'premium' ? StoreProductKind.premium : StoreProductKind.credits,
    credits: (json['credits'] as num?)?.toInt(),
    premiumDays: (json['premiumDays'] as num?)?.toInt(),
    platforms: [for (final p in json['platforms'] as List? ?? const []) p.toString()],
  );

  final String id;
  final StoreProductKind kind;
  final int? credits;
  final int? premiumDays;

  /// Stores whose server-side receipt verification is configured.
  final List<String> platforms;
}
