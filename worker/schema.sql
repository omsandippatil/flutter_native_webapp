-- schema.sql
-- D1 database schema for the Cloudflare Worker.
--
-- accounts: one row per phone number. Stores hashed password.
--   phone is the primary key — no email, no username.
--
-- profiles: one row per student under an account.
--   Multiple profiles share one account (phone).
--   Each profile has its own courseId and display info.
--
-- progress: one row per profile.
--   Stores currentStepIndex and completedActivityIds (JSON array).
--   Updated on every step completion.
--
-- sessions: tracks issued JWTs for logout blacklisting.
--   jti (JWT ID claim) is stored; on logout, jti is added here.
--   Worker checks this table on every authenticated request.

CREATE TABLE IF NOT EXISTS accounts (
  phone         TEXT PRIMARY KEY,
  password_hash TEXT NOT NULL,
  created_at    INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS profiles (
  profile_id    TEXT PRIMARY KEY,
  phone         TEXT NOT NULL REFERENCES accounts(phone),
  display_name  TEXT NOT NULL,
  avatar_index  INTEGER NOT NULL DEFAULT 0,
  course_id     TEXT NOT NULL,
  created_at    INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS progress (
  profile_id              TEXT PRIMARY KEY REFERENCES profiles(profile_id),
  current_step_index      INTEGER NOT NULL DEFAULT 0,
  completed_activity_ids  TEXT NOT NULL DEFAULT '[]',
  last_active_at          INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS sessions (
  jti        TEXT PRIMARY KEY,
  phone      TEXT NOT NULL,
  revoked    INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);
