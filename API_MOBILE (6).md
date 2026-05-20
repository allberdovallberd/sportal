# Sport Portal — Mobile API Reference

This document is the mobile-client contract for the current backend implementation.
It covers:

- public APIs
- authenticated user APIs
- mobile camera publishing APIs
- real-time SSE events
- admin APIs that a mobile admin client may need

It does not document internal-only infrastructure callbacks such as the SRS webhook.

---

## 1. Base URLs

### API base

All backend routes are served under:

```text
https://<host>/sport/api/v1
```

Example:

```text
https://asyllypent.com.tm/sport/api/v1
```

### Public media paths

The API may return public paths under `/sport/...`.
Mobile clients should prepend the same host they use for the API base.

Examples:

```text
API:      https://<host>/sport/api/v1/...
Uploads:  https://<host>/sport/uploads/<file>
HLS:      https://<host>/sport/live/<stream_id>.m3u8
FLV:      https://<host>/sport/live/<stream_id>.flv
WHEP:     https://<host>/sport/rtc/v1/whep/?app=live&stream=<stream_id>
WHIP:     https://<host>/sport/rtc/v1/whip/?app=live&stream=<stream_id>&secret=<secret>
SSE:      https://<host>/sport/api/v1/streams/subscribe?streamId=<stream_id>
```

### Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| `8000` | HTTP/HTTPS | API, admin SPA, uploads, HLS/FLV via nginx |
| `1935` | TCP | RTMP publish for OBS / ffmpeg |
| `8000/udp` | UDP | WebRTC media |

---

## 2. Common Rules

### Response envelope

Every endpoint returns the same top-level envelope:

```json
{
  "success": true,
  "message": "...",
  "data": {}
}
```

Paginated endpoints also return:

```json
{
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 100,
    "total_pages": 5
  }
}
```

Validation failures may return structured error details inside `data`.

### Auth header

Use:

```http
Authorization: Bearer <access_token>
```

### Mobile header

For requests made by the mobile app, send:

```http
X-Client-Platform: mobile
```

Why it matters:

- the backend uses it to enforce mobile restrictions for OBS stream management
- camera/WebRTC stream creation is allowed from mobile
- OBS stream creation/deletion is blocked from mobile

### Pagination defaults

- `page`: default `1`
- `per_page`: default `20`, max `100`
- `order`: default `desc`

### Relative media URLs

Fields such as `avatar`, `thumbnail`, `logo`, `uploads`, `hls`, `flv`, `webrtc`, `master_hls`, `qualities[].url` may be returned as public paths under `/sport/...`.

Always resolve them against the current API host.

### Roles

`role` values:

- `user`
- `admin`

### Stream status

`status` values:

- `created`
- `live`
- `ended`

### Sport values

Allowed `sport` values:

- `football`
- `volleyball`
- `basketball`
- `tennis`
- `boxing`
- `mma`
- `hockey`
- `handball`
- `rugby`
- `cricket`
- `badminton`
- `table_tennis`
- `swimming`
- `athletics`
- `gymnastics`
- `wrestling`
- `judo`
- `taekwondo`
- `karate`
- `fencing`
- `weightlifting`
- `cycling`
- `shooting`
- `archery`
- `esports`
- `other`

### viewers_count semantics

`viewers_count` is:

- real-time
- not persisted in the database
- derived from active SSE viewers
- counted as `1 viewer = 1 IP`, not raw SSE connection count

Important consequence:

- a viewer only contributes to `viewers_count` while the mobile client keeps the SSE subscription open
- multiple tabs/screens/connections from the same IP are counted as one viewer

---

## 3. Authentication

### 3.1 Register

`POST /auth/register`

Request:

```json
{
  "username": "john_doe",
  "email": "user@example.com",
  "password": "strong-password",
  "firebase_token": "optional"
}
```

Rules:

- `username`: required, 3..100 chars
- `email`: required, valid email, max 255 chars
- `password`: required, 8..128 chars
- `firebase_token`: optional

Behavior:

- with `firebase_token`: registration is completed immediately
- without `firebase_token`: the backend sends an email verification code

Success `201 Created`:

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

Common errors:

- `400 Bad Request` validation failed / invalid Firebase token / auth not configured
- `409 Conflict` duplicate username or email

### 3.2 Verify email

`POST /auth/verify`

Request:

```json
{
  "email": "user@example.com",
  "code": "123456"
}
```

Success `200 OK`:

```json
{
  "success": true,
  "message": "Email verified successfully",
  "data": null
}
```

### 3.3 Login

`POST /auth/login`

Request:

```json
{
  "email": "user@example.com",
  "password": "strong-password"
}
```

Success `200 OK`:

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
      "created_at": "...",
      "updated_at": "..."
    }
  }
}
```

Notes:

- the JWT embeds `user_id`, `role`, and `username`
- these claims are used by SSE and stream comments

### 3.4 Refresh token

`POST /auth/refresh`

Request:

```json
{
  "refresh_token": "eyJ..."
}
```

Success `200 OK`:

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

### 3.5 Resend verification code

`POST /auth/resend-code`

Request:

```json
{
  "email": "user@example.com"
}
```

Success `200 OK`.

### 3.6 Forgot password

`POST /auth/forgot-password`

Request:

```json
{
  "email": "user@example.com"
}
```

Success `200 OK` with message:

`If the email exists, a reset code has been sent`

### 3.7 Reset password

`POST /auth/reset-password`

Request:

```json
{
  "email": "user@example.com",
  "code": "123456",
  "new_password": "new-strong-password"
}
```

Success `200 OK` with message:

`Password reset successfully`

---

## 4. Profile And Uploads

### 4.1 Get my profile

`GET /users/me`

Auth required.

Success `200 OK`:

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
    "created_at": "...",
    "updated_at": "..."
  }
}
```

### 4.2 Update my profile

`PUT /users/me`

Auth required.

Request fields are optional:

```json
{
  "username": "new_username",
  "phone": "+1234567890",
  "avatar": "/sport/uploads/avatars/uuid.jpg"
}
```

Notes:

- `email` cannot be changed here
- `avatar` should usually be taken from an upload response

### 4.3 Upload a file (authenticated user)

`POST /upload`

Auth required.

Content type:

```text
multipart/form-data
```

Form fields:

- `file` required

Allowed extensions:

- `.jpg`
- `.jpeg`
- `.png`
- `.gif`
- `.webp`

Success `201 Created`:

```json
{
  "success": true,
  "message": "File uploaded",
  "data": {
    "url": "/sport/uploads/<generated_filename>.jpg"
  }
}
```

### 4.4 Upload my avatar

`POST /users/me/avatar`

Auth required.

Same multipart contract and same response shape as `POST /upload`.

Typical flow:

1. call `POST /users/me/avatar`
2. get `data.url`
3. send it as `avatar` to `PUT /users/me`

---

## 5. Public Content APIs

### 5.1 Categories

`GET /categories`

Success `200 OK`:

```json
{
  "success": true,
  "message": "Categories list",
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

### 5.2 News list

`GET /news`

Query params:

- `page`
- `per_page`
- `search`
- `category_id`
- `sort`
- `order` (`asc` or `desc`)

Success `200 OK` returns paginated `NewsResponse[]`.

Key fields in a news item:

- `id`
- `title`
- `content`
- `thumbnail`
- `category_id`
- `author_id`
- `likes_count`
- `shares_count`
- `published_at`
- `created_at`
- `updated_at`
- `category`
- `author`
- `is_liked`

`is_liked` is meaningful only when the request is authenticated.

### 5.3 News by ID

`GET /news/:id`

Returns one `NewsResponse`.

### 5.4 Federations list

`GET /federations`

Query params:

- `page`
- `per_page`
- `search`

Success `200 OK` returns paginated `FederationResponse[]`.

### 5.5 Federation by ID

`GET /federations/:id`

Returns one federation object.

---

## 6. News Interaction APIs

### 6.1 Like / unlike news

`POST /news/:id/like`

Auth required.

Success `200 OK`:

```json
{
  "success": true,
  "message": "News liked",
  "data": {
    "liked": true
  }
}
```

The same endpoint toggles the like off on the next call.

### 6.2 Track share

`POST /news/:id/share`

Auth required.

Request:

```json
{
  "platform": "telegram"
}
```

Success `200 OK` with message `Share tracked`.

---

## 7. Stream Discovery And Watching

These APIs work for both camera/WebRTC streams and OBS/RTMP streams.

### 7.1 List all streams

`GET /streams`

Success `200 OK` returns `StreamSession[]`.

Key fields:

- `id`
- `streamer_id`
- `title`
- `sport`
- `is_obs`
- `status`
- `started_at`
- `ended_at`
- `likes_count`
- `comments_count`
- `viewers_count`
- `created_at`
- `updated_at`
- optional `streamer`

### 7.2 List active streams

`GET /streams/live`

Returns only streams with statuses relevant for active discovery.

Note:

- OBS streams may appear as `created` before the encoder connects
- mobile clients should treat `created` as “scheduled / waiting for publisher”

### 7.3 Get stream by ID

`GET /streams/:id`

Returns one stream session.

### 7.4 Get playback URLs

`GET /streams/:id/watch`

Success `200 OK`:

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
      "hls": "/sport/live/<uuid>.m3u8",
      "master_hls": "/sport/api/v1/streams/<uuid>/master.m3u8",
      "flv": "/sport/live/<uuid>.flv",
      "webrtc": "/sport/rtc/v1/whep/?app=live&stream=<uuid>",
      "ice_servers": [
        {
          "urls": ["stun:stun.l.google.com:19302"]
        },
        {
          "urls": [
            "turn:<host>:3478?transport=udp",
            "turn:<host>:3478?transport=tcp"
          ],
          "username": "sportportal",
          "credential": "change-me"
        }
      ],
      "qualities": [
        {
          "name": "144p",
          "label": "144p",
          "width": 256,
          "height": 144,
          "bandwidth": 220000,
          "url": "/sport/transcoded/<uuid>_144p.m3u8"
        }
      ]
    }
  }
}
```

Playback strategy recommendation:

1. try `playback.webrtc` first for low latency
2. if WebRTC negotiation or connectivity fails, fall back to `master_hls`
3. if `master_hls` is missing, fall back to `hls`

Platform recommendation:

- iOS: prefer `master_hls` / `hls` unless the app already supports WHEP
- Android: use `master_hls` with Media3/ExoPlayer or use WebRTC first if supported

### 7.5 Dynamic master playlist

`GET /streams/:id/master.m3u8`

Public HLS master playlist endpoint.

Use it when the client wants adaptive HLS directly.

Response content type:

```text
application/vnd.apple.mpegurl
```

### 7.6 Playback grant

`POST /streams/playback`

Auth required.

Request:

```json
{
  "stream_id": "uuid"
}
```

Success `200 OK` returns:

- `stream_id`
- `viewer_id`
- `expires_at`
- `webrtc_url`
- `playback` object identical in shape to `GET /streams/:id/watch`

---

## 8. Stream Likes And Comments

### 8.1 Toggle like

`POST /streams/like`

Auth required.

Request:

```json
{
  "stream_id": "uuid"
}
```

Success `200 OK`:

```json
{
  "success": true,
  "message": "Like toggled",
  "data": {
    "stream_id": "uuid",
    "likes": 151,
    "liked": true
  }
}
```

### 8.2 Increment like count

`POST /streams/like-inc`

Auth required.

Use this for rapid tap aggregation.

Request:

```json
{
  "stream_id": "uuid",
  "delta": 5
}
```

Success `200 OK`:

```json
{
  "success": true,
  "message": "Likes incremented",
  "data": {
    "stream_id": "uuid",
    "likes": 160
  }
}
```

### 8.3 Get likes

`POST /streams/likes`

Auth required.

Request:

```json
{
  "stream_id": "uuid"
}
```

Success `200 OK` returns:

- `stream_id`
- `likes`
- `liked`

### 8.4 Post comment

`POST /streams/comment`

Auth required.

Request:

```json
{
  "stream_id": "uuid",
  "text": "Great match!"
}
```

Success `201 Created` returns the created comment object.

### 8.5 Get comments

`POST /streams/comments`

Auth required.

Request:

```json
{
  "stream_id": "uuid"
}
```

Success `200 OK`:

```json
{
  "success": true,
  "message": "Comments retrieved",
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

## 9. Real-Time Stream Events (SSE)

### 9.1 Subscribe

`GET /streams/subscribe?streamId=<uuid>`

or:

`GET /streams/subscribe?streamId=<uuid>&token=<access_token>`

This opens a Server-Sent Events connection.

Event format:

```text
event: <event_name>
data: <json>
```

Authentication options:

- `Authorization: Bearer <token>` header
- `?token=<access_token>` query parameter

The query param is recommended for platforms where `EventSource` cannot set custom headers.

### 9.2 Why mobile should use SSE

Use SSE for:

- `viewers_count` updates
- live comments / likes updates
- stream status changes
- admin moderation events (`mute`, `kick`)

Also note:

- `viewers_count` includes only active SSE viewers
- if the viewer screen closes, close SSE as well

### 9.3 Actual event names and payloads

The current backend emits these event names:

| Event | When sent | `data` shape |
|------|-----------|--------------|
| `init` | Immediately after subscribe | `{ "stream_id": "...", "likes": 152, "comments": [...], "viewers_count": 18 }` |
| `status` | Stream status changed | `{ "stream_id": "...", "status": "created" | "live" | "ended" }` |
| `likes` | Like count changed | `{ "stream_id": "...", "likes": 152 }` |
| `viewer_count` | Live viewer count changed | `{ "stream_id": "...", "viewers_count": 18 }` |
| `comment` | New comment created | full comment object |
| `mute` | Admin muted this viewer | `{ "viewer_id": "..." }` |
| `kick` | Admin removed this viewer | `{ "viewer_id": "..." }` |

Important:

- the event name is `status`, not `stream_live` / `stream_ended`
- the event name is `likes`, not `like`
- the event name is `kick`, not `kicked`

### 9.4 Client behavior for moderation events

On `mute`:

- disable chat input and/or local interaction UI as needed by the app

On `kick`:

- close the viewer experience immediately
- the SSE connection will be terminated
- reconnect attempts are blocked for 24 hours

Because viewers are deduplicated by IP, moderation also effectively applies per viewer IP identity.

---

## 10. Mobile Camera Publishing (WebRTC / WHIP)

This is the only supported mobile publishing flow.

### 10.1 Restrictions

- stream creation is admin-only
- mobile can create camera streams
- mobile cannot create OBS streams

### 10.2 Create mobile camera stream session

`POST /admin/streams`

Headers:

- `Authorization: Bearer <access_token>`
- `X-Client-Platform: mobile`

Request:

```json
{
  "title": "Arsenal vs Liverpool",
  "sport": "football",
  "is_obs": false
}
```

Success `201 Created`:

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
      "status": "live"
    },
    "publish": {
      "whip_url": "/sport/rtc/v1/whip/?app=live&stream=<uuid>&secret=<token>",
      "secret": "<token>",
      "stream_id": "<uuid>",
      "ice_servers": [
        {
          "urls": ["stun:stun.l.google.com:19302"]
        }
      ]
    }
  }
}
```

Notes:

- the full `publish` object may contain more fields; mobile camera publishing uses `whip_url`, `secret`, `stream_id`, and `ice_servers`
- non-OBS streams become `live` immediately after creation

### 10.3 Publish via WHIP

Send the SDP offer directly to SRS.

Do not prepend `/api/v1`.

Request:

```text
POST /sport/rtc/v1/whip/?app=live&stream=<uuid>&secret=<token>
Content-Type: application/sdp

<SDP offer body>
```

Response:

- `200 OK`
- body is the SDP answer

Client requirements:

- create `RTCPeerConnection` with `publish.ice_servers`
- add local tracks as `sendonly`
- use HTTPS for camera access in production

### 10.4 Stop publishing

Close the `RTCPeerConnection`.

Backend behavior:

- SRS triggers `on_unpublish`
- backend moves the stream to `created` for a reconnect grace period
- reconnecting within the grace period reuses the same session

---

## 11. OBS / RTMP Note For Mobile Developers

OBS streams are part of the same stream catalog and can be watched from mobile like any other stream.

But mobile clients must not manage them:

- `POST /admin/streams` with `is_obs: true` and header `X-Client-Platform: mobile` returns `403 Forbidden`
- `DELETE /admin/streams/:id` for an OBS stream from mobile also returns `403 Forbidden`

This means:

- mobile can watch OBS streams
- mobile can list OBS streams
- mobile admin can still create camera streams
- OBS creation/deletion belongs to web/desktop admin flows

---

## 12. Admin APIs For Mobile Admin Clients

These endpoints require:

- admin JWT
- usually `X-Client-Platform: mobile`

### 12.1 Users

#### List users

`GET /admin/users`

Query params:

- `page`
- `per_page`
- `search`

Returns paginated `UserResponse[]`.

#### Get user by ID

`GET /admin/users/:id`

Returns one `UserResponse`.

#### Update user role

`PUT /admin/users/:id/role`

Request:

```json
{
  "role": "admin"
}
```

Allowed values:

- `user`
- `admin`

#### Delete user

`DELETE /admin/users/:id`

#### Delete all non-admin users

`DELETE /admin/users`

Returns:

```json
{
  "success": true,
  "message": "Deleted 42 non-admin users",
  "data": {
    "deleted": 42
  }
}
```

### 12.2 Categories

#### Create category

`POST /admin/categories`

```json
{
  "name": "Football"
}
```

#### Update category

`PUT /admin/categories/:id`

```json
{
  "name": "Football"
}
```

#### Delete category

`DELETE /admin/categories/:id`

### 12.3 News

#### Create news

`POST /admin/news`

```json
{
  "title": "Match preview",
  "content": "Article body",
  "thumbnail": "/sport/uploads/image.jpg",
  "category_id": "uuid",
  "published_at": "2025-01-01T12:00:00Z"
}
```

`published_at` is optional and must be RFC3339 when present.

#### Update news

`PUT /admin/news/:id`

All fields are optional.

#### Delete news

`DELETE /admin/news/:id`

### 12.4 Federations

#### Create federation

`POST /admin/federations`

```json
{
  "name": "Football Federation",
  "description": "...",
  "contacts": "...",
  "logo": "/sport/uploads/logo.png",
  "thumbnail": "/sport/uploads/thumb.jpg",
  "president": "John Smith",
  "address": "1 Sports Street"
}
```

#### Update federation

`PUT /admin/federations/:id`

All fields are optional.

#### Delete federation

`DELETE /admin/federations/:id`

### 12.5 Upload (admin)

`POST /admin/upload`

Multipart form-data, same contract as `POST /upload`.

### 12.6 Stream sessions

#### Create stream session

`POST /admin/streams`

Request:

```json
{
  "title": "My stream",
  "sport": "football",
  "is_obs": false
}
```

Notes:

- `is_obs: false` or omitted is allowed from mobile admin
- `is_obs: true` is blocked from mobile

#### Delete one stream session

`DELETE /admin/streams/:id`

Notes:

- camera streams can be deleted from mobile admin
- OBS streams are blocked from mobile admin when `X-Client-Platform: mobile` is present

#### Delete all stream sessions

`DELETE /admin/streams`

### 12.7 Live attendees

#### List attendees

`GET /admin/streams/:id/attendees`

Returns unique live viewers currently connected via SSE.

Because viewer identity is deduplicated by IP, this list represents unique viewer IP identities rather than raw connection count.

Response:

```json
{
  "success": true,
  "message": "Attendees retrieved",
  "data": {
    "stream_id": "uuid",
    "count": 2,
    "items": [
      {
        "viewer_id": "uuid-or-anon_id",
        "viewer_name": "john_doe",
        "joined_at": "2025-01-01T12:01:00Z"
      }
    ]
  }
}
```

#### Mute attendee

`POST /admin/streams/:id/attendees/:viewerId/mute`

Success `200 OK` with message `Viewer muted`.

Effect:

- sends SSE event `mute`
- because viewer identity is IP-based, all active connections for the same viewer IP are affected

#### Kick attendee

`DELETE /admin/streams/:id/attendees/:viewerId/kick`

Success `200 OK` with message `Viewer kicked`.

Effect:

- sends SSE event `kick`
- closes active SSE connection(s)
- blocks reconnect for 24 hours
- because viewer identity is IP-based, the kick applies to the same viewer IP identity

---

## 13. Rate Limiting

The backend rate-limits stream interactions.

Important examples:

- likes / like-inc are limited per user and per IP
- comments are limited per user and per IP

When a limit is exceeded, the server returns `429 Too Many Requests`:

```json
{
  "success": false,
  "message": "Too many like actions (IP per minute)"
}
```

---

## 14. Endpoint Checklist

### Public

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/auth/register` | Register |
| `POST` | `/auth/verify` | Verify email |
| `POST` | `/auth/login` | Login |
| `POST` | `/auth/refresh` | Refresh tokens |
| `POST` | `/auth/resend-code` | Resend verification code |
| `POST` | `/auth/forgot-password` | Request password reset code |
| `POST` | `/auth/reset-password` | Reset password |
| `GET` | `/categories` | List categories |
| `GET` | `/news` | List news |
| `GET` | `/news/:id` | News details |
| `GET` | `/federations` | List federations |
| `GET` | `/federations/:id` | Federation details |
| `GET` | `/streams` | List all streams |
| `GET` | `/streams/live` | List active streams |
| `GET` | `/streams/:id` | Stream details |
| `GET` | `/streams/:id/master.m3u8` | Dynamic HLS master playlist |
| `GET` | `/streams/:id/watch` | Playback URLs |
| `GET` | `/streams/subscribe` | SSE stream events |

### Authenticated user

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/users/me` | Get my profile |
| `PUT` | `/users/me` | Update my profile |
| `POST` | `/upload` | Upload a file |
| `POST` | `/users/me/avatar` | Upload avatar |
| `POST` | `/news/:id/like` | Toggle news like |
| `POST` | `/news/:id/share` | Track share |
| `POST` | `/streams/like` | Toggle stream like |
| `POST` | `/streams/like-inc` | Increment stream likes |
| `POST` | `/streams/likes` | Get stream likes |
| `POST` | `/streams/comment` | Post comment |
| `POST` | `/streams/comments` | Get comments |
| `POST` | `/streams/playback` | Playback grant |

### Admin

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/admin/users` | List users |
| `GET` | `/admin/users/:id` | User details |
| `PUT` | `/admin/users/:id/role` | Update role |
| `DELETE` | `/admin/users/:id` | Delete user |
| `DELETE` | `/admin/users` | Delete all non-admin users |
| `POST` | `/admin/categories` | Create category |
| `PUT` | `/admin/categories/:id` | Update category |
| `DELETE` | `/admin/categories/:id` | Delete category |
| `POST` | `/admin/news` | Create news |
| `PUT` | `/admin/news/:id` | Update news |
| `DELETE` | `/admin/news/:id` | Delete news |
| `POST` | `/admin/federations` | Create federation |
| `PUT` | `/admin/federations/:id` | Update federation |
| `DELETE` | `/admin/federations/:id` | Delete federation |
| `POST` | `/admin/upload` | Upload file |
| `POST` | `/admin/streams` | Create stream session |
| `DELETE` | `/admin/streams/:id` | Delete stream session |
| `DELETE` | `/admin/streams` | Delete all stream sessions |
| `GET` | `/admin/streams/:id/attendees` | List live attendees |
| `POST` | `/admin/streams/:id/attendees/:viewerId/mute` | Mute attendee |
| `DELETE` | `/admin/streams/:id/attendees/:viewerId/kick` | Kick attendee |

---

## 15. Mobile Implementation Notes

Recommended minimum implementation for viewer apps:

1. auth flow
2. list streams
3. stream watch screen
4. SSE subscription for `viewers_count`, comments, likes, and status
5. WebRTC playback with HLS fallback
6. likes and comments

Recommended minimum implementation for mobile admin apps:

1. everything above
2. create camera/WebRTC stream session (`is_obs: false`)
3. attendee moderation via SSE + admin attendee APIs
4. uploads
5. optional content management APIs (`news`, `categories`, `federations`, `users`)

This document matches the current route map in the backend and supersedes older mobile API notes.