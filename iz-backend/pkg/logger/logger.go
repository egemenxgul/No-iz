package logger

import (
	"os"
	"time"

	"github.com/rs/zerolog"
)

// New creates a configured zerolog.Logger.
// In development: pretty-printed, human-readable output.
// In production: structured JSON output.
func New(env string) zerolog.Logger {
	zerolog.TimeFieldFormat = time.RFC3339

	if env != "production" {
		return zerolog.New(zerolog.ConsoleWriter{
			Out:        os.Stderr,
			TimeFormat: "15:04:05",
		}).With().Timestamp().Caller().Logger()
	}

	return zerolog.New(os.Stderr).With().Timestamp().Logger()
}
