package call

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/no-iz/iz-backend/internal/economy"
	"github.com/rs/zerolog"
)

var (
	ErrCallNotFound  = errors.New("call not found")
	ErrUnauthorized  = errors.New("not a participant in this call")
	ErrCalleeOffline = errors.New("callee is offline")
	ErrCalleeBusy    = errors.New("callee is busy in another call")
)

// Broadcaster is the WebSocket hub interface (avoids import cycle).
type Broadcaster interface {
	Deliver(recipientID uuid.UUID, data []byte) bool
	IsOnline(userID uuid.UUID) bool
}

// SocialRepository defines the interface for checking blocks from call service.
type SocialRepository interface {
	HasBlocked(ctx context.Context, blocker, blocked uuid.UUID) (bool, error)
}

// NotificationService interface abstraction
type NotificationService interface{}

// EconomyService interface abstraction
type EconomyService interface {
	GetUserLimits(ctx context.Context, userID uuid.UUID) (economy.Features, economy.Tier, int64, error)
}

// AuthService interface abstraction
type AuthService interface {
	ValidateDeclineToken(tokenStr string) (uuid.UUID, error)
}

// Service provides call signaling logic.
type Service struct {
	repo            *Repository
	broadcaster     Broadcaster
	notificationSvc NotificationService
	economySvc      EconomyService
	authSvc         AuthService
	socialRepo      SocialRepository
	log             zerolog.Logger
}

// NewService creates a new call Service.
func NewService(
	repo *Repository,
	broadcaster Broadcaster,
	notificationSvc NotificationService,
	economySvc EconomyService,
	authSvc AuthService,
	log zerolog.Logger,
) *Service {
	return &Service{
		repo:            repo,
		broadcaster:     broadcaster,
		notificationSvc: notificationSvc,
		economySvc:      economySvc,
		authSvc:         authSvc,
		log:             log.With().Str("svc", "call").Logger(),
	}
}

// SetSocialRepo sets the social repository for block checking.
func (s *Service) SetSocialRepo(sr SocialRepository) {
	s.socialRepo = sr
}

// ─── 1-1 Call Signaling ───────────────────────────────────────────────────────

// Offer initiates a call from callerID to the callee specified in the payload.
// It persists the call record and relays the SDP offer to the callee.
func (s *Service) Offer(ctx context.Context, callerID uuid.UUID, raw []byte) (*Call, error) {
	var p CallOfferPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return nil, fmt.Errorf("invalid call_offer payload")
	}

	calleeID, err := uuid.Parse(p.CalleeID)
	if err != nil {
		return nil, fmt.Errorf("invalid callee_id")
	}
	if calleeID == callerID {
		return nil, fmt.Errorf("cannot call yourself")
	}

	// Check if callee has blocked caller
	if s.socialRepo != nil {
		blocked, err := s.socialRepo.HasBlocked(ctx, calleeID, callerID)
		if err == nil && blocked {
			s.log.Info().Str("caller", callerID.String()).Str("callee", calleeID.String()).Msg("call blocked by callee")
			return nil, fmt.Errorf("this user has blocked you")
		}
	}

	// Check if callee is busy
	busy, err := s.repo.HasActiveCall(ctx, calleeID)
	if err != nil {
		return nil, err
	}

	call := &Call{
		CallType: p.CallType,
		Status:   StatusRinging,
		CallerID: callerID,
		CalleeID: &calleeID,
	}
	if call.CallType == "" {
		call.CallType = CallTypeAudio
	}

	// Determine if ForceRelay should be active
	callerRelay, _ := s.repo.GetRelayCalls(ctx, callerID)
	calleeRelay, _ := s.repo.GetRelayCalls(ctx, calleeID)

	if callerRelay || calleeRelay {
		call.ForceRelay = true
		s.log.Info().Str("call_id", call.ID.String()).Msg("forced relay enabled for call due to privacy settings")
	}

	if err := s.repo.CreateCall(ctx, call); err != nil {
		return nil, fmt.Errorf("create call record: %w", err)
	}

	if busy {
		_ = s.repo.SetBusy(ctx, call.ID)
		call.Status = StatusBusy
		s.log.Info().Str("call_id", call.ID.String()).Msg("callee busy")
		return call, ErrCalleeBusy
	}

	// Relay incoming_call to callee
	if !s.broadcaster.IsOnline(calleeID) {
		_ = s.repo.Miss(ctx, call.ID)
		call.Status = StatusMissed
		return call, ErrCalleeOffline
	}

	s.deliver(calleeID, EventIncomingCall, IncomingCallPush{
		CallID:   call.ID.String(),
		CallerID: callerID.String(),
		CallType: call.CallType,
		SDP:      p.SDP,
	})

	s.log.Info().Str("call_id", call.ID.String()).
		Str("caller", callerID.String()).Str("callee", calleeID.String()).Msg("call ringing")

	return call, nil
}

// Answer accepts an incoming call and relays the SDP answer to the caller.
func (s *Service) Answer(ctx context.Context, calleeID uuid.UUID, raw []byte) error {
	var p CallAnswerPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return fmt.Errorf("invalid call_answer payload")
	}

	callID, err := uuid.Parse(p.CallID)
	if err != nil {
		return fmt.Errorf("invalid call_id")
	}

	call, err := s.repo.GetCall(ctx, callID)
	if err != nil {
		return ErrCallNotFound
	}
	if call.CalleeID == nil || *call.CalleeID != calleeID {
		return ErrUnauthorized
	}

	if err := s.repo.Accept(ctx, callID); err != nil {
		return err
	}

	// Relay call_accepted + SDP answer to caller
	s.deliver(call.CallerID, EventCallAccepted, CallAcceptedPush{
		CallID:   callID.String(),
		CalleeID: calleeID.String(),
		SDP:      p.SDP,
	})

	s.log.Info().Str("call_id", callID.String()).Msg("call accepted")
	return nil
}

// Reject declines an incoming call.
func (s *Service) Reject(ctx context.Context, calleeID uuid.UUID, raw []byte) error {
	var p CallRejectPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return fmt.Errorf("invalid call_reject payload")
	}

	callID, err := uuid.Parse(p.CallID)
	if err != nil {
		return fmt.Errorf("invalid call_id")
	}

	call, err := s.repo.GetCall(ctx, callID)
	if err != nil {
		return ErrCallNotFound
	}
	if call.CalleeID == nil || *call.CalleeID != calleeID {
		return ErrUnauthorized
	}

	if err := s.repo.Reject(ctx, callID); err != nil {
		return err
	}

	s.deliver(call.CallerID, EventCallRejected, CallRejectedPush{
		CallID:   callID.String(),
		CalleeID: calleeID.String(),
		Reason:   p.Reason,
	})

	s.log.Info().Str("call_id", callID.String()).Msg("call rejected")
	return nil
}

// End terminates an active call.
func (s *Service) End(ctx context.Context, userID uuid.UUID, raw []byte) error {
	var p CallEndPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return fmt.Errorf("invalid call_end payload")
	}

	callID, err := uuid.Parse(p.CallID)
	if err != nil {
		return fmt.Errorf("invalid call_id")
	}

	call, err := s.repo.GetCall(ctx, callID)
	if err != nil {
		return ErrCallNotFound
	}

	// Verify participant
	isCaller := call.CallerID == userID
	isCallee := call.CalleeID != nil && *call.CalleeID == userID
	
	// Query active participants in DB for group call verification
	participants, _ := s.repo.ActiveParticipants(ctx, callID)
	isGroupParticipant := false
	for _, pid := range participants {
		if pid == userID {
			isGroupParticipant = true
			break
		}
	}

	if !isCaller && !isCallee && !isGroupParticipant {
		return ErrUnauthorized
	}

	if err := s.repo.End(ctx, callID); err != nil {
		return err
	}

	ended := CallEndedPush{CallID: callID.String(), EndedBy: userID.String()}

	// Notify the other party
	if isCaller && call.CalleeID != nil {
		s.deliver(*call.CalleeID, EventCallEnded, ended)
	} else if isCallee {
		s.deliver(call.CallerID, EventCallEnded, ended)
	}

	// For group calls (where CalleeID is nil), notify all active participants
	if call.CalleeID == nil {
		for _, pid := range participants {
			if pid != userID {
				s.deliver(pid, EventCallEnded, ended)
			}
		}
	}

	s.log.Info().Str("call_id", callID.String()).Str("ended_by", userID.String()).Msg("call ended")
	return nil
}

// DeclineCallREST ends the call via REST API without requiring participant verification (auth done via token)
func (s *Service) DeclineCallREST(ctx context.Context, callID uuid.UUID) error {
	call, err := s.repo.GetCall(ctx, callID)
	if err != nil {
		return ErrCallNotFound
	}
	if err := s.repo.End(ctx, callID); err != nil {
		return err
	}
	s.log.Info().Str("call_id", callID.String()).Msg("call declined via rest")
	
	ended := CallEndedPush{CallID: callID.String(), EndedBy: "system"}
	s.deliver(call.CallerID, EventCallEnded, ended)
	if call.CalleeID != nil {
		s.deliver(*call.CalleeID, EventCallEnded, ended)
	}
	return nil
}

// ValidateDeclineToken delegates to auth service
func (s *Service) ValidateDeclineToken(tokenStr string) (uuid.UUID, error) {
	if s.authSvc != nil {
		return s.authSvc.ValidateDeclineToken(tokenStr)
	}
	return uuid.Nil, fmt.Errorf("auth service not available")
}

// RelayICE forwards an ICE candidate to the specified target peer.
func (s *Service) RelayICE(ctx context.Context, fromID uuid.UUID, raw []byte) error {
	var p ICECandidatePayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return fmt.Errorf("invalid ice_candidate payload")
	}

	targetID, err := uuid.Parse(p.TargetID)
	if err != nil {
		return fmt.Errorf("invalid target_id")
	}

	callID, err := uuid.Parse(p.CallID)
	if err == nil {
		if call, err := s.repo.GetCall(ctx, callID); err == nil && call.ForceRelay {
			var candMap map[string]interface{}
			if err := json.Unmarshal([]byte(p.Candidate), &candMap); err == nil {
				candidateStr, ok := candMap["candidate"].(string)
				if ok && !strings.Contains(candidateStr, "typ relay") {
					// Drop non-relay candidate
					return nil
				}
			}
		}
	}

	s.deliver(targetID, EventICECandidate, ICECandidatePush{
		CallID:    p.CallID,
		FromID:    fromID.String(),
		Candidate: p.Candidate,
	})
	return nil
}

// ─── Group Call Signaling ─────────────────────────────────────────────────────

// GroupOffer relays a WebRTC offer from one group member to a specific peer.
// In a mesh topology each member establishes a P2P connection to every other member.
func (s *Service) GroupOffer(ctx context.Context, fromID uuid.UUID, raw []byte) error {
	var p GroupCallOfferPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return fmt.Errorf("invalid group_call_offer payload")
	}

	targetID, err := uuid.Parse(p.TargetID)
	if err != nil {
		return fmt.Errorf("invalid target_id")
	}

	// Relay the offer — same payload structure with added from_id
	type relayPayload struct {
		GroupCallOfferPayload
		FromID string `json:"from_id"`
	}
	s.deliver(targetID, EventGroupCallOffer, relayPayload{
		GroupCallOfferPayload: p,
		FromID:                fromID.String(),
	})
	return nil
}

// GroupJoin registers a user as an active participant in a group call.
func (s *Service) GroupJoin(ctx context.Context, userID uuid.UUID, raw []byte) error {
	var p GroupCallJoinPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return fmt.Errorf("invalid group_call_join payload")
	}

	callID, err := uuid.Parse(p.CallID)
	if err != nil {
		return fmt.Errorf("invalid call_id")
	}

	// Ensure the call record exists in the database.
	_, err = s.repo.GetCall(ctx, callID)
	if err != nil {
		var groupID *uuid.UUID
		if p.GroupID != "" {
			if gID, err := uuid.Parse(p.GroupID); err == nil {
				groupID = &gID
			}
		}
		call := &Call{
			ID:        callID,
			CallType:  CallTypeAudio, // Default to audio, can negotiate video inside mesh
			Status:    StatusActive,
			CallerID:  userID,
			GroupID:   groupID,
			RingingAt: time.Now(),
			CreatedAt: time.Now(),
		}
		if err := s.repo.CreateCallWithID(ctx, call); err != nil {
			s.log.Error().Err(err).Str("call_id", callID.String()).Msg("failed to create group call on join")
		}
	}

	if err := s.repo.AddParticipant(ctx, callID, userID); err != nil {
		return err
	}

	// Notify existing participants
	participants, _ := s.repo.ActiveParticipants(ctx, callID)
	for _, pid := range participants {
		if pid != userID {
			s.deliver(pid, EventGroupCallMember, GroupCallMemberPush{
				CallID: callID.String(),
				UserID: userID.String(),
				Action: "joined",
			})
		}
	}
	return nil
}

// GroupLeave removes a user from a group call.
func (s *Service) GroupLeave(ctx context.Context, userID uuid.UUID, raw []byte) error {
	var p GroupCallLeavePayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return fmt.Errorf("invalid group_call_leave payload")
	}

	callID, err := uuid.Parse(p.CallID)
	if err != nil {
		return fmt.Errorf("invalid call_id")
	}

	if err := s.repo.RemoveParticipant(ctx, callID, userID); err != nil {
		return err
	}

	// Notify remaining participants
	participants, _ := s.repo.ActiveParticipants(ctx, callID)
	for _, pid := range participants {
		s.deliver(pid, EventGroupCallMember, GroupCallMemberPush{
			CallID: callID.String(),
			UserID: userID.String(),
			Action: "left",
		})
	}
	return nil
}

// CallHistory returns call history for a user.
func (s *Service) CallHistory(ctx context.Context, userID uuid.UUID, limit int) ([]*Call, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	return s.repo.CallHistory(ctx, userID, limit, time.Time{})
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func (s *Service) deliver(targetID uuid.UUID, eventType string, payload interface{}) {
	type envelope struct {
		Type    string      `json:"type"`
		Payload interface{} `json:"payload"`
	}
	data, _ := json.Marshal(envelope{Type: eventType, Payload: payload})
	s.broadcaster.Deliver(targetID, data)
}

// ─── messaging.CallSvc adapter methods ───────────────────────────────────────
// These thin wrappers satisfy the CallSvc interface used in messaging.Handler
// to avoid an import cycle (messaging ↔ call).

func (s *Service) OfferRaw(ctx context.Context, callerID uuid.UUID, raw []byte) error {
	// Extract the payload portion (WS frame wraps it in {"type":..., "payload":{...}})
	var frame struct {
		Payload json.RawMessage `json:"payload"`
	}
	_ = json.Unmarshal(raw, &frame)
	if frame.Payload == nil {
		frame.Payload = raw
	}
	_, err := s.Offer(ctx, callerID, frame.Payload)
	return err
}

func (s *Service) AnswerRaw(ctx context.Context, calleeID uuid.UUID, raw []byte) error {
	payload := unwrapPayload(raw)
	return s.Answer(ctx, calleeID, payload)
}

func (s *Service) RejectRaw(ctx context.Context, calleeID uuid.UUID, raw []byte) error {
	payload := unwrapPayload(raw)
	return s.Reject(ctx, calleeID, payload)
}

func (s *Service) EndRaw(ctx context.Context, userID uuid.UUID, raw []byte) error {
	payload := unwrapPayload(raw)
	return s.End(ctx, userID, payload)
}

func (s *Service) RelayICERaw(ctx context.Context, fromID uuid.UUID, raw []byte) error {
	payload := unwrapPayload(raw)
	return s.RelayICE(ctx, fromID, payload)
}

func (s *Service) GroupOfferRaw(ctx context.Context, fromID uuid.UUID, raw []byte) error {
	payload := unwrapPayload(raw)
	return s.GroupOffer(ctx, fromID, payload)
}

func (s *Service) GroupJoinRaw(ctx context.Context, userID uuid.UUID, raw []byte) error {
	payload := unwrapPayload(raw)
	return s.GroupJoin(ctx, userID, payload)
}

func (s *Service) GroupLeaveRaw(ctx context.Context, userID uuid.UUID, raw []byte) error {
	payload := unwrapPayload(raw)
	return s.GroupLeave(ctx, userID, payload)
}

// Promote transitions a 1-1 call into a group call by inviting another user.
func (s *Service) Promote(ctx context.Context, fromID uuid.UUID, raw []byte) error {
	var p CallPromotePayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return fmt.Errorf("invalid call_promote payload")
	}

	targetID, err := uuid.Parse(p.TargetID)
	if err != nil {
		return fmt.Errorf("invalid target_id")
	}

	s.deliver(targetID, EventCallPromote, CallPromotePush{
		CallID: p.CallID,
		FromID: fromID.String(),
	})
	return nil
}

func (s *Service) PromoteRaw(ctx context.Context, userID uuid.UUID, raw []byte) error {
	payload := unwrapPayload(raw)
	return s.Promote(ctx, userID, payload)
}

// unwrapPayload extracts {"payload":{...}} from a WS frame; returns raw if not wrapped.
func unwrapPayload(raw []byte) []byte {
	var frame struct {
		Payload json.RawMessage `json:"payload"`
	}
	if err := json.Unmarshal(raw, &frame); err == nil && frame.Payload != nil {
		return frame.Payload
	}
	return raw
}
