package story

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// Create persists a new story in the database.
func (r *Repository) Create(ctx context.Context, s *Story) error {
	query := `
		INSERT INTO stories (user_id, media_url, caption, media_type, expires_at)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, created_at
	`
	return r.db.QueryRow(ctx, query, s.UserID, s.MediaURL, s.Caption, s.MediaType, s.ExpiresAt).Scan(&s.ID, &s.CreatedAt)
}

// Delete deletes a user's own story.
func (r *Repository) Delete(ctx context.Context, storyID, userID uuid.UUID) error {
	query := `
		DELETE FROM stories
		WHERE id = $1 AND user_id = $2
	`
	_, err := r.db.Exec(ctx, query, storyID, userID)
	return err
}

// ListActiveFromFriends retrieves unexpired stories posted by the user's accepted friends.
func (r *Repository) ListActiveFromFriends(ctx context.Context, userID uuid.UUID) ([]*FriendStoryFeed, error) {
	// First, fetch friends and their unexpired stories.
	// A friend is someone who has an 'accepted' friendship record with the requesting user.
	query := `
		SELECT 
			s.id, s.user_id, s.media_url, s.caption, s.media_type, s.created_at, s.expires_at,
			u.username, u.display_name, u.avatar_url
		FROM stories s
		JOIN users u ON u.id = s.user_id
		JOIN friendships f ON (
			(f.user_id1 = LEAST($1, s.user_id) AND f.user_id2 = GREATEST($1, s.user_id))
		)
		WHERE f.status = 'accepted'
		  AND s.expires_at > NOW()
		  -- Exclude blocked users to ensure anti-spam compliance
		  AND NOT EXISTS (
		      SELECT 1 FROM blocks b 
		      WHERE (b.blocker_id = $1 AND b.blocked_id = s.user_id)
		         OR (b.blocker_id = s.user_id AND b.blocked_id = $1)
		  )
		ORDER BY u.id, s.created_at ASC
	`
	rows, err := r.db.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	// Group stories by user (friend) dynamically.
	feedMap := make(map[uuid.UUID]*FriendStoryFeed)
	var orderedUserIDs []uuid.UUID

	for rows.Next() {
		s := &Story{}
		var username, displayName, avatarURL string
		var friendID uuid.UUID

		err := rows.Scan(
			&s.ID, &s.UserID, &s.MediaURL, &s.Caption, &s.MediaType, &s.CreatedAt, &s.ExpiresAt,
			&username, &displayName, &avatarURL,
		)
		if err != nil {
			return nil, err
		}

		friendID = s.UserID
		if _, exists := feedMap[friendID]; !exists {
			feedMap[friendID] = &FriendStoryFeed{
				UserID:      friendID,
				Username:    username,
				DisplayName: displayName,
				AvatarURL:   avatarURL,
				Stories:     []*Story{},
			}
			orderedUserIDs = append(orderedUserIDs, friendID)
		}

		feedMap[friendID].Stories = append(feedMap[friendID].Stories, s)
	}

	feeds := make([]*FriendStoryFeed, 0, len(orderedUserIDs))
	for _, id := range orderedUserIDs {
		feeds = append(feeds, feedMap[id])
	}

	return feeds, rows.Err()
}
