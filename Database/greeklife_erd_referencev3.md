# Greek Life App — ERD Reference (v3)

Build-ready field reference for the Supabase/PostgreSQL schema. Every column lists its
exact datatype, key role, nullability, default, and (for FKs) the on-delete behavior, so
this doc can be transcribed directly into a schema.

Legend — **PK** primary key · **FK** foreign key · **UK** unique · `NN` not null.
No payments. Timestamps are `timestamptz`. Geo is PostGIS `geography(Point,4326)`.

v3 changes: added `invitations` (invite-only path for alumni), added required `profiles.birthday`,
and a derived `member_birthdays` view for group calendars.

---

## Enum types

| Enum | Values |
|---|---|
| `org_type` | `fraternity`, `sorority`, `club`, `organization` |
| `account_type` | `student`, `alumni` |
| `membership_role` | `admin`, `user`, `alumni` |
| `membership_status` | `pending`, `active`, `removed` |
| `invitation_status` | `pending`, `accepted`, `declined`, `expired`, `revoked` |
| `event_visibility` | `org`, `public` |
| `rsvp_status` | `going`, `maybe`, `not_going` |
| `chat_type` | `group`, `dm`, `announcement` |
| `chat_member_role` | `member`, `admin` |
| `post_scope` | `campus`, `chapter` |

---

## schools
A campus. Anchors campus-feed scope and geo radius.

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| name | text | NN | | |
| domain | citext | UK | | Email domain, e.g. `stateu.edu`. Used to detect `.edu` signups. |
| location | geography(Point,4326) | | | Campus center. |
| radius_m | integer | NN | `8000` | Campus feed radius (meters). |
| created_at | timestamptz | NN | `now()` | |

---

## profiles
One row per user; 1:1 with `auth.users`. Created on signup. **Carries the access tier.**

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | | FK → `auth.users(id)` ON DELETE CASCADE. Same UUID as the auth user. |
| username | citext | UK | | Case-insensitive. |
| full_name | text | | | |
| birthday | date | NN | | Required at signup. Surfaced on group calendars via the `member_birthdays` view. |
| account_type | account_type | NN | `'alumni'` | `student` = full access; `alumni` = restricted. Set/upgraded by email verification. |
| edu_verified | boolean | NN | `false` | True once a `.edu` address is confirmed → promote to `student`. |
| school_email | citext | UK | | The verified `.edu` address (null for personal-email accounts). |
| avatar_url | text | | | `avatars` storage bucket. |
| phone | text | | | |
| school_id | uuid | FK | | → `schools(id)` ON DELETE SET NULL. Campus for feed visibility. |
| created_at | timestamptz | NN | `now()` | |
| updated_at | timestamptz | NN | `now()` | Trigger-maintained. |

---

## organizations
A chapter, club, or student org.

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| name | text | NN | | |
| slug | citext | UK | | URL handle. |
| type | org_type | NN | `'organization'` | |
| description | text | | | |
| avatar_url | text | | | |
| primary_color | text | | | Brand accent hex. |
| school_id | uuid | FK | | → `schools(id)` ON DELETE SET NULL. |
| created_by | uuid | FK | | → `profiles(id)` ON DELETE SET NULL. |
| created_at | timestamptz | NN | `now()` | |
| updated_at | timestamptz | NN | `now()` | |

---

## memberships
User ↔ organization link with role + status. **UNIQUE (org_id, user_id).**

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| org_id | uuid | FK, NN | | → `organizations(id)` ON DELETE CASCADE. |
| user_id | uuid | FK, NN | | → `profiles(id)` ON DELETE CASCADE. |
| role | membership_role | NN | `'user'` | `admin`, `user`, or `alumni`. See role rules below. |
| status | membership_status | NN | `'pending'` | `pending` = self-request (students/users); `active` after approval or invite-accept. |
| joined_at | timestamptz | NN | `now()` | |

---

## invitations
Invite-only path into an org. Required for alumni (who cannot self-request); also usable
for any admin-initiated invite. **UNIQUE (token).** Accepting an invite creates an `active`
`memberships` row with the invite's `role`.

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| org_id | uuid | FK, NN | | → `organizations(id)` ON DELETE CASCADE. |
| email | citext | NN | | Invitee's email (they may not have an account yet). |
| invited_user_id | uuid | FK | | → `profiles(id)` ON DELETE SET NULL. Resolved if the email matches an account. |
| role | membership_role | NN | `'user'` | Role granted on accept (`alumni` for alumni invites). |
| invited_by | uuid | FK | | → `profiles(id)` ON DELETE SET NULL. Must be an org admin. |
| status | invitation_status | NN | `'pending'` | |
| token | text | UK, NN | | Opaque accept-link token. |
| expires_at | timestamptz | | | Optional expiry. |
| created_at | timestamptz | NN | `now()` | |
| responded_at | timestamptz | | | Set on accept/decline. |

---

## events
An org event. Optional geocoordinate.

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| org_id | uuid | FK, NN | | → `organizations(id)` ON DELETE CASCADE. |
| created_by | uuid | FK | | → `profiles(id)` ON DELETE SET NULL. |
| title | text | NN | | |
| description | text | | | |
| location_text | text | | | Human-readable place. |
| location | geography(Point,4326) | | | Optional pin. |
| starts_at | timestamptz | NN | | |
| ends_at | timestamptz | | | CHECK `ends_at IS NULL OR ends_at >= starts_at`. |
| all_day | boolean | NN | `false` | |
| visibility | event_visibility | NN | `'org'` | `public` readable beyond the org. |
| created_at | timestamptz | NN | `now()` | |
| updated_at | timestamptz | NN | `now()` | |

> **View `member_birthdays`** (not a table): joins `memberships` (active) → `profiles.birthday`,
> producing one all-day, annually-recurring birthday entry per active member per org. This is
> how a member's birthday auto-appears on a group's calendar on join and auto-disappears on leave —
> no stored event rows. Suggested columns: `org_id`, `user_id`, `full_name`, `birthday`.

---

## event_rsvps
A member's RSVP. **UNIQUE (event_id, user_id).**

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| event_id | uuid | FK, NN | | → `events(id)` ON DELETE CASCADE. |
| user_id | uuid | FK, NN | | → `profiles(id)` ON DELETE CASCADE. |
| status | rsvp_status | NN | `'going'` | |
| responded_at | timestamptz | NN | `now()` | |

---

## chats
A conversation. `org_id` nullable for cross-org DMs.

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| org_id | uuid | FK | | → `organizations(id)` ON DELETE CASCADE. Null for DMs. |
| type | chat_type | NN | `'group'` | |
| name | text | | | Null for DMs. |
| created_by | uuid | FK | | → `profiles(id)` ON DELETE SET NULL. |
| created_at | timestamptz | NN | `now()` | |
| updated_at | timestamptz | NN | `now()` | |

---

## chat_members
Membership in a chat + read cursor. **UNIQUE (chat_id, user_id).**

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| chat_id | uuid | FK, NN | | → `chats(id)` ON DELETE CASCADE. |
| user_id | uuid | FK, NN | | → `profiles(id)` ON DELETE CASCADE. |
| role | chat_member_role | NN | `'member'` | |
| last_read_at | timestamptz | NN | `now()` | Compare to `messages.created_at` for unread counts. |
| joined_at | timestamptz | NN | `now()` | |

---

## messages
A single message. Soft-deleted via `deleted_at`.

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| chat_id | uuid | FK, NN | | → `chats(id)` ON DELETE CASCADE. |
| sender_id | uuid | FK | | → `profiles(id)` ON DELETE SET NULL. |
| body | text | | | |
| attachment_url | text | | | `attachments` storage bucket. |
| created_at | timestamptz | NN | `now()` | |
| edited_at | timestamptz | | | |
| deleted_at | timestamptz | | | Soft delete. |

---

## location_settings
Per-user sharing controls. **1:1 with profiles** (PK is the user).

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| user_id | uuid | PK, NN | | FK → `profiles(id)` ON DELETE CASCADE. |
| sharing_enabled | boolean | NN | `true` | Master switch. |
| ghost_mode | boolean | NN | `false` | Temporarily hide live location. |
| updated_at | timestamptz | NN | `now()` | |

---

## locations
Append-only ping history. Latest-per-user via the `latest_locations` view.

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| user_id | uuid | FK, NN | | → `profiles(id)` ON DELETE CASCADE. |
| point | geography(Point,4326) | NN | | GiST index recommended. |
| accuracy_m | real | | | |
| battery_level | smallint | | | |
| place_label | text | | | e.g. "Library". |
| captured_at | timestamptz | NN | `now()` | Device time of fix. |
| created_at | timestamptz | NN | `now()` | Server insert time. |

> **View `latest_locations`**: `DISTINCT ON (user_id) ... ORDER BY user_id, captured_at DESC`.

---

## posts
Anonymous post, scoped to a campus **or** a chapter. CHECK enforces the matching FK.

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| scope | post_scope | NN | `'campus'` | |
| school_id | uuid | FK | | → `schools(id)` ON DELETE CASCADE. Required when `scope='campus'`. |
| org_id | uuid | FK | | → `organizations(id)` ON DELETE CASCADE. Required when `scope='chapter'`. |
| author_id | uuid | FK | | → `profiles(id)` ON DELETE SET NULL. For moderation; hidden in UI. |
| is_anonymous | boolean | NN | `true` | |
| body | text | NN | | |
| point | geography(Point,4326) | | | |
| score | integer | NN | `0` | Denormalized vote sum (maintain via trigger). |
| created_at | timestamptz | NN | `now()` | |
| deleted_at | timestamptz | | | Soft delete. |

> CHECK: `(scope='campus' AND school_id IS NOT NULL) OR (scope='chapter' AND org_id IS NOT NULL)`.

---

## post_votes
One vote per user per post. **UNIQUE (post_id, user_id).**

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| post_id | uuid | FK, NN | | → `posts(id)` ON DELETE CASCADE. |
| user_id | uuid | FK, NN | | → `profiles(id)` ON DELETE CASCADE. |
| value | smallint | NN | | CHECK `value IN (-1, 1)`. |
| created_at | timestamptz | NN | `now()` | |

---

## comments
A reply on a post.

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| post_id | uuid | FK, NN | | → `posts(id)` ON DELETE CASCADE. |
| author_id | uuid | FK | | → `profiles(id)` ON DELETE SET NULL. |
| body | text | NN | | |
| score | integer | NN | `0` | Denormalized vote sum. |
| created_at | timestamptz | NN | `now()` | |
| deleted_at | timestamptz | | | Soft delete. |

---

## comment_votes
One vote per user per comment. **UNIQUE (comment_id, user_id).**

| Field | Datatype | Key / NN | Default | Notes |
|---|---|---|---|---|
| id | uuid | PK, NN | `gen_random_uuid()` | |
| comment_id | uuid | FK, NN | | → `comments(id)` ON DELETE CASCADE. |
| user_id | uuid | FK, NN | | → `profiles(id)` ON DELETE CASCADE. |
| value | smallint | NN | | CHECK `value IN (-1, 1)`. |
| created_at | timestamptz | NN | `now()` | |

---

## Relationships (quick reference)

| Parent | Child | FK column | On delete |
|---|---|---|---|
| schools | profiles | school_id | SET NULL |
| schools | organizations | school_id | SET NULL |
| schools | posts | school_id | CASCADE |
| auth.users | profiles | id | CASCADE |
| profiles | memberships | user_id | CASCADE |
| organizations | memberships | org_id | CASCADE |
| organizations | invitations | org_id | CASCADE |
| profiles | invitations | invited_user_id | SET NULL |
| profiles | invitations | invited_by | SET NULL |
| organizations | events | org_id | CASCADE |
| profiles | events | created_by | SET NULL |
| events | event_rsvps | event_id | CASCADE |
| profiles | event_rsvps | user_id | CASCADE |
| organizations | chats | org_id | CASCADE |
| chats | chat_members | chat_id | CASCADE |
| profiles | chat_members | user_id | CASCADE |
| chats | messages | chat_id | CASCADE |
| profiles | messages | sender_id | SET NULL |
| profiles | location_settings | user_id | CASCADE |
| profiles | locations | user_id | CASCADE |
| organizations | posts | org_id | CASCADE |
| profiles | posts | author_id | SET NULL |
| posts | post_votes | post_id | CASCADE |
| profiles | post_votes | user_id | CASCADE |
| posts | comments | post_id | CASCADE |
| profiles | comments | author_id | SET NULL |
| comments | comment_votes | comment_id | CASCADE |
| profiles | comment_votes | user_id | CASCADE |

---

## Access & role rules to enforce (logic, not columns)

These live in RLS policies / app logic when you build the schema — the fields above are
just the switches they read.

**Account tier (email gating)**
- `.edu` verified → `account_type = 'student'`, `edu_verified = true` → full access (Map, Feed, Messaging, Calendar).
- Personal email only → `account_type = 'alumni'` → restricted to **Messaging (chats/messages) + Calendar (events/event_rsvps + birthdays)** only. Block reads/writes on `posts`, `post_votes`, `comments`, `comment_votes`, `locations`.

**Joining a group**
- Students/users may self-request: insert a `memberships` row with `status='pending'` for themselves; an admin approves to `active`.
- Alumni may NOT self-request — block the self-insert path when `account_type='alumni'`. They can only join by accepting an `invitations` row, which creates an `active` membership with the invite's `role`.
- Only org admins may create `invitations` (`invited_by` must be an admin of `org_id`).

**Org membership roles** (`admin` / `user` / `alumni`)
- Admins can promote others to `admin` (role-change allowed only when the actor is an org admin).
- A regular `user` cannot promote itself — reject any self-update where `user_id = auth.uid()` and new `role = 'admin'`.
- An `alumni` cannot be an org admin — forbid `role = 'admin'` when the member's `account_type = 'alumni'` (CHECK via trigger, or enforce in the policy's `WITH CHECK`).

**Birthdays on the calendar**
- Birthday entries are derived, not stored: the `member_birthdays` view exposes each active member's `birthday` per org, so it appears on join and disappears on leave automatically. No trigger or event rows required.
