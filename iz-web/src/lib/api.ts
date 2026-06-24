import { getToken } from '@/store/auth';

const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? 'https://api.no-iz.app';

class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
    this.name = 'ApiError';
  }
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getToken();
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string>),
  };
  
  if (typeof window !== 'undefined') {
    const lang = localStorage.getItem('iz_language') || navigator.language.slice(0, 2).toLowerCase();
    headers['Accept-Language'] = lang;
  }

  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(`${BASE_URL}${path}`, { ...options, headers });

  if (!res.ok) {
    let message = `HTTP ${res.status}`;
    try {
      const body = await res.json();
      message = body.error ?? message;
    } catch {}
    throw new ApiError(res.status, message);
  }

  const text = await res.text();
  return (text ? JSON.parse(text) : undefined) as T;
}

// ─── Auth ─────────────────────────────────────────────────────────────────────

export const api = {
  auth: {
    login: (username: string, password: string) =>
      request<{ access_token: string; user_id: string; username: string; display_name: string; avatar_url: string; is_admin: boolean }>(
        '/api/auth/login', { method: 'POST', body: JSON.stringify({ email_or_username: username, password }) }
      ),

    register: (username: string, email: string, password: string, display_name: string, invite_code: string, keys: Record<string, unknown>) =>
      request<{ access_token: string; user_id: string; username: string; display_name: string; avatar_url: string; is_admin: boolean }>(
        '/api/auth/register', { 
          method: 'POST', 
          body: JSON.stringify({ 
            username, 
            email,
            password, 
            display_name, 
            invite_code,
            ...keys
          }) 
        }
      ),

    me: () => request<{ user_id: string }>('/api/auth/me'),

    getUserBundle: (userID: string) =>
      request<{
        user_id: string;
        identity_key: string;
        signed_prekey: string;
        signed_prekey_sig: string;
        one_time_prekey?: { key_id: number; public_key: string };
      }>(`/api/users/${userID}/bundle`),

    searchUsers: (q: string) =>
      request<{ users: { id: string; username: string; display_name: string; avatar_url: string }[] }>(
        `/api/users/search?q=${encodeURIComponent(q)}`
      ),
  },

  // ─── Messages ───────────────────────────────────────────────────────────────
  messages: {
    conversations: () => request<{ conversations: import('@/types').Conversation[] }>('/api/conversations'),
    history: (withUser: string, before?: string) => {
      const q = new URLSearchParams({ with: withUser });
      if (before) q.set('before', before);
      return request<{ messages: import('@/types').Message[] }>(`/api/messages?${q}`);
    },
    pin: (msgID: string) => request<void>(`/api/messages/${msgID}/pin`, { method: 'POST' }),
    unpin: (msgID: string) => request<void>(`/api/messages/${msgID}/unpin`, { method: 'POST' }),
  },

  // ─── Groups ─────────────────────────────────────────────────────────────────
  groups: {
    list: () => request<{ groups: import('@/types').Group[] }>('/api/groups'),
    get: (id: string) => request<import('@/types').Group>(`/api/groups/${id}`),
    create: (name: string, description: string, isPrivate: boolean) =>
      request<import('@/types').Group>('/api/groups', { method: 'POST', body: JSON.stringify({ name, description, is_private: isPrivate }) }),
    join: (token: string) => request<import('@/types').Group>(`/api/groups/join/${token}`, { method: 'POST' }),
    leave: (id: string) => request<void>(`/api/groups/${id}/leave`, { method: 'DELETE' }),
    members: (id: string) => request<{ members: import('@/types').User[] }>(`/api/groups/${id}/members`),
    history: (id: string, before?: string) => {
      const q = new URLSearchParams();
      if (before) q.set('before', before);
      return request<{ messages: import('@/types').GroupMessage[] }>(`/api/groups/${id}/messages?${q}`);
    },
  },

  // ─── Communities ────────────────────────────────────────────────────────────
  communities: {
    discover: (limit = 30, offset = 0) =>
      request<{ communities: import('@/types').Community[] }>(`/api/communities/discover?limit=${limit}&offset=${offset}`),
    mine: () => request<{ communities: import('@/types').Community[] }>('/api/communities/me'),
    get: (slug: string) => request<import('@/types').Community>(`/api/communities/${slug}`),
    create: (name: string, slug: string, description: string, isPublic: boolean) =>
      request<import('@/types').Community>('/api/communities', { method: 'POST', body: JSON.stringify({ name, slug, description, is_public: isPublic }) }),
    join: (id: string) => request<import('@/types').Community>(`/api/communities/${id}/join`, { method: 'POST' }),
    joinByInvite: (token: string) => request<import('@/types').Community>(`/api/communities/join/${token}`, { method: 'POST' }),
    leave: (id: string) => request<void>(`/api/communities/${id}/leave`, { method: 'DELETE' }),
    posts: (communityID: string, before?: string) => {
      const q = new URLSearchParams({ limit: '30' });
      if (before) q.set('before', before);
      return request<{ posts: import('@/types').Post[] }>(`/api/communities/${communityID}/posts?${q}`);
    },
    createPost: (communityID: string, title: string, body: string, mediaURLs: string[] = []) =>
      request<import('@/types').Post>(`/api/communities/${communityID}/posts`, {
        method: 'POST', body: JSON.stringify({ title, body, media_urls: mediaURLs })
      }),
    likePost: (communityID: string, postID: string) =>
      request<void>(`/api/communities/${communityID}/posts/${postID}/like`, { method: 'POST' }),
    unlikePost: (communityID: string, postID: string) =>
      request<void>(`/api/communities/${communityID}/posts/${postID}/like`, { method: 'DELETE' }),
  },

  // ─── Calls ──────────────────────────────────────────────────────────────────
  calls: {
    history: () => request<{ calls: import('@/types').Call[] }>('/api/calls'),
    turnConfig: () => request<{ ice_servers: RTCIceServer[] }>('/api/calls/turn'),
  },

  // ─── Stories ────────────────────────────────────────────────────────────────
  stories: {
    feed: () => request<import('@/types').FriendStoryFeed[]>('/api/stories'),
    view: (storyID: string) => request<void>(`/api/stories/${storyID}/view`, { method: 'POST' }),
  },

  // ─── Backup ─────────────────────────────────────────────────────────────────
  backup: {
    get: () => request<{ encrypted_blob: string; salt: string; created_at: string } | null>('/api/backup').catch(err => {
      if (err instanceof ApiError && err.status === 404) return null;
      throw err;
    }),
    save: (encryptedBlob: string, salt: string) => request<void>('/api/backup', {
      method: 'POST',
      body: JSON.stringify({ encrypted_blob: encryptedBlob, salt })
    }),
  },
};

export { ApiError };
