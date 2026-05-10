[@@@alert "-deprecated"]

open Util
open Yojson.Basic.Util

module Q = struct
  open Caqti_request.Infix

  let create_user_role_type =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = ''user_role'') THEN
            CREATE TYPE user_role AS ENUM (''USER'', ''ADMIN'');
          END IF;
        END
        ';
      |}

  let create_task_type_type =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = ''task_type'') THEN
            CREATE TYPE task_type AS ENUM (''MODEL_CONSTRUCTION'');
          END IF;
        END
        ';
      |}

  let create_task_status_type =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = ''task_status'') THEN
            CREATE TYPE task_status AS ENUM (''DRAFT'', ''PUBLISHED'', ''ARCHIVED'');
          END IF;
        END
        ';
      |}

  let create_task_visibility_type =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = ''task_visibility'') THEN
            CREATE TYPE task_visibility AS ENUM (''PRIVATE'', ''PUBLIC'', ''UNLISTED'');
          END IF;
        END
        ';
      |}

  let create_submission_verdict_type =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = ''submission_verdict'') THEN
            CREATE TYPE submission_verdict AS ENUM (
              ''PENDING'',
              ''ACCEPTED'',
              ''REJECTED'',
              ''INVALID_FORMAT'',
              ''INTERNAL_ERROR''
            );
          END IF;
        END
        ';
      |}

  let acquire_schema_lock =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          PERFORM pg_advisory_lock(2026050801);
        END
        ';
      |}

  let release_schema_lock =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          PERFORM pg_advisory_unlock(2026050801);
        END
        ';
      |}

  let create_users_table =
    Caqti_type.(unit ->. unit)
      {|
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
        )
      |}

  let add_users_email_column =
    Caqti_type.(unit ->. unit)
      {|
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS email TEXT
      |}

  let backfill_users_email =
    Caqti_type.(unit ->. unit)
      {|
        UPDATE users
        SET email = username || '@recognita.local'
        WHERE email IS NULL OR BTRIM(email) = ''
      |}

  let set_users_email_not_null =
    Caqti_type.(unit ->. unit)
      {|
        ALTER TABLE users
        ALTER COLUMN email SET NOT NULL
      |}

  let drop_users_password_salt_column =
    Caqti_type.(unit ->. unit)
      {|
        ALTER TABLE users
        DROP COLUMN IF EXISTS password_salt
      |}

  let add_users_verified_column =
    Caqti_type.(unit ->. unit)
      {|
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS verified BOOLEAN
      |}

  let backfill_users_verified =
    Caqti_type.(unit ->. unit)
      {|
        UPDATE users
        SET verified = FALSE
        WHERE verified IS NULL
      |}

  let set_users_verified_default =
    Caqti_type.(unit ->. unit)
      {|
        ALTER TABLE users
        ALTER COLUMN verified SET DEFAULT FALSE
      |}

  let set_users_verified_not_null =
    Caqti_type.(unit ->. unit)
      {|
        ALTER TABLE users
        ALTER COLUMN verified SET NOT NULL
      |}

  let add_users_ban_columns =
    Caqti_type.(unit ->. unit)
      {|
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS is_banned BOOLEAN,
        ADD COLUMN IF NOT EXISTS ban_reason TEXT
      |}

  let backfill_users_ban_columns =
    Caqti_type.(unit ->. unit)
      {|
        UPDATE users
        SET is_banned = FALSE
        WHERE is_banned IS NULL
      |}

  let set_users_ban_defaults =
    Caqti_type.(unit ->. unit)
      {|
        ALTER TABLE users
        ALTER COLUMN is_banned SET DEFAULT FALSE,
        ALTER COLUMN is_banned SET NOT NULL
      |}

  let migrate_users_role_to_enum =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = ''users''
              AND column_name = ''role''
              AND udt_name <> ''user_role''
          ) THEN
            EXECUTE ''ALTER TABLE users ALTER COLUMN role TYPE user_role USING UPPER(role)::user_role'';
          END IF;
        END
        ';
      |}

  let set_users_role_defaults =
    Caqti_type.(unit ->. unit)
      {|
        ALTER TABLE users
        ALTER COLUMN role SET DEFAULT 'USER',
        ALTER COLUMN role SET NOT NULL
      |}

  let verify_admin_users =
    Caqti_type.(unit ->. unit)
      {|
        UPDATE users
        SET verified = TRUE
        WHERE role::text = 'ADMIN'
      |}

  let migrate_users_created_at =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = ''users''
              AND column_name = ''created_at''
              AND udt_name = ''float8''
          ) THEN
            EXECUTE ''ALTER TABLE users ALTER COLUMN created_at TYPE TIMESTAMPTZ USING to_timestamp(created_at)'';
          END IF;
        END
        ';
      |}

  let migrate_users_updated_at =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = ''users''
              AND column_name = ''updated_at''
              AND udt_name = ''float8''
          ) THEN
            EXECUTE ''ALTER TABLE users ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING to_timestamp(updated_at)'';
          END IF;
        END
        ';
      |}

  let set_users_timestamp_defaults =
    Caqti_type.(unit ->. unit)
      {|
        ALTER TABLE users
        ALTER COLUMN created_at SET DEFAULT now(),
        ALTER COLUMN updated_at SET DEFAULT now()
      |}

  let create_users_email_index =
    Caqti_type.(unit ->. unit)
      {|
        CREATE UNIQUE INDEX IF NOT EXISTS users_email_key ON users(email)
      |}

  let create_sessions_table =
    Caqti_type.(unit ->. unit)
      {|
        CREATE TABLE IF NOT EXISTS sessions (
          id BIGSERIAL PRIMARY KEY,
          user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          access_token TEXT UNIQUE NOT NULL,
          refresh_token TEXT UNIQUE NOT NULL,
          access_expires_at TIMESTAMPTZ NOT NULL,
          refresh_expires_at TIMESTAMPTZ NOT NULL,
          revoked_at TIMESTAMPTZ NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
      |}

  let migrate_sessions_access_expires_at =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = ''sessions''
              AND column_name = ''access_expires_at''
              AND udt_name = ''float8''
          ) THEN
            EXECUTE ''ALTER TABLE sessions ALTER COLUMN access_expires_at TYPE TIMESTAMPTZ USING to_timestamp(access_expires_at)'';
          END IF;
        END
        ';
      |}

  let migrate_sessions_refresh_expires_at =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = ''sessions''
              AND column_name = ''refresh_expires_at''
              AND udt_name = ''float8''
          ) THEN
            EXECUTE ''ALTER TABLE sessions ALTER COLUMN refresh_expires_at TYPE TIMESTAMPTZ USING to_timestamp(refresh_expires_at)'';
          END IF;
        END
        ';
      |}

  let migrate_sessions_revoked_at =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = ''sessions''
              AND column_name = ''revoked_at''
              AND udt_name = ''float8''
          ) THEN
            EXECUTE ''ALTER TABLE sessions ALTER COLUMN revoked_at TYPE TIMESTAMPTZ USING CASE WHEN revoked_at IS NULL THEN NULL ELSE to_timestamp(revoked_at) END'';
          END IF;
        END
        ';
      |}

  let migrate_sessions_created_at =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = ''sessions''
              AND column_name = ''created_at''
              AND udt_name = ''float8''
          ) THEN
            EXECUTE ''ALTER TABLE sessions ALTER COLUMN created_at TYPE TIMESTAMPTZ USING to_timestamp(created_at)'';
          END IF;
        END
        ';
      |}

  let set_sessions_timestamp_defaults =
    Caqti_type.(unit ->. unit)
      {|
        ALTER TABLE sessions
        ALTER COLUMN created_at SET DEFAULT now()
      |}

  let create_email_verifications_table =
    Caqti_type.(unit ->. unit)
      {|
        CREATE TABLE IF NOT EXISTS email_verifications (
          id BIGSERIAL PRIMARY KEY,
          user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          token TEXT UNIQUE NOT NULL,
          expires_at TIMESTAMPTZ NOT NULL,
          consumed_at TIMESTAMPTZ NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
      |}

  let migrate_email_verifications_expires_at =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = ''email_verifications''
              AND column_name = ''expires_at''
              AND udt_name = ''float8''
          ) THEN
            EXECUTE ''ALTER TABLE email_verifications ALTER COLUMN expires_at TYPE TIMESTAMPTZ USING to_timestamp(expires_at)'';
          END IF;
        END
        ';
      |}

  let migrate_email_verifications_consumed_at =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = ''email_verifications''
              AND column_name = ''consumed_at''
              AND udt_name = ''float8''
          ) THEN
            EXECUTE ''ALTER TABLE email_verifications ALTER COLUMN consumed_at TYPE TIMESTAMPTZ USING CASE WHEN consumed_at IS NULL THEN NULL ELSE to_timestamp(consumed_at) END'';
          END IF;
        END
        ';
      |}

  let migrate_email_verifications_created_at =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = ''email_verifications''
              AND column_name = ''created_at''
              AND udt_name = ''float8''
          ) THEN
            EXECUTE ''ALTER TABLE email_verifications ALTER COLUMN created_at TYPE TIMESTAMPTZ USING to_timestamp(created_at)'';
          END IF;
        END
        ';
      |}

  let set_email_verifications_timestamp_defaults =
    Caqti_type.(unit ->. unit)
      {|
        ALTER TABLE email_verifications
        ALTER COLUMN created_at SET DEFAULT now()
      |}

  let create_tasks_table =
    Caqti_type.(unit ->. unit)
      {|
        CREATE TABLE IF NOT EXISTS tasks (
          id BIGSERIAL PRIMARY KEY,
          title TEXT NOT NULL,
          slug TEXT UNIQUE,
          short_description TEXT,
          description TEXT NOT NULL,
          type task_type NOT NULL,
          author_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          difficulty SMALLINT NOT NULL CHECK (difficulty BETWEEN 0 AND 10),
          config JSONB NOT NULL,
          status task_status NOT NULL DEFAULT 'DRAFT',
          visibility task_visibility NOT NULL DEFAULT 'PRIVATE',
          created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
          published_at TIMESTAMPTZ,
          CHECK (status <> 'PUBLISHED' OR published_at IS NOT NULL),
          CHECK (jsonb_typeof(config) = 'object')
        )
      |}

  let ensure_tasks_author_delete_cascade =
    Caqti_type.(unit ->. unit)
      {|
        DO '
        DECLARE
          constraint_name text;
          delete_mode "char";
        BEGIN
          SELECT c.confdeltype INTO delete_mode
          FROM pg_constraint c
          JOIN pg_class t ON t.oid = c.conrelid
          JOIN pg_attribute a
            ON a.attrelid = t.oid AND a.attnum = ANY(c.conkey)
          WHERE t.relname = ''tasks''
            AND c.contype = ''f''
            AND a.attname = ''author_id''
          LIMIT 1;

          IF delete_mode IS DISTINCT FROM ''c'' THEN
            FOR constraint_name IN
              SELECT c.conname
              FROM pg_constraint c
              JOIN pg_class t ON t.oid = c.conrelid
              JOIN pg_attribute a
                ON a.attrelid = t.oid AND a.attnum = ANY(c.conkey)
              WHERE t.relname = ''tasks''
                AND c.contype = ''f''
                AND a.attname = ''author_id''
            LOOP
              EXECUTE ''ALTER TABLE tasks DROP CONSTRAINT '' || quote_ident(constraint_name);
            END LOOP;

            EXECUTE
              ''ALTER TABLE tasks ADD CONSTRAINT tasks_author_id_fkey FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE'';
          END IF;
        END
        ';
      |}

  let create_pg_trgm_extension =
    Caqti_type.(unit ->. unit)
      {|
        CREATE EXTENSION IF NOT EXISTS pg_trgm
      |}

  let create_tasks_indexes =
    Caqti_type.(unit ->. unit)
      {|
        CREATE INDEX IF NOT EXISTS tasks_difficulty_idx ON tasks (difficulty)
      |}

  let create_tasks_author_idx =
    Caqti_type.(unit ->. unit)
      {|
        CREATE INDEX IF NOT EXISTS tasks_author_idx ON tasks (author_id)
      |}

  let create_tasks_type_idx =
    Caqti_type.(unit ->. unit)
      {|
        CREATE INDEX IF NOT EXISTS tasks_type_idx ON tasks (type)
      |}

  let create_tasks_status_visibility_idx =
    Caqti_type.(unit ->. unit)
      {|
        CREATE INDEX IF NOT EXISTS tasks_status_visibility_idx ON tasks (status, visibility)
      |}

  let create_tasks_created_at_idx =
    Caqti_type.(unit ->. unit)
      {|
        CREATE INDEX IF NOT EXISTS tasks_created_at_idx ON tasks (created_at DESC)
      |}

  let create_tasks_title_trgm_idx =
    Caqti_type.(unit ->. unit)
      {|
        CREATE INDEX IF NOT EXISTS tasks_title_trgm_idx
        ON tasks USING gin (title gin_trgm_ops)
      |}

  let create_tasks_description_trgm_idx =
    Caqti_type.(unit ->. unit)
      {|
        CREATE INDEX IF NOT EXISTS tasks_description_trgm_idx
        ON tasks USING gin (description gin_trgm_ops)
      |}

  let create_submissions_table =
    Caqti_type.(unit ->. unit)
      {|
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
        )
      |}

  let create_submissions_task_id_idx =
    Caqti_type.(unit ->. unit)
      {|
        CREATE INDEX IF NOT EXISTS submissions_task_id_idx ON submissions (task_id)
      |}

  let create_submissions_user_id_idx =
    Caqti_type.(unit ->. unit)
      {|
        CREATE INDEX IF NOT EXISTS submissions_user_id_idx ON submissions (user_id)
      |}

  let create_submissions_task_user_created_at_idx =
    Caqti_type.(unit ->. unit)
      {|
        CREATE INDEX IF NOT EXISTS submissions_task_user_created_at_idx
        ON submissions (task_id, user_id, created_at DESC)
      |}

  let create_submissions_verdict_idx =
    Caqti_type.(unit ->. unit)
      {|
        CREATE INDEX IF NOT EXISTS submissions_verdict_idx ON submissions (verdict)
      |}

  let create_submissions_created_at_idx =
    Caqti_type.(unit ->. unit)
      {|
        CREATE INDEX IF NOT EXISTS submissions_created_at_idx ON submissions (created_at DESC)
      |}

  let create_submissions_pending_idx =
    Caqti_type.(unit ->. unit)
      {|
        CREATE INDEX IF NOT EXISTS submissions_pending_idx
        ON submissions (created_at)
        WHERE verdict = 'PENDING'
      |}

  let user_json =
    {|
      json_build_object(
        'id', id,
        'username', username,
        'email', email,
        'password_hash', password_hash,
        'role', role::text,
        'verified', verified,
        'is_banned', is_banned,
        'ban_reason', ban_reason,
        'created_at', EXTRACT(EPOCH FROM created_at),
        'updated_at', EXTRACT(EPOCH FROM updated_at)
      )::text
    |}

  let public_user_json =
    {|
      json_build_object(
        'id', id,
        'username', username,
        'email', email,
        'role', role::text,
        'verified', verified,
        'is_banned', is_banned,
        'ban_reason', ban_reason,
        'created_at', EXTRACT(EPOCH FROM created_at),
        'updated_at', EXTRACT(EPOCH FROM updated_at)
      )
    |}

  let session_json =
    {|
      json_build_object(
        'id', id,
        'user_id', user_id,
        'access_token', access_token,
        'refresh_token', refresh_token,
        'access_expires_at', EXTRACT(EPOCH FROM access_expires_at),
        'refresh_expires_at', EXTRACT(EPOCH FROM refresh_expires_at),
        'revoked_at', CASE WHEN revoked_at IS NULL THEN NULL ELSE EXTRACT(EPOCH FROM revoked_at) END,
        'created_at', EXTRACT(EPOCH FROM created_at)
      )::text
    |}

  let email_verification_json =
    {|
      json_build_object(
        'id', id,
        'user_id', user_id,
        'token', token,
        'expires_at', EXTRACT(EPOCH FROM expires_at),
        'consumed_at', CASE WHEN consumed_at IS NULL THEN NULL ELSE EXTRACT(EPOCH FROM consumed_at) END,
        'created_at', EXTRACT(EPOCH FROM created_at)
      )::text
    |}

  let task_json =
    {|
      json_build_object(
        'id', id,
        'title', title,
        'slug', slug,
        'short_description', short_description,
        'description', description,
        'type', type::text,
        'author_id', author_id,
        'difficulty', difficulty,
        'config', config,
        'status', status::text,
        'visibility', visibility::text,
        'created_at', EXTRACT(EPOCH FROM created_at),
        'updated_at', EXTRACT(EPOCH FROM updated_at),
        'published_at', CASE WHEN published_at IS NULL THEN NULL ELSE EXTRACT(EPOCH FROM published_at) END
      )::text
    |}

  let submission_json =
    {|
      json_build_object(
        'id', id,
        'task_id', task_id,
        'user_id', user_id,
        'data', data,
        'verdict', verdict::text,
        'run_data', run_data,
        'created_at', EXTRACT(EPOCH FROM created_at),
        'judged_at', CASE WHEN judged_at IS NULL THEN NULL ELSE EXTRACT(EPOCH FROM judged_at) END
      )::text
    |}

  let find_user_by_username =
    Caqti_type.(string ->? string)
      ("SELECT " ^ user_json ^ " FROM users WHERE username = ?")

  let find_user_by_email =
    Caqti_type.(string ->? string)
      ("SELECT " ^ user_json ^ " FROM users WHERE email = ?")

  let find_user_by_id =
    Caqti_type.(int ->? string)
      ("SELECT " ^ user_json ^ " FROM users WHERE id = ?")

  let create_user =
    Caqti_type.(tup4 string string string (tup3 string float float) ->! string)
      ({|
        INSERT INTO users (
          username,
          email,
          password_hash,
          role,
          verified,
          created_at,
          updated_at
        )
        VALUES (?, ?, ?, CAST(? AS user_role), FALSE, to_timestamp(?), to_timestamp(?))
        RETURNING
      |}
      ^ user_json)

  let list_users =
    Caqti_type.(unit ->! string)
      ({|
        SELECT COALESCE(
          json_agg(payload ORDER BY user_id)::text,
          '[]'
        )
        FROM (
          SELECT
            id AS user_id,
      |}
      ^ public_user_json
      ^ {|
              AS payload
          FROM users
          ORDER BY id
        ) ordered_users
      |})

  let update_role =
    Caqti_type.(tup4 string string float int ->? string)
      ({|
        UPDATE users
        SET
          role = CAST(? AS user_role),
          verified = CASE WHEN ? = 'ADMIN' THEN TRUE ELSE verified END,
          updated_at = to_timestamp(?)
        WHERE id = ?
        RETURNING
      |}
      ^ user_json)

  let update_ban =
    Caqti_type.(tup4 bool (option string) float int ->? string)
      ({|
        UPDATE users
        SET
          is_banned = ?,
          ban_reason = ?,
          updated_at = to_timestamp(?)
        WHERE id = ?
        RETURNING
      |}
      ^ user_json)

  let mark_user_verified =
    Caqti_type.(tup2 float int ->? string)
      ({|
        UPDATE users
        SET
          verified = TRUE,
          updated_at = to_timestamp(?)
        WHERE id = ?
        RETURNING
      |}
      ^ user_json)

  let delete_user =
    Caqti_type.(int ->? string)
      ({|
        DELETE FROM users
        WHERE id = ?
        RETURNING
      |}
      ^ user_json)

  let create_session =
    Caqti_type.(tup4 int string string (tup3 float float float) ->! string)
      ({|
        INSERT INTO sessions (
          user_id,
          access_token,
          refresh_token,
          access_expires_at,
          refresh_expires_at,
          created_at
        )
        VALUES (?, ?, ?, to_timestamp(?), to_timestamp(?), to_timestamp(?))
        RETURNING
      |}
      ^ session_json)

  let find_session_by_access_token =
    Caqti_type.(string ->? string)
      ("SELECT " ^ session_json ^ " FROM sessions WHERE access_token = ?")

  let find_session_by_refresh_token =
    Caqti_type.(string ->? string)
      ("SELECT " ^ session_json ^ " FROM sessions WHERE refresh_token = ?")

  let revoke_session =
    Caqti_type.(tup2 float int ->. unit)
      {|
        UPDATE sessions
        SET revoked_at = to_timestamp(?)
        WHERE id = ?
      |}

  let revoke_user_sessions =
    Caqti_type.(tup2 float int ->. unit)
      {|
        UPDATE sessions
        SET revoked_at = to_timestamp(?)
        WHERE user_id = ? AND revoked_at IS NULL
      |}

  let create_email_verification =
    Caqti_type.(tup4 int string float float ->! string)
      ({|
        INSERT INTO email_verifications (
          user_id,
          token,
          expires_at,
          created_at
        )
        VALUES (?, ?, to_timestamp(?), to_timestamp(?))
        RETURNING
      |}
      ^ email_verification_json)

  let find_email_verification_by_token =
    Caqti_type.(string ->? string)
      ("SELECT " ^ email_verification_json
     ^ " FROM email_verifications WHERE token = ?")

  let consume_email_verification =
    Caqti_type.(tup2 float int ->. unit)
      {|
        UPDATE email_verifications
        SET consumed_at = to_timestamp(?)
        WHERE id = ?
      |}

  let create_task =
    Caqti_type.(
      tup4 string (option string) (option string)
        (tup4 string string int (tup4 int string string (tup4 string (option float) float float)))
      ->! string)
      ({|
        INSERT INTO tasks (
          title,
          slug,
          short_description,
          description,
          type,
          difficulty,
          author_id,
          config,
          status,
          visibility,
          published_at,
          created_at,
          updated_at
        )
        VALUES (
          ?,
          ?,
          ?,
          ?,
          CAST(? AS task_type),
          ?,
          ?,
          CAST(? AS jsonb),
          CAST(? AS task_status),
          CAST(? AS task_visibility),
          to_timestamp(?),
          to_timestamp(?),
          to_timestamp(?)
        )
        RETURNING
      |}
      ^ task_json)

  let list_tasks =
    Caqti_type.(unit ->! string)
      ({|
        SELECT COALESCE(
          json_agg(payload ORDER BY created_at_epoch DESC)::text,
          '[]'
        )
        FROM (
          SELECT
            EXTRACT(EPOCH FROM created_at) AS created_at_epoch,
      |}
      ^ task_json
      ^ {|
              AS payload
          FROM tasks
          ORDER BY created_at DESC
        ) ordered_tasks
      |})

  let find_task_by_id =
    Caqti_type.(int ->? string)
      ("SELECT " ^ task_json ^ " FROM tasks WHERE id = ?")

  let find_task_by_slug =
    Caqti_type.(string ->? string)
      ("SELECT " ^ task_json ^ " FROM tasks WHERE slug = ?")

  let create_submission =
    Caqti_type.(tup4 int int string float ->! string)
      ({|
        INSERT INTO submissions (
          task_id,
          user_id,
          data,
          verdict,
          created_at
        )
        VALUES (?, ?, CAST(? AS jsonb), 'PENDING', to_timestamp(?))
        RETURNING
      |}
      ^ submission_json)

  let find_submission_by_id =
    Caqti_type.(int ->? string)
      ("SELECT " ^ submission_json ^ " FROM submissions WHERE id = ?")

  let list_submissions =
    Caqti_type.(unit ->! string)
      ({|
        SELECT COALESCE(
          json_agg(payload ORDER BY created_at_epoch DESC)::text,
          '[]'
        )
        FROM (
          SELECT
            EXTRACT(EPOCH FROM created_at) AS created_at_epoch,
      |}
      ^ submission_json
      ^ {|
              AS payload
          FROM submissions
          ORDER BY created_at DESC
        ) ordered_submissions
      |})

  let list_submissions_by_user =
    Caqti_type.(int ->! string)
      ({|
        SELECT COALESCE(
          json_agg(payload ORDER BY created_at_epoch DESC)::text,
          '[]'
        )
        FROM (
          SELECT
            EXTRACT(EPOCH FROM created_at) AS created_at_epoch,
      |}
      ^ submission_json
      ^ {|
              AS payload
          FROM submissions
          WHERE user_id = ?
          ORDER BY created_at DESC
        ) ordered_submissions
      |})

  let update_submission_result =
    Caqti_type.(tup4 string (option string) float int ->? string)
      ({|
        UPDATE submissions
        SET
          verdict = CAST(? AS submission_verdict),
          run_data = CAST(? AS jsonb),
          judged_at = to_timestamp(?)
        WHERE id = ?
        RETURNING
      |}
      ^ submission_json)
end

let contains needle haystack =
  try
    ignore (Str.search_forward (Str.regexp_string needle) haystack 0);
    true
  with Not_found -> false

let classify_error message =
  if contains "users_email_key" message then
    Repository.Conflict "Email already exists"
  else if contains "users_username_key" message then
    Repository.Conflict "Username already exists"
  else if contains "tasks_slug_key" message then
    Repository.Conflict "Task slug already exists"
  else if contains "duplicate key" message || contains "23505" message then
    Repository.Conflict "Unique field already exists"
  else
    Repository.Storage message

let map_caqti_error error = classify_error (Caqti_error.show error)

let parse_role value =
  match Domain.role_of_string value with
  | Some role -> Ok role
  | None -> Error (Repository.Storage ("Unknown role: " ^ value))

let parse_task_type value =
  match Domain.task_type_of_string value with
  | Some task_type -> Ok task_type
  | None -> Error (Repository.Storage ("Unknown task type: " ^ value))

let parse_task_status value =
  match Domain.task_status_of_string value with
  | Some status -> Ok status
  | None -> Error (Repository.Storage ("Unknown task status: " ^ value))

let parse_task_visibility value =
  match Domain.task_visibility_of_string value with
  | Some visibility -> Ok visibility
  | None -> Error (Repository.Storage ("Unknown task visibility: " ^ value))

let parse_submission_verdict value =
  match Domain.submission_verdict_of_string value with
  | Some verdict -> Ok verdict
  | None -> Error (Repository.Storage ("Unknown submission verdict: " ^ value))

let parse_user json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    match parse_role (json |> member "role" |> to_string) with
    | Error _ as error -> error
    | Ok role ->
        Ok
          {
            Domain.id = json |> member "id" |> to_int;
            username = json |> member "username" |> to_string;
            email = json |> member "email" |> to_string;
            password_hash = json |> member "password_hash" |> to_string;
            role;
            verified = json |> member "verified" |> to_bool;
            is_banned = json |> member "is_banned" |> to_bool;
            ban_reason = json |> member "ban_reason" |> to_option to_string;
            created_at = json |> member "created_at" |> to_float;
            updated_at = json |> member "updated_at" |> to_float;
          }
  with exn -> Error (Repository.Storage ("Failed to decode user JSON: " ^ pp_exn exn))

let parse_public_user json =
  try
    match parse_role (json |> member "role" |> to_string) with
    | Error _ as error -> error
    | Ok role ->
        Ok
          {
            Domain.id = json |> member "id" |> to_int;
            username = json |> member "username" |> to_string;
            email = json |> member "email" |> to_string;
            role;
            verified = json |> member "verified" |> to_bool;
            is_banned = json |> member "is_banned" |> to_bool;
            ban_reason = json |> member "ban_reason" |> to_option to_string;
            created_at = json |> member "created_at" |> to_float;
            updated_at = json |> member "updated_at" |> to_float;
          }
  with exn ->
    Error (Repository.Storage ("Failed to decode public user JSON: " ^ pp_exn exn))

let parse_session json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    Ok
      {
        Domain.id = json |> member "id" |> to_int;
        user_id = json |> member "user_id" |> to_int;
        access_token = json |> member "access_token" |> to_string;
        refresh_token = json |> member "refresh_token" |> to_string;
        access_expires_at = json |> member "access_expires_at" |> to_float;
        refresh_expires_at = json |> member "refresh_expires_at" |> to_float;
        revoked_at = json |> member "revoked_at" |> to_option to_float;
        created_at = json |> member "created_at" |> to_float;
      }
  with exn ->
    Error (Repository.Storage ("Failed to decode session JSON: " ^ pp_exn exn))

let parse_email_verification json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    Ok
      {
        Domain.id = json |> member "id" |> to_int;
        user_id = json |> member "user_id" |> to_int;
        token = json |> member "token" |> to_string;
        expires_at = json |> member "expires_at" |> to_float;
        consumed_at = json |> member "consumed_at" |> to_option to_float;
        created_at = json |> member "created_at" |> to_float;
      }
  with exn ->
    Error
      (Repository.Storage
         ("Failed to decode verification JSON: " ^ pp_exn exn))

let parse_task json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    match
      ( parse_task_type (json |> member "type" |> to_string),
        parse_task_status (json |> member "status" |> to_string),
        parse_task_visibility (json |> member "visibility" |> to_string) )
    with
    | (Error _ as error), _, _
    | _, (Error _ as error), _
    | _, _, (Error _ as error) ->
        error
    | Ok type_, Ok status, Ok visibility ->
        Ok
          {
            Domain.id = json |> member "id" |> to_int;
            title = json |> member "title" |> to_string;
            slug = json |> member "slug" |> to_option to_string;
            short_description =
              json |> member "short_description" |> to_option to_string;
            description = json |> member "description" |> to_string;
            type_;
            author_id = json |> member "author_id" |> to_int;
            difficulty = json |> member "difficulty" |> to_int;
            config = json |> member "config";
            status;
            visibility;
            created_at = json |> member "created_at" |> to_float;
            updated_at = json |> member "updated_at" |> to_float;
            published_at = json |> member "published_at" |> to_option to_float;
          }
  with exn ->
    Error (Repository.Storage ("Failed to decode task JSON: " ^ pp_exn exn))

let parse_submission json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    match parse_submission_verdict (json |> member "verdict" |> to_string) with
    | Error _ as error -> error
    | Ok verdict ->
        Ok
          {
            Domain.id = json |> member "id" |> to_int;
            task_id = json |> member "task_id" |> to_int;
            user_id = json |> member "user_id" |> to_int;
            data = json |> member "data";
            verdict;
            run_data = json |> member "run_data" |> to_option (fun value -> value);
            created_at = json |> member "created_at" |> to_float;
            judged_at = json |> member "judged_at" |> to_option to_float;
          }
  with exn ->
    Error
      (Repository.Storage ("Failed to decode submission JSON: " ^ pp_exn exn))

let parse_public_user_list json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    match json with
    | `List items ->
        let rec loop acc = function
          | [] -> Ok (List.rev acc)
          | item :: rest -> (
              match parse_public_user item with
              | Ok parsed -> loop (parsed :: acc) rest
              | Error _ as error -> error)
        in
        loop [] items
    | _ -> Error (Repository.Storage "Expected a JSON array for users list")
  with exn ->
    Error (Repository.Storage ("Failed to decode users JSON: " ^ pp_exn exn))

let json_item_text = function
  | `String value -> value
  | value -> Yojson.Basic.to_string value

let parse_task_list json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    match json with
    | `List items ->
        let rec loop acc = function
          | [] -> Ok (List.rev acc)
          | item :: rest -> (
              match parse_task (json_item_text item) with
              | Ok parsed -> loop (parsed :: acc) rest
              | Error _ as error -> error)
        in
        loop [] items
    | _ -> Error (Repository.Storage "Expected a JSON array for tasks list")
  with exn ->
    Error (Repository.Storage ("Failed to decode tasks JSON: " ^ pp_exn exn))

let parse_submission_list json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    match json with
    | `List items ->
        let rec loop acc = function
          | [] -> Ok (List.rev acc)
          | item :: rest -> (
              match parse_submission (json_item_text item) with
              | Ok parsed -> loop (parsed :: acc) rest
              | Error _ as error -> error)
        in
        loop [] items
    | _ -> Error (Repository.Storage "Expected a JSON array for submissions list")
  with exn ->
    Error
      (Repository.Storage ("Failed to decode submissions JSON: " ^ pp_exn exn))

let make (db : Caqti_lwt.connection) =
  let module Db = (val db : Caqti_lwt.CONNECTION) in
  let run_exec query params =
    let* result = Db.exec query params in
    Lwt.return
      (match result with
      | Ok () -> Ok ()
      | Error error -> Error (map_caqti_error error))
  in
  let ( let** ) value next =
    let* result = value in
    match result with
    | Error _ as error -> Lwt.return error
    | Ok ok -> next ok
  in
  let init_schema () =
    let* lock_result = run_exec Q.acquire_schema_lock () in
    match lock_result with
    | Error _ as error -> Lwt.return error
    | Ok () ->
        let* result =
          let** () = run_exec Q.create_user_role_type () in
          let** () = run_exec Q.create_task_type_type () in
          let** () = run_exec Q.create_task_status_type () in
          let** () = run_exec Q.create_task_visibility_type () in
          let** () = run_exec Q.create_submission_verdict_type () in
          let** () = run_exec Q.create_users_table () in
          let** () = run_exec Q.add_users_email_column () in
          let** () = run_exec Q.backfill_users_email () in
          let** () = run_exec Q.set_users_email_not_null () in
          let** () = run_exec Q.drop_users_password_salt_column () in
          let** () = run_exec Q.add_users_verified_column () in
          let** () = run_exec Q.backfill_users_verified () in
          let** () = run_exec Q.add_users_ban_columns () in
          let** () = run_exec Q.backfill_users_ban_columns () in
          let** () = run_exec Q.set_users_ban_defaults () in
          let** () = run_exec Q.migrate_users_role_to_enum () in
          let** () = run_exec Q.set_users_role_defaults () in
          let** () = run_exec Q.verify_admin_users () in
          let** () = run_exec Q.set_users_verified_default () in
          let** () = run_exec Q.set_users_verified_not_null () in
          let** () = run_exec Q.migrate_users_created_at () in
          let** () = run_exec Q.migrate_users_updated_at () in
          let** () = run_exec Q.set_users_timestamp_defaults () in
          let** () = run_exec Q.create_users_email_index () in
          let** () = run_exec Q.create_sessions_table () in
          let** () = run_exec Q.migrate_sessions_access_expires_at () in
          let** () = run_exec Q.migrate_sessions_refresh_expires_at () in
          let** () = run_exec Q.migrate_sessions_revoked_at () in
          let** () = run_exec Q.migrate_sessions_created_at () in
          let** () = run_exec Q.set_sessions_timestamp_defaults () in
          let** () = run_exec Q.create_email_verifications_table () in
          let** () = run_exec Q.migrate_email_verifications_expires_at () in
          let** () = run_exec Q.migrate_email_verifications_consumed_at () in
          let** () = run_exec Q.migrate_email_verifications_created_at () in
          let** () = run_exec Q.set_email_verifications_timestamp_defaults () in
          let** () = run_exec Q.create_tasks_table () in
          let** () = run_exec Q.ensure_tasks_author_delete_cascade () in
          let** () = run_exec Q.create_pg_trgm_extension () in
          let** () = run_exec Q.create_tasks_indexes () in
          let** () = run_exec Q.create_tasks_author_idx () in
          let** () = run_exec Q.create_tasks_type_idx () in
          let** () = run_exec Q.create_tasks_status_visibility_idx () in
          let** () = run_exec Q.create_tasks_created_at_idx () in
          let** () = run_exec Q.create_tasks_title_trgm_idx () in
          let** () = run_exec Q.create_tasks_description_trgm_idx () in
          let** () = run_exec Q.create_submissions_table () in
          let** () = run_exec Q.create_submissions_task_id_idx () in
          let** () = run_exec Q.create_submissions_user_id_idx () in
          let** () = run_exec Q.create_submissions_task_user_created_at_idx () in
          let** () = run_exec Q.create_submissions_verdict_idx () in
          let** () = run_exec Q.create_submissions_created_at_idx () in
          run_exec Q.create_submissions_pending_idx ()
        in
        let* unlock_result = run_exec Q.release_schema_lock () in
        begin
          match result, unlock_result with
          | Error _ as error, _ -> Lwt.return error
          | Ok _, (Error _ as error) -> Lwt.return error
          | Ok (), Ok () -> Lwt.return (Ok ())
        end
  in
  let find_user_by_username username =
    let* result = Db.find_opt Q.find_user_by_username username in
    match result with
    | Error error -> Lwt.return (Error (map_caqti_error error))
    | Ok None -> Lwt.return (Ok None)
    | Ok (Some json) -> Lwt.return (Result.map Option.some (parse_user json))
  in
  let find_user_by_email email =
    let* result = Db.find_opt Q.find_user_by_email email in
    match result with
    | Error error -> Lwt.return (Error (map_caqti_error error))
    | Ok None -> Lwt.return (Ok None)
    | Ok (Some json) -> Lwt.return (Result.map Option.some (parse_user json))
  in
  let find_user_by_id user_id =
    let* result = Db.find_opt Q.find_user_by_id user_id in
    match result with
    | Error error -> Lwt.return (Error (map_caqti_error error))
    | Ok None -> Lwt.return (Ok None)
    | Ok (Some json) -> Lwt.return (Result.map Option.some (parse_user json))
  in
  let create_user ~username ~email ~password_hash ~role ~created_at =
    let* result =
      Db.find Q.create_user
        ( username,
          email,
          password_hash,
          (Domain.role_to_db_string role, created_at, created_at) )
    in
    Lwt.return
      (match result with
      | Ok json -> parse_user json
      | Error error -> Error (map_caqti_error error))
  in
  let list_users () =
    let* result = Db.find Q.list_users () in
    Lwt.return
      (match result with
      | Ok json -> parse_public_user_list json
      | Error error -> Error (map_caqti_error error))
  in
  let update_role ~user_id ~role ~updated_at =
    let role_name = Domain.role_to_db_string role in
    let* result =
      Db.find_opt Q.update_role (role_name, role_name, updated_at, user_id)
    in
    Lwt.return
      (match result with
      | Ok None -> Ok None
      | Ok (Some json) -> Result.map Option.some (parse_user json)
      | Error error -> Error (map_caqti_error error))
  in
  let update_ban ~user_id ~is_banned ~ban_reason ~updated_at =
    let* result =
      Db.find_opt Q.update_ban (is_banned, ban_reason, updated_at, user_id)
    in
    Lwt.return
      (match result with
      | Ok None -> Ok None
      | Ok (Some json) -> Result.map Option.some (parse_user json)
      | Error error -> Error (map_caqti_error error))
  in
  let mark_user_verified ~user_id ~updated_at =
    let* result = Db.find_opt Q.mark_user_verified (updated_at, user_id) in
    Lwt.return
      (match result with
      | Ok None -> Ok None
      | Ok (Some json) -> Result.map Option.some (parse_user json)
      | Error error -> Error (map_caqti_error error))
  in
  let delete_user ~user_id =
    let* result = Db.find_opt Q.delete_user user_id in
    Lwt.return
      (match result with
      | Ok None -> Ok None
      | Ok (Some json) -> Result.map Option.some (parse_user json)
      | Error error -> Error (map_caqti_error error))
  in
  let create_session ~user_id ~access_token ~refresh_token ~access_expires_at
      ~refresh_expires_at ~created_at =
    let* result =
      Db.find Q.create_session
        ( user_id,
          access_token,
          refresh_token,
          (access_expires_at, refresh_expires_at, created_at) )
    in
    Lwt.return
      (match result with
      | Ok json -> parse_session json
      | Error error -> Error (map_caqti_error error))
  in
  let find_session_by_access_token access_token =
    let* result = Db.find_opt Q.find_session_by_access_token access_token in
    Lwt.return
      (match result with
      | Ok None -> Ok None
      | Ok (Some json) -> Result.map Option.some (parse_session json)
      | Error error -> Error (map_caqti_error error))
  in
  let find_session_by_refresh_token refresh_token =
    let* result = Db.find_opt Q.find_session_by_refresh_token refresh_token in
    Lwt.return
      (match result with
      | Ok None -> Ok None
      | Ok (Some json) -> Result.map Option.some (parse_session json)
      | Error error -> Error (map_caqti_error error))
  in
  let revoke_session ~session_id ~revoked_at =
    let* result = Db.exec Q.revoke_session (revoked_at, session_id) in
    Lwt.return
      (match result with
      | Ok () -> Ok ()
      | Error error -> Error (map_caqti_error error))
  in
  let revoke_user_sessions ~user_id ~revoked_at =
    let* result = Db.exec Q.revoke_user_sessions (revoked_at, user_id) in
    Lwt.return
      (match result with
      | Ok () -> Ok ()
      | Error error -> Error (map_caqti_error error))
  in
  let create_email_verification ~user_id ~token ~expires_at ~created_at =
    let* result =
      Db.find Q.create_email_verification (user_id, token, expires_at, created_at)
    in
    Lwt.return
      (match result with
      | Ok json -> parse_email_verification json
      | Error error -> Error (map_caqti_error error))
  in
  let find_email_verification_by_token token =
    let* result = Db.find_opt Q.find_email_verification_by_token token in
    Lwt.return
      (match result with
      | Ok None -> Ok None
      | Ok (Some json) ->
          Result.map Option.some (parse_email_verification json)
      | Error error -> Error (map_caqti_error error))
  in
  let consume_email_verification ~verification_id ~consumed_at =
    let* result =
      Db.exec Q.consume_email_verification (consumed_at, verification_id)
    in
    Lwt.return
      (match result with
      | Ok () -> Ok ()
      | Error error -> Error (map_caqti_error error))
  in
  let create_task ~title ~slug ~short_description ~description ~type_ ~author_id
      ~difficulty ~config ~status ~visibility ~published_at ~created_at
      ~updated_at =
    let* result =
      Db.find Q.create_task
        ( title,
          slug,
          short_description,
          ( description,
            Domain.task_type_to_string type_,
            difficulty,
            ( author_id,
              Yojson.Basic.to_string config,
              Domain.task_status_to_string status,
              ( Domain.task_visibility_to_string visibility,
                published_at,
                created_at,
                updated_at ) ) ) )
    in
    Lwt.return
      (match result with
      | Ok json -> parse_task json
      | Error error -> Error (map_caqti_error error))
  in
  let list_tasks () =
    let* result = Db.find Q.list_tasks () in
    Lwt.return
      (match result with
      | Ok json -> parse_task_list json
      | Error error -> Error (map_caqti_error error))
  in
  let find_task_by_id task_id =
    let* result = Db.find_opt Q.find_task_by_id task_id in
    Lwt.return
      (match result with
      | Ok None -> Ok None
      | Ok (Some json) -> Result.map Option.some (parse_task json)
      | Error error -> Error (map_caqti_error error))
  in
  let find_task_by_slug slug =
    let* result = Db.find_opt Q.find_task_by_slug slug in
    Lwt.return
      (match result with
      | Ok None -> Ok None
      | Ok (Some json) -> Result.map Option.some (parse_task json)
      | Error error -> Error (map_caqti_error error))
  in
  let create_submission ~task_id ~user_id ~data ~created_at =
    let* result =
      Db.find Q.create_submission
        (task_id, user_id, Yojson.Basic.to_string data, created_at)
    in
    Lwt.return
      (match result with
      | Ok json -> parse_submission json
      | Error error -> Error (map_caqti_error error))
  in
  let list_submissions () =
    let* result = Db.find Q.list_submissions () in
    Lwt.return
      (match result with
      | Ok json -> parse_submission_list json
      | Error error -> Error (map_caqti_error error))
  in
  let list_submissions_by_user ~user_id =
    let* result = Db.find Q.list_submissions_by_user user_id in
    Lwt.return
      (match result with
      | Ok json -> parse_submission_list json
      | Error error -> Error (map_caqti_error error))
  in
  let find_submission_by_id submission_id =
    let* result = Db.find_opt Q.find_submission_by_id submission_id in
    Lwt.return
      (match result with
      | Ok None -> Ok None
      | Ok (Some json) -> Result.map Option.some (parse_submission json)
      | Error error -> Error (map_caqti_error error))
  in
  let update_submission_result ~submission_id ~verdict ~run_data ~judged_at =
    let encoded_run_data =
      match run_data with
      | Some json -> Some (Yojson.Basic.to_string json)
      | None -> None
    in
    let* result =
      Db.find_opt Q.update_submission_result
        ( Domain.submission_verdict_to_string verdict,
          encoded_run_data,
          judged_at,
          submission_id )
    in
    Lwt.return
      (match result with
      | Ok None -> Ok None
      | Ok (Some json) -> Result.map Option.some (parse_submission json)
      | Error error -> Error (map_caqti_error error))
  in
  {
    Repository.init_schema;
    find_user_by_username;
    find_user_by_email;
    find_user_by_id;
    create_user;
    list_users;
    update_role;
    update_ban;
    create_session;
    find_session_by_access_token;
    find_session_by_refresh_token;
    revoke_session;
    revoke_user_sessions;
    create_email_verification;
    find_email_verification_by_token;
    consume_email_verification;
    mark_user_verified;
    delete_user;
    create_task;
    list_tasks;
    find_task_by_id;
    find_task_by_slug;
    create_submission;
    list_submissions;
    list_submissions_by_user;
    find_submission_by_id;
    update_submission_result;
  }
