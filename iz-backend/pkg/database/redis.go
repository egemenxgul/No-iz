package database

import (
	"context"
	"fmt"

	"github.com/redis/go-redis/v9"
	"github.com/no-iz/iz-backend/pkg/config"
)

// NewRedis creates and validates a Redis client.
func NewRedis(cfg *config.Config) (*redis.Client, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:     cfg.RedisAddr(),
		Password: cfg.RedisPassword,
		DB:       cfg.RedisDB,
	})

	ctx := context.Background()
	if err := rdb.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("ping redis: %w", err)
	}

	return rdb, nil
}
