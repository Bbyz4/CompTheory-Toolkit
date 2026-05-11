[@@@alert "-deprecated"]

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

  let update_bootstrap_admin =
    Caqti_type.(tup4 string string float int ->? string)
      ({|
        UPDATE users
        SET
          email = ?,
          password_hash = ?,
          role = 'ADMIN',
          verified = TRUE,
          is_banned = FALSE,
          ban_reason = NULL,
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
