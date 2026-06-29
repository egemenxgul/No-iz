package server

import (
	"context"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
)

// RateLimiter enforces per-IP request limits using Redis sliding-window counters.
// Each call to Middleware creates an independent limiter with its own bucket key prefix,
// limit, and window so different endpoints can have different thresholds.
type RateLimiter struct {
	rdb    *redis.Client
	prefix string        // Redis key prefix — used to isolate endpoint buckets
	limit  int           // max requests allowed in the window
	window time.Duration // sliding window size
}

// NewRateLimiter creates a new RateLimiter.
//
//	prefix — unique per-endpoint string, e.g. "rl:auth:login"
//	limit  — max requests per IP per window
//	window — duration of the sliding window (e.g. 1*time.Minute)
func NewRateLimiter(rdb *redis.Client, prefix string, limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{rdb: rdb, prefix: prefix, limit: limit, window: window}
}

// Middleware returns an http.Handler middleware that rate-limits by client IP.
// When the limit is exceeded it writes 429 Too Many Requests with a
// Retry-After header indicating when the window resets.
func (rl *RateLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := realIP(r)
		key := fmt.Sprintf("%s:%s", rl.prefix, ip)

		count, ttl, err := rl.increment(r.Context(), key)
		if err != nil {
			// Fail-closed policy: if Redis is unavailable, block requests.
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte(`{"error":"service temporarily unavailable due to internal error"}`))
			return
		}

		// Set informational rate-limit headers on every response.
		remaining := rl.limit - count
		if remaining < 0 {
			remaining = 0
		}
		w.Header().Set("X-RateLimit-Limit", strconv.Itoa(rl.limit))
		w.Header().Set("X-RateLimit-Remaining", strconv.Itoa(remaining))
		w.Header().Set("X-RateLimit-Reset", strconv.FormatInt(time.Now().Add(ttl).Unix(), 10))

		if count > rl.limit {
			retryAfter := int(ttl.Seconds())
			if retryAfter < 1 {
				retryAfter = 1
			}
			w.Header().Set("Retry-After", strconv.Itoa(retryAfter))
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusTooManyRequests)
			_, _ = w.Write([]byte(`{"error":"too many requests, please try again later"}`))
			return
		}

		next.ServeHTTP(w, r)
	})
}

// increment atomically increments the counter for the given key and returns
// (currentCount, remainingTTL, error). On first request the key is created
// with the configured window TTL via a Lua script to avoid TOCTOU race conditions.
func (rl *RateLimiter) increment(ctx context.Context, key string) (int, time.Duration, error) {
	// Lua script: INCR + EXPIRE in a single atomic round-trip.
	// Returns {count, pttl_ms}.
	const luaScript = `
local current = redis.call("INCR", KEYS[1])
if current == 1 then
	redis.call("PEXPIRE", KEYS[1], ARGV[1])
end
local pttl = redis.call("PTTL", KEYS[1])
return {current, pttl}
`
	windowMS := rl.window.Milliseconds()
	result, err := redis.NewScript(luaScript).Run(ctx, rl.rdb, []string{key}, windowMS).Int64Slice()
	if err != nil {
		return 0, 0, err
	}

	count := int(result[0])
	pttlMS := result[1]
	if pttlMS < 0 {
		pttlMS = windowMS
	}
	ttl := time.Duration(pttlMS) * time.Millisecond

	return count, ttl, nil
}

// realIP extracts the most specific client IP, preferring the value set by
// chi's middleware.RealIP (which already respects X-Forwarded-For / X-Real-IP)
// and falling back to r.RemoteAddr.
func realIP(r *http.Request) string {
	// chi's RealIP middleware stores the resolved IP in RemoteAddr.
	ip := r.RemoteAddr
	// Strip port if present.
	for i := len(ip) - 1; i >= 0; i-- {
		if ip[i] == ':' {
			ip = ip[:i]
			break
		}
	}
	return ip
}
