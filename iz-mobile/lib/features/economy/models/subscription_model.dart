class Features {
  final int maxUploadBytes;
  final int maxStorageBytes;
  final int maxGroupCallParticipants;
  final bool hasVerifiedBadge;
  final bool hasEliteBadge;

  Features({
    required this.maxUploadBytes,
    required this.maxStorageBytes,
    required this.maxGroupCallParticipants,
    required this.hasVerifiedBadge,
    required this.hasEliteBadge,
  });

  factory Features.fromJson(Map<String, dynamic> json) {
    return Features(
      maxUploadBytes: json['max_upload_bytes'] as int? ?? 100 * 1024 * 1024,
      maxStorageBytes: json['max_storage_bytes'] as int? ?? 1024 * 1024 * 1024,
      maxGroupCallParticipants: json['max_group_call_participants'] as int? ?? 5,
      hasVerifiedBadge: json['has_verified_badge'] as bool? ?? false,
      hasEliteBadge: json['has_elite_badge'] as bool? ?? false,
    );
  }
}

class SubscriptionInfo {
  final String tier;
  final Features features;
  final int storageUsed;
  final int storageTotal;
  final String? periodEnd;
  final String? scheduledDowngrade;

  SubscriptionInfo({
    required this.tier,
    required this.features,
    required this.storageUsed,
    required this.storageTotal,
    this.periodEnd,
    this.scheduledDowngrade,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      tier: json['tier'] as String? ?? 'free',
      features: Features.fromJson(json['features'] as Map<String, dynamic>? ?? {}),
      storageUsed: json['storage_used'] as int? ?? 0,
      storageTotal: json['storage_total'] as int? ?? 1024 * 1024 * 1024,
      periodEnd: json['period_end'] as String?,
      scheduledDowngrade: json['scheduled_downgrade'] as String?,
    );
  }
}
