
# Sport Portal — Mobile API Reference

**Base URL:** `http://<server>:8000/sport/api/v1`

> All API requests go through nginx on **port 8000** under the `/sport/` path prefix.  
> The server uses a **self-signed TLS certificate** if HTTPS is enabled. In development disable SSL verification.

---

## Connection

| Port | Protocol | Purpose |
|------|----------|---------|
| **8000** | HTTP/HTTPS | API, static files, HLS/FLV streams (via nginx `/sport/`) |
| **1935** | TCP | RTMP (OBS Studio / ffmpeg publish) |
| **8000/udp** | UDP | WebRTC media (WHIP publish & watch) |

**URL examples:**
```

API:      https://asyllypent.com.tm/sport/api/v1/...
HLS:      https://asyllypent.com.tm/sport/live/<uuid>.m3u8
FLV:      https://asyllypent.com.tm/sport/live/<uuid>.flv
Images:   https://asyllypent.com.tm/sport/uploads/<filename>
SSE:      https://asyllypent.com.tm/sport/api/v1/streams/subscribe?streamId=<uuid>

```

> Playback URLs returned by the API are canonical public paths under `/sport` (for example `/sport/live/...` and `/sport/rtc/...`). Mobile clients should prepend the same host they use for the API base URL.

---

## Response Format

Every endpoint returns the same envelope:

```json
{
  "success": true,
  "message": "...",
  "data": { ... }
}
```

Paginated list endpoints include an additional `meta` object:

```json
{
  "success": true,
  "message": "...",
  "data": [ ... ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 100,
    "total_pages": 5
  }
}
```

**Authorization header:** `Authorization: Bearer <access_token>`

---

## 1. Authentication

### 1.1 Register
```
POST /auth/register
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `email` | string | ✅ | Email (max 255) |
| `username` | string | ✅ | Unique username (min 3, max 100 chars) |
| `password` | string | ✅ | Password (min 8, max 128) |
| `firebase_token` | string | ❌ | Firebase phone-auth token — skips email verification if provided |

If `firebase_token` is supplied the account is verified immediately.  
Otherwise a 6-digit code is sent to the email address.  
If the email already exists but is **not verified**, the password and username are updated and the code is re-sent.

**Response 201:**
```json
{
  "success": true,
  "message": "Registration successful. Verification code sent to email.",
  "data": {
    "id": "uuid",
    "username": "john_doe",
    "email": "user@example.com",
    "phone": "",
    "avatar": "",
    "role": "user",
    "is_verified": false,
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-01T00:00:00Z"
  }
}
```

**Error responses:**

| Status | Condition |
|--------|-----------|
| `409 Conflict` | `username` or `email` (or phone if firebase) already taken |
| `400 Bad Request` | Validation failed, or Firebase token invalid / phone auth not configured |

> Registration does **not** return tokens. Call login after email verification.

---

### 1.2 Verify Email
```
POST /auth/verify
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `email` | string | ✅ | Email |
| `code` | string | ✅ | 6-digit verification code |

**Response 200:**
```json
{
  "success": true,
  "message": "Email verified successfully",
  "data": null
}
```

---

### 1.3 Login
```
POST /auth/login
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `email` | string | ✅ | Email |
| `password` | string | ✅ | Password |

**Response 200:**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "access_token": "eyJ...",
    "refresh_token": "eyJ...",
    "user": {
      "id": "uuid",
      "username": "john_doe",
      "email": "user@example.com",
      "phone": "",
      "avatar": "",
      "role": "user",
      "is_verified": true,
      "created_at": "2025-01-01T00:00:00Z",
      "updated_at": "2025-01-01T00:00:00Z"
    }
  }
}
```

> The JWT access token embeds `user_id`, `role`, and `username`. These are used server-side to identify the viewer in SSE sessions and comments without extra DB lookups.

---

### 1.4 Refresh Token
```
POST /auth/refresh
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `refresh_token` | string | ✅ | Refresh token |

**Response 200:**
```json
{
  "success": true,
  "message": "Token refreshed",
  "data": {
    "access_token": "eyJ...",
    "refresh_token": "eyJ..."
  }
}
```

> Returns only a new token pair — no user object.

---

### 1.5 Resend Verification Code
```
POST /auth/resend-code
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `email` | string | ✅ | Email |

---

### 1.6 Forgot Password
```
POST /auth/forgot-password
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `email` | string | ✅ | Email |

A 6-digit reset code is sent to the address (valid 15 minutes). Always returns 200 — the response does **not** reveal whether the email exists.

---

### 1.7 Reset Password
```
POST /auth/reset-password
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `email` | string | ✅ | Email |
| `code` | string | ✅ | 6-digit code from email |
| `new_password` | string | ✅ | New password (min 8, max 128) |

---

## 2. User Profile

### 2.1 My Profile *(auth required)*
```
GET /users/me
```

**Response 200:**
```json
{
  "success": true,
  "message": "User profile",
  "data": {
    "id": "uuid",
    "username": "john_doe",
    "email": "user@example.com",
    "phone": "+1234567890",
    "avatar": "/sport/uploads/avatars/uuid.jpg",
    "role": "user",
    "is_verified": true,
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-01T00:00:00Z"
  }
}
```

---

### 2.2 Update My Profile *(auth required)*
```
PUT /users/me
```

All fields are **optional**. Only fields provided in the body are changed.  
**Email cannot be changed** via this endpoint.

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `username` | string | ❌ | New username (min 3, max 100 chars; must be unique) |
| `phone` | string | ❌ | Phone number (max 20 chars) |
| `avatar` | string | ❌ | Avatar URL / path (max 500 chars; use `POST /users/me/avatar` to get a path) |

**Response 200:**
```json
{
  "success": true,
  "message": "Profile updated",
  "data": {
    "id": "uuid",
    "username": "new_username",
    "email": "user@example.com",
    "phone": "+1234567890",
    "avatar": "/sport/uploads/avatars/uuid.jpg",
    "role": "user",
    "is_verified": true,
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-01T12:00:00Z"
  }
}
```

**Error responses:**

| Status | Condition |
|--------|-----------|
| `400 Bad Request` | `username` already taken by another user, or validation failed |

> To upload an avatar image call `POST /users/me/avatar` (auth required) to get a URL, then pass that URL in the `avatar` field.

---

## 3. News

### 3.1 List Categories
```
GET /categories
```

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "Football",
      "slug": "football",
      "news_count": 42,
      "created_at": "2025-01-01T00:00:00Z"
    }
  ]
}
```

---

### 3.2 List News
```
GET /news
```

| Query param | Type | Default | Description |
|-------------|------|:-------:|-------------|
| `page` | int | 1 | Page number |
| `per_page` | int | 20 | Items per page (max 100) |
| `search` | string | — | Search by title |
| `category_id` | uuid | — | Filter by category |
| `sort` | string | — | Sort field |
| `order` | string | `desc` | Sort direction: `asc` / `desc` |

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "title": "Match preview",
      "content": "Article text...",
      "thumbnail": "/sport/uploads/image.jpg",
      "category_id": "uuid",
      "author_id": "uuid",
      "likes_count": 10,
      "shares_count": 3,
      "published_at": "2025-01-01T00:00:00Z",
      "created_at": "2025-01-01T00:00:00Z",
      "updated_at": "2025-01-01T00:00:00Z",
      "category": { "id": "uuid", "name": "Football", "slug": "football", "created_at": "..." },
      "author": {
        "id": "uuid",
        "username": "admin",
        "email": "admin@example.com",
        "role": "admin",
        "is_verified": true,
        "created_at": "...",
        "updated_at": "..."
      },
      "is_liked": false
    }
  ],
  "meta": { "page": 1, "per_page": 20, "total": 100, "total_pages": 5 }
}
```

> `thumbnail` is a relative path. Full URL: `http://<server>:8000/sport/uploads/image.jpg`

---

### 3.3 Get News by ID
```
GET /news/:id
```

Returns a single news object (same shape as the list item).  
When authenticated, `is_liked` reflects the current user's like status.

---

### 3.4 Like / Unlike News *(auth required)*
```
POST /news/:id/like
```

Toggles the like. A second request removes the like.

**Response 200:**
```json
{
  "success": true,
  "data": { "liked": true }
}
```

---

### 3.5 Track News Share *(auth required)*
```
POST /news/:id/share
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `platform` | string | ✅ | Platform name (max 50 chars) |

---

## 4. Federations

### 4.1 List Federations
```
GET /federations
```

| Query param | Type | Default | Description |
|-------------|------|:-------:|-------------|
| `page` | int | 1 | Page number |
| `per_page` | int | 20 | Items per page (max 100) |
| `search` | string | — | Search by name |

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "Football Federation",
      "description": "...",
      "contacts": "...",
      "logo": "/sport/uploads/logo.png",
      "thumbnail": "/sport/uploads/thumb.jpg",
      "president": "John Smith",
      "address": "1 Sports Street",
      "created_at": "2025-01-01T00:00:00Z",
      "updated_at": "2025-01-01T00:00:00Z"
    }
  ],
  "meta": { "page": 1, "per_page": 20, "total": 10, "total_pages": 1 }
}
```

---

### 4.2 Get Federation by ID
```
GET /federations/:id
```

Returns a single federation object.

---

## 5. Streams — Camera (WebRTC / WHIP)

Use this flow when the streamer publishes **directly from a mobile camera** using WebRTC.  
Do **not** set `is_obs: true` for camera streams.

### Flow overview
```
1. Create stream session  →  POST /admin/streams (is_obs: false)
2.                            → receive whip_url + secret
3.                            → session.status = "live" immediately
4. Capture camera / mic   →  getUserMedia() / AVCaptureSession
5. Build RTCPeerConnection →  add sendonly transceivers
6. Create & send SDP offer →  POST to whip_url (Content-Type: application/sdp)
7. Apply SDP answer        →  setRemoteDescription()
8. Stream is live          →  viewers watch via HLS or WebRTC (§7)
9. Stop streaming          →  close RTCPeerConnection → session auto-deleted
```

---

### 5.1 Create Camera Stream Session *(admin role required)*
```
POST /admin/streams
```

**Headers:**
- `Authorization: Bearer <access_token>`
- `X-Client-Platform: mobile` *(include this on all mobile requests — see §9)*

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `title` | string | ✅ | Stream title (max 500 chars) |
| `sport` | string | ❌ | Sport type (see §7.1 for values) |
| `is_obs` | bool | ❌ | `false` or omit for camera streams |

**Response 201:**
```json
{
  "success": true,
  "message": "Stream session created",
  "data": {
    "session": {
      "id": "uuid",
      "streamer_id": "uuid",
      "title": "Arsenal vs Liverpool",
      "sport": "football",
      "is_obs": false,
      "status": "live",
      "started_at": "2025-01-01T12:00:00Z",
      "likes_count": 0,
      "comments_count": 0,
      "created_at": "2025-01-01T12:00:00Z",
      "updated_at": "2025-01-01T12:00:00Z"
    },
    "publish": {
      "whip_url": "http://192.168.55.45:1985/rtc/v1/whip/?app=live&stream=<uuid>&secret=<token>",
      "secret": "<token>",
    "stream_id": "<uuid>",
    "ice_servers": [
      {
        "urls": ["stun:stun.l.google.com:19302"]
      },
      {
        "urls": [
          "turn:192.168.55.45:3478?transport=udp",
          "turn:192.168.55.45:3478?transport=tcp"
        ],
        "username": "sportportal",
        "credential": "change-me"
      }
    ]
    }
  }
}
```

> Non-OBS (camera) streams are set to **`live`** status immediately upon creation.  
> `publish` is returned **only once**. Store `secret` and `stream_id` securely — they cannot be retrieved again.

---

### 5.2 Publish via WHIP (WebRTC)

Send the WebRTC SDP offer directly to SRS — **no `/api/v1` prefix**:

```
POST /sport/rtc/v1/whip/?app=live&stream=<uuid>&secret=<token>
Content-Type: application/sdp

<SDP offer body>
```

SRS responds `200 OK` with the SDP answer. Apply it as the remote description to complete the handshake.

**Notes for mobile:**
- Requires HTTPS context (or localhost) for camera access
- Use `publish.ice_servers` from the API response as the `RTCPeerConnection` ICE configuration
- `ice_servers` may include both STUN and TURN entries; use the full array in order
- Add each track with `direction: "sendonly"`
- Do **not** override the `Content-Type` header
- If the WebRTC connection drops, retry with the same `stream_id` and `secret` before creating a new session

---

### 5.3 Stop Camera Stream

Close the `RTCPeerConnection`. SRS fires `on_unpublish` and the backend moves the stream back to `created` for a reconnect grace period. If the publisher reconnects in time, the same session becomes `live` again. No manual `DELETE /admin/streams/:id` call is needed for normal camera-stream stops.

---

## 6. Streams — OBS / RTMP

Use this flow when the streamer uses **OBS Studio or any RTMP encoder**.

> **Mobile restriction:** OBS streams (`is_obs: true`) **cannot be created or deleted from a mobile client**.  
> Attempting to do so with the `X-Client-Platform: mobile` header returns `403 Forbidden`.

### Flow overview
```
1. Create stream session  →  POST /admin/streams (is_obs: true) — from web/desktop only
2.                            → receive rtmp_server + obs_stream_key
3.                            → session.status = "created" (waiting for encoder)
4. Open OBS Studio        →  Settings → Stream → Custom
5. Enter Server + Key     →  see §6.2
6. Click "Start Streaming"→  RTMP connects → on_publish webhook → status = "live"
7. Viewers watch via      →  HLS or FLV (§7)
8. Click "Stop Streaming" →  RTMP disconnects → on_unpublish webhook → session auto-deleted
```

---

### 6.1 Create OBS Stream Session *(admin role required; web/desktop only)*
```
POST /admin/streams
```

**Headers:** `Authorization: Bearer <access_token>`  
*(Do NOT include `X-Client-Platform: mobile` — OBS stream creation is blocked from mobile)*

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `title` | string | ✅ | Stream title (max 500 chars) |
| `sport` | string | ❌ | Sport type (see §7.1 for values) |
| `is_obs` | bool | ✅ | Must be `true` for OBS streams |

**Response 201:**
```json
{
  "success": true,
  "message": "Stream session created",
  "data": {
    "session": {
      "id": "uuid",
      "streamer_id": "uuid",
      "title": "Arsenal vs Liverpool",
      "sport": "football",
      "is_obs": true,
      "status": "created",
      "started_at": null,
      "likes_count": 0,
      "comments_count": 0,
      "created_at": "2025-01-01T00:00:00Z",
      "updated_at": "2025-01-01T00:00:00Z"
    },
    "publish": {
      "rtmp_server": "rtmp://192.168.55.45/live",
      "obs_stream_key": "<uuid>?secret=<token>",
      "rtmp_url": "rtmp://192.168.55.45/live/<uuid>?secret=<token>",
      "secret": "<token>",
    "stream_id": "<uuid>",
    "ice_servers": [
      {
        "urls": ["stun:stun.l.google.com:19302"]
      },
      {
        "urls": [
          "turn:192.168.55.45:3478?transport=udp",
          "turn:192.168.55.45:3478?transport=tcp"
        ],
        "username": "sportportal",
        "credential": "change-me"
      }
    ]
    }
  }
}
```

> OBS streams start with status **`created`** until SRS fires `on_publish`, at which point status becomes **`live`**.  
> `publish` is returned **only once**. Store `secret` and `stream_id` securely.

---

### 6.2 Configure OBS Studio

1. Open **Settings → Stream**
2. Set **Service** to `Custom...`
3. **Server:** value of `rtmp_server` — e.g. `rtmp://192.168.55.45/live`
4. **Stream Key:** value of `obs_stream_key` — e.g. `<uuid>?secret=<token>`
5. Click **Start Streaming**

The stream appears live within a few seconds.

---

### 6.3 Stop OBS Stream

Click **Stop Streaming** in OBS. SRS fires `on_unpublish`, which moves the stream session back to `created` for a reconnect grace period. If OBS reconnects before that window expires, the same session becomes `live` again. No API call is needed for a normal stop.

---

## 7. Stream Discovery & Watching

These endpoints work for both Camera and OBS streams.

### 7.1 List All Streams
```
GET /streams
```

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "streamer_id": "uuid",
      "title": "Arsenal vs Liverpool",
      "sport": "football",
      "is_obs": false,
      "status": "live",
      "started_at": "2025-01-01T12:00:00Z",
      "ended_at": null,
      "likes_count": 150,
      "comments_count": 42,
      "viewers_count": 18,
      "created_at": "2025-01-01T00:00:00Z",
      "updated_at": "2025-01-01T12:00:00Z"
    }
  ]
}
```

`viewers_count` is computed from currently connected SSE viewers. It is real-time, not persisted in the database.

**`status` values:** `created` | `live` | `ended`

**`sport` values:** `football` | `volleyball` | `basketball` | `tennis` | `boxing` | `mma` | `hockey` | `handball` | `rugby` | `cricket` | `badminton` | `table_tennis` | `swimming` | `athletics` | `gymnastics` | `wrestling` | `judo` | `taekwondo` | `karate` | `fencing` | `weightlifting` | `cycling` | `shooting` | `archery` | `esports` | `other`

---

### 7.2 List Live Streams Only
```
GET /streams/live
```

Same response shape as §7.1, filtered to active streams (`status = created` or `live`).  
`created` is included because OBS sessions are `created` until the encoder connects.

---

### 7.3 Get Stream by ID
```
GET /streams/:id
```

Returns a single stream session object (same shape as §7.1 list item).

---

### 7.4 Get Playback URLs
```
GET /streams/:id/watch
```

**Response 200:**
```json
{
  "success": true,
  "message": "Stream playback info",
  "data": {
    "stream": {
      "id": "uuid",
      "title": "Arsenal vs Liverpool",
	  "status": "live",
	  "viewers_count": 18
    },
    "playback": {
      "hls": "http://192.168.55.45:8000/sport/live/<uuid>.m3u8",
      "master_hls": "http://192.168.55.45:8000/sport/api/v1/streams/<uuid>/master.m3u8",
      "flv": "http://192.168.55.45:8000/sport/live/<uuid>.flv",
      "webrtc": "http://192.168.55.45:8000/sport/rtc/v1/whep/?app=live&stream=<uuid>",
      "ice_servers": [
        {
          "urls": ["stun:stun.l.google.com:19302"]
        },
        {
          "urls": [
            "turn:192.168.55.45:3478?transport=udp",
            "turn:192.168.55.45:3478?transport=tcp"
          ],
          "username": "sportportal",
          "credential": "change-me"
        }
      ],
      "qualities": [
        { "name": "144p", "label": "144p", "width": 256, "height": 144, "bandwidth": 220000, "url": "http://192.168.55.45:8000/sport/live/<uuid>_144p.m3u8" },
        { "name": "240p", "label": "240p", "width": 426, "height": 240, "bandwidth": 420000, "url": "http://192.168.55.45:8000/sport/live/<uuid>_240p.m3u8" }
      ]
    }
  }
}
```

> The returned playback URLs are public `/sport/...` paths behind nginx. Use them with the same host you use for the API.
> Use `playback.ice_servers` when creating a `RTCPeerConnection` for WHEP/WebRTC playback instead of hardcoding STUN/TURN servers in the app.
> - **iOS:** use `master_hls` for adaptive HLS when available, otherwise fall back to `hls`
> - **Android:** use `master_hls` for adaptive HLS in `ExoPlayer` / `Media3`, otherwise fall back to `hls`
> - For adaptive HLS with `Auto/144p/240p/360p/720p/1080p`, use `master_hls` and expose `qualities` in the player UI.
> - Recommended playback strategy: try WebRTC first for low latency, but automatically fall back to `master_hls` or `hls` if WHEP negotiation fails or the WebRTC connection drops.

---

### 7.5 Get Playback Grant *(auth required)*
```
POST /streams/playback
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `stream_id` | string | ✅ | Stream UUID |

**Response 200:**
```json
{
  "success": true,
  "data": {
    "stream_id": "uuid",
    "viewer_id": "uuid",
    "expires_at": "2025-01-01T13:00:00Z",
    "webrtc_url": "http://...",
    "playback": {
      "hls": "http://192.168.55.45:8000/sport/live/<uuid>.m3u8",
      "master_hls": "http://192.168.55.45:8000/sport/api/v1/streams/<uuid>/master.m3u8",
      "flv": "http://192.168.55.45:8000/sport/live/<uuid>.flv",
      "webrtc": "http://192.168.55.45:8000/sport/rtc/v1/whep/?app=live&stream=<uuid>",
      "ice_servers": [
        {
          "urls": ["stun:stun.l.google.com:19302"]
        },
        {
          "urls": [
            "turn:192.168.55.45:3478?transport=udp",
            "turn:192.168.55.45:3478?transport=tcp"
          ],
          "username": "sportportal",
          "credential": "change-me"
        }
      ]
    }
  }
}
```

---

### 7.6 Real-Time Events (SSE)
```
GET /streams/subscribe?streamId=<uuid>
GET /streams/subscribe?streamId=<uuid>&token=<access_token>
```

Opens a Server-Sent Events connection. Events arrive as:
```
event: <event_name>
data: <json>
```

**Authentication (optional but recommended):**  
Pass the JWT access token either via:
- `Authorization: Bearer <token>` header, **or**
- `?token=<access_token>` query parameter (useful when headers cannot be set, e.g., `EventSource` on some platforms)

Authenticated viewers are tracked as live attendees and can be muted or kicked by admins.
The server also emits a live `viewer_count` event whenever the number of connected viewers changes.

**Events:**

| Event | Description | `data` shape |
|-------|-------------|-------------|
| `init` | Initial snapshot sent right after subscribe | `{ "stream_id": "...", "likes": 152, "comments": [...], "viewers_count": 18 }` |
| `stream_live` | Encoder connected, stream is live | `{ "stream_id": "..." }` |
| `stream_ended` | Encoder disconnected, stream ended | `{ "stream_id": "..." }` |
| `like` | Like count updated | `{ "stream_id": "...", "likes": 152 }` |
| `viewer_count` | Current online viewers count changed | `{ "stream_id": "...", "viewers_count": 18 }` |
| `comment` | New comment posted | `{ "id": "...", "author_name": "...", "text": "..." }` |
| `mute` | **You** have been muted by an admin | `{ "stream_id": "...", "viewer_id": "..." }` |
| `kicked` | **You** have been removed from this stream | `{ "stream_id": "...", "viewer_id": "..." }` |

**`mute` event:** The viewer should stop their microphone / disable chat UI. The event is advisory — the server does not forcibly stop the client.

**`kicked` event:** The SSE connection is immediately closed after this event is delivered. The viewer is **blocked from reconnecting** for 24 hours. Attempting to reconnect returns `403 Forbidden`.

---

## 8. Stream Interactions

### 8.1 Like / Unlike Stream *(auth required)*
```
POST /streams/like
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `stream_id` | string | ✅ | Stream UUID |

Toggles the like. A second request removes it.

**Response 200:**
```json
{
  "success": true,
  "data": {
    "stream_id": "uuid",
    "likes": 151,
    "liked": true
  }
}
```

---

### 8.2 Increment Like Count *(auth required)*
```
POST /streams/like-inc
```

Use this for rapid like animations — accumulate taps and send a single delta instead of one request per tap.

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `stream_id` | string | ✅ | Stream UUID |
| `delta` | int | ✅ | Number of likes to add (min 1) |

**Response 200:**
```json
{
  "success": true,
  "data": {
    "stream_id": "uuid",
    "likes": 160
  }
}
```

---

### 8.3 Get Stream Likes *(auth required)*
```
POST /streams/likes
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `stream_id` | string | ✅ | Stream UUID |

**Response 200:**
```json
{
  "success": true,
  "data": {
    "stream_id": "uuid",
    "likes": 151,
    "liked": true
  }
}
```

---

### 8.4 Post a Comment *(auth required)*
```
POST /streams/comment
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `stream_id` | string | ✅ | Stream UUID |
| `text` | string | ✅ | Comment text (min 1, max 2000 chars) |

The server resolves `author_name` from the current user profile username. If the JWT username claim is missing or stale, the backend falls back to the latest username stored in the database.

**Response 201:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "stream_id": "uuid",
    "author_id": "uuid",
    "author_name": "john_doe",
    "text": "Great match!",
    "created_at": "2025-01-01T12:05:00Z"
  }
}
```

---

### 8.5 Get Comments *(auth required)*
```
POST /streams/comments
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `stream_id` | string | ✅ | Stream UUID |

**Response 200:**
```json
{
  "success": true,
  "data": {
    "stream_id": "uuid",
    "items": [
      {
        "id": "uuid",
        "stream_id": "uuid",
        "author_id": "uuid",
        "author_name": "john_doe",
        "text": "Goal!",
        "created_at": "2025-01-01T12:05:00Z"
      }
    ]
  }
}
```

---

## 9. Admin — Attendee Management

These endpoints are **admin-only** and allow real-time management of live viewers.

> **`X-Client-Platform` header:** Include `X-Client-Platform: mobile` on all requests from mobile clients. The server uses this to enforce OBS-stream restrictions (see §6).

---

### 9.1 List Live Attendees *(admin role required)*
```
GET /admin/streams/:id/attendees
```

Returns all viewers currently connected via SSE.

**Response 200:**
```json
{
  "success": true,
  "message": "Attendees retrieved",
  "data": {
    "stream_id": "uuid",
    "count": 2,
    "items": [
      {
        "viewer_id": "uuid",
        "viewer_name": "john_doe",
        "joined_at": "2025-01-01T12:01:00Z"
      },
      {
        "viewer_id": "anon_a1b2c3d4",
        "viewer_name": "Anonymous",
        "joined_at": "2025-01-01T12:02:00Z"
      }
    ]
  }
}
```

> Unauthenticated viewers have a generated `viewer_id` (prefix `anon_`) and `viewer_name = "Anonymous"`. They can still be muted or kicked.

---

### 9.2 Mute a Viewer *(admin role required)*
```
POST /admin/streams/:id/attendees/:viewerId/mute
```

Sends a `mute` SSE event to the specified viewer. The client is expected to stop its microphone / disable chat input.

**Response 200:**
```json
{
  "success": true,
  "message": "Viewer muted"
}
```

| Status | Condition |
|--------|-----------|
| `404 Not Found` | Viewer is not currently connected to this stream |

---

### 9.3 Kick a Viewer *(admin role required)*
```
DELETE /admin/streams/:id/attendees/:viewerId/kick
```

Sends a `kicked` SSE event, closes the viewer's SSE connection, and blocks them from reconnecting for **24 hours** (enforced via Redis).

**Response 200:**
```json
{
  "success": true,
  "message": "Viewer kicked"
}
```

| Status | Condition |
|--------|-----------|
| `404 Not Found` | Viewer is not currently connected to this stream |

> After kicking, if the viewer tries to reconnect via `GET /streams/subscribe`, the server returns `403 Forbidden`.

---

## 10. Admin — User Management

All endpoints in this section require:
- `Authorization: Bearer <access_token>` of an **admin** user
- Optional `X-Client-Platform: mobile` header

### 10.1 List Users
```
GET /admin/users
```

| Query param | Type | Default | Description |
|-------------|------|:-------:|-------------|
| `page` | int | 1 | Page number |
| `per_page` | int | 20 | Items per page (max 100) |
| `search` | string | — | Search by email / username / phone |

**Response 200:**
```json
{
  "success": true,
  "message": "Users list",
  "data": [
    {
      "id": "uuid",
      "username": "john_doe",
      "email": "user@example.com",
      "phone": "+1234567890",
      "avatar": "/sport/uploads/avatars/uuid.jpg",
      "role": "user",
      "is_verified": true,
      "created_at": "2025-01-01T00:00:00Z",
      "updated_at": "2025-01-01T00:00:00Z"
    }
  ],
  "meta": { "page": 1, "per_page": 20, "total": 100, "total_pages": 5 }
}
```

---

### 10.2 Get User by ID
```
GET /admin/users/:id
```

**Response 200:** Single `UserResponse` object (same shape as §10.1 item).  
`404 Not Found` if the user does not exist.

---

### 10.3 Update User Role
```
PUT /admin/users/:id/role
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `role` | string | ✅ | `user` or `admin` |

**Response 200:**
```json
{
  "success": true,
  "message": "User role updated",
  "data": { "id": "uuid", "role": "admin", "...": "..." }
}
```

---

### 10.4 Delete a User
```
DELETE /admin/users/:id
```

**Response 200:**
```json
{ "success": true, "message": "User deleted", "data": null }
```

---

### 10.5 Delete All Non-Admin Users
```
DELETE /admin/users
```

> ⚠️ Destructive — deletes every account that does **not** have the `admin` role.

**Response 200:**
```json
{
  "success": true,
  "message": "Deleted 42 non-admin users",
  "data": { "deleted": 42 }
}
```

---

## 11. Admin — News Categories

### 11.1 Create Category
```
POST /admin/categories
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `name` | string | ✅ | Category name (max 100) |

The slug is generated automatically from the name.

**Response 201:**
```json
{
  "success": true,
  "message": "Category created",
  "data": {
    "id": "uuid",
    "name": "Football",
    "slug": "football",
    "created_at": "2025-01-01T00:00:00Z"
  }
}
```

`409 Conflict` if a category with the same name/slug already exists.

---

### 11.2 Update Category
```
PUT /admin/categories/:id
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `name` | string | ✅ | New name (max 100) |

**Response 200:** Updated `NewsCategoryResponse`.

---

### 11.3 Delete Category
```
DELETE /admin/categories/:id
```

**Response 200:**
```json
{ "success": true, "message": "Category deleted", "data": null }
```

---

## 12. Admin — News

### 12.1 Create News
```
POST /admin/news
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `title` | string | ✅ | Title (max 500) |
| `content` | string | ✅ | Article body (HTML or plain text) |
| `thumbnail` | string | ❌ | Thumbnail URL/path (max 500) |
| `category_id` | uuid | ✅ | Category UUID |
| `published_at` | string | ❌ | RFC3339 timestamp; if omitted the article is unpublished/draft |

The `author_id` is taken from the JWT token.

**Response 201:** A `NewsResponse` (same shape as §3.2).

---

### 12.2 Update News
```
PUT /admin/news/:id
```

All fields optional. Only fields included in the body are changed.

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Title (max 500) |
| `content` | string | Article body |
| `thumbnail` | string | Thumbnail URL/path (max 500) |
| `category_id` | uuid | New category UUID |
| `published_at` | string | RFC3339 timestamp |

**Response 200:** Updated `NewsResponse`.

---

### 12.3 Delete News
```
DELETE /admin/news/:id
```

**Response 200:**
```json
{ "success": true, "message": "News deleted", "data": null }
```

---

## 13. Admin — Federations

### 13.1 Create Federation
```
POST /admin/federations
```

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `name` | string | ✅ | Federation name (max 255) |
| `description` | string | ❌ | Description |
| `contacts` | string | ❌ | Contact info (phone / email / etc.) |
| `logo` | string | ❌ | Logo URL/path (max 500) |
| `thumbnail` | string | ❌ | Thumbnail URL/path (max 500) |
| `president` | string | ❌ | President name (max 255) |
| `address` | string | ❌ | Postal address |

**Response 201:** A `FederationResponse` (same shape as §4.1).

---

### 13.2 Update Federation
```
PUT /admin/federations/:id
```

All fields optional. Only fields included in the body are changed.  
Same field set as §13.1 (every field becomes optional).

**Response 200:** Updated `FederationResponse`.

---

### 13.3 Delete Federation
```
DELETE /admin/federations/:id
```

**Response 200:**
```json
{ "success": true, "message": "Federation deleted", "data": null }
```

---

## 14. Admin — File Upload

### 14.1 Upload a File
```
POST /admin/upload
Content-Type: multipart/form-data
```

**Form fields:**
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `file` | file | ✅ | Image file (jpg, jpeg, png, gif, webp). Max size from server config. |

**Response 201:**
```json
{
  "success": true,
  "message": "File uploaded",
  "data": {
    "url": "/sport/uploads/<generated_filename>.jpg"
  }
}
```

The returned `url` is a relative path. Full URL: `http://<server>:8000/sport/uploads/<file>`.  

### 14.2 Upload Your Avatar *(auth required)*
```
POST /users/me/avatar
Content-Type: multipart/form-data
```

Same multipart contract and response shape as `POST /admin/upload`, but available to any authenticated user for profile avatars.
Use the returned URL as the `avatar` value in `PUT /users/me`.

**Errors:**

| Status | Condition |
|--------|-----------|
| `400 Bad Request` | No file in request, unsupported extension, or file exceeds the configured max size |

---

## 15. Rate Limiting

The server enforces rate limits on interactive stream actions:

| Action | Limit |
|--------|-------|
| Like / like-inc | 60 per minute per user; 200 per minute per IP |
| Comment | Configured sliding window per user / IP |

Exceeding the limit returns `429 Too Many Requests`:
```json
{
  "success": false,
  "message": "Too many like actions (IP per minute)"
}
```

---

## Endpoint Summary

### Public (no token needed)
| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/auth/register` | Register (requires `username`) |
| `POST` | `/auth/verify` | Verify email |
| `POST` | `/auth/login` | Login |
| `POST` | `/auth/refresh` | Refresh tokens |
| `POST` | `/auth/resend-code` | Resend verification code |
| `POST` | `/auth/forgot-password` | Request password reset code |
| `POST` | `/auth/reset-password` | Reset password |
| `GET` | `/categories` | List news categories |
| `GET` | `/news` | List news |
| `GET` | `/news/:id` | Get news by ID |
| `GET` | `/federations` | List federations |
| `GET` | `/federations/:id` | Get federation by ID |
| `GET` | `/streams` | List all streams |
| `GET` | `/streams/live` | List live/active streams |
| `GET` | `/streams/:id` | Get stream by ID |
| `GET` | `/streams/:id/watch` | Get playback URLs (HLS / FLV / WebRTC) |
| `GET` | `/streams/subscribe` | SSE — real-time stream events |

### Authenticated (any verified user)
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/users/me` | My profile |
| `PUT` | `/users/me` | Update profile (username, phone, avatar) |
| `POST` | `/users/me/avatar` | Upload avatar image for the current user |
| `POST` | `/news/:id/like` | Like / unlike news |
| `POST` | `/news/:id/share` | Track share |
| `POST` | `/streams/like` | Like / unlike stream |
| `POST` | `/streams/like-inc` | Increment like count |
| `POST` | `/streams/likes` | Get stream likes & my like status |
| `POST` | `/streams/comment` | Post a comment |
| `POST` | `/streams/comments` | Get comments |
| `POST` | `/streams/playback` | Get playback grant |

### Admin only
| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/admin/upload` | Upload an image file (multipart) |
| `POST` | `/admin/streams` | Create stream session (camera or OBS¹) |
| `DELETE` | `/admin/streams/:id` | Delete a stream session (OBS blocked on mobile¹) |
| `DELETE` | `/admin/streams` | Delete all stream sessions |
| `GET` | `/admin/streams/:id/attendees` | List live viewers |
| `POST` | `/admin/streams/:id/attendees/:viewerId/mute` | Mute a viewer |
| `DELETE` | `/admin/streams/:id/attendees/:viewerId/kick` | Kick a viewer (24h ban) |

> ¹ OBS stream creation/deletion is blocked when the `X-Client-Platform: mobile` header is present → `403 Forbidden`.

> All paths are prefixed with `/api/v1` and served under `/sport/`.  
> Full example: `POST http://192.168.55.45:8000/sport/api/v1/auth/login`
