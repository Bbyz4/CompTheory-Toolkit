DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('USER', 'ADMIN');
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  email TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  role user_role NOT NULL DEFAULT 'USER',
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_banned BOOLEAN NOT NULL DEFAULT FALSE,
  ban_reason TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS users_email_key ON users(email);

CREATE TABLE IF NOT EXISTS sessions (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  access_token TEXT UNIQUE NOT NULL,
  refresh_token TEXT UNIQUE NOT NULL,
  access_expires_at TIMESTAMPTZ NOT NULL,
  refresh_expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS email_verifications (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT UNIQUE NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_type') THEN
    CREATE TYPE task_type AS ENUM ('MODEL_CONSTRUCTION');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_status') THEN
    CREATE TYPE task_status AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_visibility') THEN
    CREATE TYPE task_visibility AS ENUM ('PRIVATE', 'PUBLIC', 'UNLISTED');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'submission_verdict') THEN
    CREATE TYPE submission_verdict AS ENUM (
      'PENDING',
      'ACCEPTED',
      'REJECTED',
      'INVALID_FORMAT',
      'INTERNAL_ERROR'
    );
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS tasks (
  id BIGSERIAL PRIMARY KEY,

  title TEXT NOT NULL,
  slug TEXT UNIQUE,
  short_description TEXT,
  description TEXT NOT NULL,

  type task_type NOT NULL,

  author_id BIGINT NOT NULL REFERENCES users(id),

  difficulty SMALLINT NOT NULL CHECK (difficulty BETWEEN 0 AND 10),

  config JSONB NOT NULL,

  status task_status NOT NULL DEFAULT 'DRAFT',
  visibility task_visibility NOT NULL DEFAULT 'PRIVATE',

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  published_at TIMESTAMPTZ,

  CHECK (
    status <> 'PUBLISHED'
    OR published_at IS NOT NULL
  ),

  CHECK (jsonb_typeof(config) = 'object')
);

CREATE INDEX IF NOT EXISTS tasks_difficulty_idx
  ON tasks (difficulty);

CREATE INDEX IF NOT EXISTS tasks_author_idx
  ON tasks (author_id);

CREATE INDEX IF NOT EXISTS tasks_type_idx
  ON tasks (type);

CREATE INDEX IF NOT EXISTS tasks_status_visibility_idx
  ON tasks (status, visibility);

CREATE INDEX IF NOT EXISTS tasks_created_at_idx
  ON tasks (created_at DESC);

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS tasks_title_trgm_idx
  ON tasks USING gin (title gin_trgm_ops);

CREATE INDEX IF NOT EXISTS tasks_description_trgm_idx
  ON tasks USING gin (description gin_trgm_ops);

CREATE TABLE IF NOT EXISTS submissions (
  id BIGSERIAL PRIMARY KEY,

  task_id BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  data JSONB NOT NULL,

  verdict submission_verdict NOT NULL DEFAULT 'PENDING',

  run_data JSONB DEFAULT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  judged_at TIMESTAMPTZ,

  CHECK (jsonb_typeof(data) = 'object'),
  CHECK (run_data IS NULL OR jsonb_typeof(run_data) = 'object')
);

CREATE INDEX IF NOT EXISTS submissions_task_id_idx
  ON submissions (task_id);

CREATE INDEX IF NOT EXISTS submissions_user_id_idx
  ON submissions (user_id);

CREATE INDEX IF NOT EXISTS submissions_task_user_created_at_idx
  ON submissions (task_id, user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS submissions_verdict_idx
  ON submissions (verdict);

CREATE INDEX IF NOT EXISTS submissions_created_at_idx
  ON submissions (created_at DESC);

CREATE INDEX IF NOT EXISTS submissions_pending_idx
  ON submissions (created_at)
  WHERE verdict = 'PENDING';
