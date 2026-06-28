package economy

type Tier string

const (
	TierFree  Tier = "free"
	TierPlus  Tier = "plus"
	TierPro   Tier = "pro"
	TierElite Tier = "elite"
)

var TierPricing = map[Tier]int{
	TierFree:  0,
	TierPlus:  49,
	TierPro:   99,
	TierElite: 299,
}

type SubscriptionInfo struct {
	Tier                 Tier      `json:"tier"`
	PeriodEnd            string    `json:"period_end"`
	ScheduledDowngrade   *Tier     `json:"scheduled_downgrade,omitempty"`
	StorageUsedBytes     int64     `json:"storage_used_bytes"`
}

type Features struct {
	MaxUploadBytes int64 `json:"max_upload_bytes"`
	MaxStorageBytes int64 `json:"max_storage_bytes"`
	MaxGroupCallParticipants int `json:"max_group_call_participants"`
	HasVerifiedBadge bool `json:"has_verified_badge"`
	HasEliteBadge bool `json:"has_elite_badge"`
}

var TierFeatures = map[Tier]Features{
	TierFree: {
		MaxUploadBytes:           100 * 1024 * 1024,        // 100 MB
		MaxStorageBytes:          1 * 1024 * 1024 * 1024,   // 1 GB
		MaxGroupCallParticipants: 5,
		HasVerifiedBadge:         false,
		HasEliteBadge:            false,
	},
	TierPlus: {
		MaxUploadBytes:           2 * 1024 * 1024 * 1024,   // 2 GB
		MaxStorageBytes:          10 * 1024 * 1024 * 1024,  // 10 GB
		MaxGroupCallParticipants: 10,
		HasVerifiedBadge:         false,
		HasEliteBadge:            false,
	},
	TierPro: {
		MaxUploadBytes:           4 * 1024 * 1024 * 1024,   // 4 GB
		MaxStorageBytes:          50 * 1024 * 1024 * 1024,  // 50 GB
		MaxGroupCallParticipants: 20,
		HasVerifiedBadge:         true,
		HasEliteBadge:            false,
	},
	TierElite: {
		MaxUploadBytes:           10 * 1024 * 1024 * 1024,  // 10 GB
		MaxStorageBytes:          200 * 1024 * 1024 * 1024, // 200 GB
		MaxGroupCallParticipants: 1000,                     // effectively unlimited
		HasVerifiedBadge:         false,
		HasEliteBadge:            true,
	},
}

func GetFeatures(tier Tier) Features {
	if f, ok := TierFeatures[tier]; ok {
		return f
	}
	return TierFeatures[TierFree]
}
