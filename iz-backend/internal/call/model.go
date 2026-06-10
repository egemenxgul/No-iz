package call

import (
	"time"

	"github.com/google/uuid"
)

// CallType distinguishes audio from video calls.
type CallType string

const (
	CallTypeAudio CallType = "audio"
	CallTypeVideo CallType = "video"
)

// CallStatus is the lifecycle state of a call.
type CallStatus string

const (
	StatusRinging  CallStatus = "ringing"
	StatusActive   CallStatus = "active"
	StatusEnded    CallStatus = "ended"
	StatusMissed   CallStatus = "missed"
	StatusRejected CallStatus = "rejected"
	StatusBusy     CallStatus = "busy"
)

// Call represents one audio/video call session.
type Call struct {
	ID           uuid.UUID  `json:"id"`
	CallType     CallType   `json:"call_type"`
	Status       CallStatus `json:"status"`
	CallerID     uuid.UUID  `json:"caller_id"`
	CalleeID     *uuid.UUID `json:"callee_id,omitempty"` // nil for group calls
	GroupID      *uuid.UUID `json:"group_id,omitempty"`
	RingingAt    time.Time  `json:"ringing_at"`
	AcceptedAt   *time.Time `json:"accepted_at,omitempty"`
	EndedAt      *time.Time `json:"ended_at,omitempty"`
	DurationSecs *int       `json:"duration_secs,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
}

// ─── WebSocket signaling events ───────────────────────────────────────────────

// All signaling messages travel over the existing /api/ws WebSocket connection.
// The server acts as a pure relay — it never inspects SDP or ICE content.

const (
	// Outgoing from caller
	EventCallOffer     = "call_offer"      // caller → server → callee
	EventCallEnd       = "call_end"        // either party → server → other
	EventICECandidate  = "ice_candidate"   // either party → server → other

	// Outgoing from callee
	EventCallAnswer    = "call_answer"     // callee → server → caller
	EventCallReject    = "call_reject"     // callee → server → caller

	// Server-pushed events
	EventIncomingCall  = "incoming_call"   // server → callee (ringing)
	EventCallAccepted  = "call_accepted"   // server → caller
	EventCallRejected  = "call_rejected"   // server → caller
	EventCallEnded     = "call_ended"      // server → both parties
	EventCallMissed    = "call_missed"     // server → caller (callee offline)
	EventCallBusy      = "call_busy"       // server → caller (callee in another call)

	// Group call
	EventGroupCallOffer    = "group_call_offer"     // member → server → other members
	EventGroupCallJoin     = "group_call_join"       // member joins group call
	EventGroupCallLeave    = "group_call_leave"      // member leaves group call
	EventGroupCallMember   = "group_call_member"     // server → all: someone joined/left

	EventCallPromote       = "call_promote"          // transition 1-1 to group
)

// CallPromotePayload is sent by a client to promote a 1-1 call to a group call.
type CallPromotePayload struct {
	CallID   string `json:"call_id"`
	TargetID string `json:"target_id"`
}

// CallPromotePush is sent by the server to the target to invite them to the group call.
type CallPromotePush struct {
	CallID string `json:"call_id"`
	FromID string `json:"from_id"`
}

// ─── Signaling Payloads ───────────────────────────────────────────────────────

// CallOfferPayload is sent by the caller to initiate a call.
type CallOfferPayload struct {
	CalleeID string   `json:"callee_id"`
	CallType CallType `json:"call_type"`
	SDP      string   `json:"sdp"`       // WebRTC SDP offer
}

// CallAnswerPayload is sent by the callee to accept.
type CallAnswerPayload struct {
	CallID string `json:"call_id"`
	SDP    string `json:"sdp"` // WebRTC SDP answer
}

// CallRejectPayload is sent by the callee to decline.
type CallRejectPayload struct {
	CallID string `json:"call_id"`
	Reason string `json:"reason,omitempty"`
}

// CallEndPayload terminates an active call.
type CallEndPayload struct {
	CallID string `json:"call_id"`
}

// ICECandidatePayload carries a single ICE candidate.
type ICECandidatePayload struct {
	CallID    string `json:"call_id"`
	TargetID  string `json:"target_id"` // recipient user ID
	Candidate string `json:"candidate"` // serialised RTCIceCandidate JSON
}

// GroupCallOfferPayload is sent when a member starts a group call.
type GroupCallOfferPayload struct {
	GroupID  string   `json:"group_id"`
	CallType CallType `json:"call_type"`
	SDP      string   `json:"sdp"`
	TargetID string   `json:"target_id"` // specific member to send offer to
}

// GroupCallJoinPayload signals intent to join a group call.
type GroupCallJoinPayload struct {
	CallID   string `json:"call_id"`
	GroupID  string `json:"group_id"`
}

// GroupCallLeavePayload signals leaving a group call.
type GroupCallLeavePayload struct {
	CallID string `json:"call_id"`
}

// ─── Server-pushed envelopes ─────────────────────────────────────────────────

// IncomingCallPush is sent to the callee when they receive a call.
type IncomingCallPush struct {
	CallID   string   `json:"call_id"`
	CallerID string   `json:"caller_id"`
	CallType CallType `json:"call_type"`
	SDP      string   `json:"sdp"`
}

// CallAcceptedPush is sent to the caller when callee answers.
type CallAcceptedPush struct {
	CallID   string `json:"call_id"`
	CalleeID string `json:"callee_id"`
	SDP      string `json:"sdp"`
}

// CallRejectedPush is sent to the caller when callee declines.
type CallRejectedPush struct {
	CallID   string `json:"call_id"`
	CalleeID string `json:"callee_id"`
	Reason   string `json:"reason,omitempty"`
}

// CallEndedPush is sent to both parties when a call ends.
type CallEndedPush struct {
	CallID       string `json:"call_id"`
	EndedBy      string `json:"ended_by"`
	DurationSecs int    `json:"duration_secs,omitempty"`
}

// GroupCallMemberPush notifies group members of a peer joining or leaving.
type GroupCallMemberPush struct {
	CallID string `json:"call_id"`
	UserID string `json:"user_id"`
	Action string `json:"action"` // "joined" | "left"
}

// ICECandidatePush relays an ICE candidate to the target peer.
type ICECandidatePush struct {
	CallID    string `json:"call_id"`
	FromID    string `json:"from_id"`
	Candidate string `json:"candidate"`
}
