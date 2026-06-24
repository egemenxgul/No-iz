// API base types

export interface User {
  id: string;
  username: string;
  display_name: string;
  avatar_url: string;
  bio: string;
  created_at: string;
}

export interface AuthTokens {
  access_token: string;
  user_id: string;
  username: string;
  display_name: string;
  avatar_url: string;
  is_admin: boolean;
}

export interface Message {
  id: string;
  sender_id: string;
  recipient_id: string;
  ciphertext: string;
  msg_type: string;
  ratchet_key?: string;
  counter?: number;
  prev_counter?: number;
  delivered_at: string | null;
  read_at: string | null;
  expires_at: string | null;
  created_at: string;
  is_pinned?: boolean;
  reactions?: Record<string, string>;
  // Decrypted client-side
  plaintext?: string;
}

export interface Group {
  id: string;
  name: string;
  description: string;
  avatar_url: string;
  invite_link: string;
  is_private: boolean;
  max_members: number;
  created_by: string;
  created_at: string;
  member_count?: number;
}

export interface GroupMessage {
  id: string;
  group_id: string;
  sender_id: string;
  ciphertext: string;
  msg_type: string;
  iteration: number;
  distribution_id: string;
  expires_at: string | null;
  created_at: string;
  plaintext?: string;
}

export interface Community {
  id: string;
  name: string;
  slug: string;
  description: string;
  avatar_url: string;
  banner_url: string;
  invite_link?: string;
  is_public: boolean;
  max_members: number;
  created_by: string;
  created_at: string;
  member_count?: number;
  group_count?: number;
}

export interface Post {
  id: string;
  community_id: string;
  author_id: string;
  title: string;
  body: string;
  media_urls: string[];
  like_count: number;
  reply_count: number;
  is_pinned: boolean;
  expires_at: string | null;
  created_at: string;
  author_username?: string;
  author_display_name?: string;
  author_avatar_url?: string;
  liked_by_me?: boolean;
}

export interface Call {
  id: string;
  call_type: 'audio' | 'video';
  status: 'ringing' | 'active' | 'ended' | 'missed' | 'rejected' | 'busy';
  caller_id: string;
  callee_id?: string;
  group_id?: string;
  ringing_at: string;
  accepted_at?: string;
  ended_at?: string;
  duration_secs?: number;
}

// WebSocket envelope
export interface WSEnvelope {
  type: string;
  payload: unknown;
}

export interface Conversation {
  id: string;
  other_user_id: string;
  other_username: string;
  other_display_name: string | null;
  last_message: string | null;
  last_message_at: string | null;
  unread_count: number;
  friendship_status: string;
  initiator_id: string | null;
  is_online: boolean;
  last_seen_at: string | null;
  disappearing_duration: number;
  is_muted: boolean;
  is_archived: boolean;
  is_group: boolean;
  last_message_type: string | null;
}

export interface Story {
  id: string;
  user_id: string;
  media_url: string;
  caption: string;
  media_type: string;
  created_at: string;
  expires_at: string;
}

export interface FriendStoryFeed {
  user_id: string;
  username: string;
  display_name: string;
  avatar_url: string;
  stories: Story[];
}
