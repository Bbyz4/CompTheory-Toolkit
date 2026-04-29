[@@@alert "-deprecated"]

open Util
open Yojson.Basic.Util

module Q = struct
  open Caqti_request.Infix

  let create_users_table =
    Caqti_type.(unit ->. unit)
      {|
        CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          username TEXT UNIQUE NOT NULL,
          email TEXT NOT NULL,
          password_hash TEXT NOT NULL,
          role TEXT NOT NULL,
          verified BOOLEAN NOT NULL DEFAULT FALSE,
          is_banned BOOLEAN NOT NULL DEFAULT FALSE,
          ban_reason TEXT NULL,
          created_at DOUBLE PRECISION NOT NULL,
          updated_at DOUBLE PRECISION NOT NULL
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

  let create_users_email_index =
    Caqti_type.(unit ->. unit)
      {|
        CREATE UNIQUE INDEX IF NOT EXISTS users_email_key ON users(email)
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

  let verify_admin_users =
    Caqti_type.(unit ->. unit)
      {|
        UPDATE users
        SET verified = TRUE
        WHERE role = 'admin'
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

  let create_sessions_table =
    Caqti_type.(unit ->. unit)
      {|
        CREATE TABLE IF NOT EXISTS sessions (
          id SERIAL PRIMARY KEY,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          access_token TEXT UNIQUE NOT NULL,
          refresh_token TEXT UNIQUE NOT NULL,
          access_expires_at DOUBLE PRECISION NOT NULL,
          refresh_expires_at DOUBLE PRECISION NOT NULL,
          revoked_at DOUBLE PRECISION NULL,
          created_at DOUBLE PRECISION NOT NULL
        )
      |}

  let create_email_verifications_table =
    Caqti_type.(unit ->. unit)
      {|
        CREATE TABLE IF NOT EXISTS email_verifications (
          id SERIAL PRIMARY KEY,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          token TEXT UNIQUE NOT NULL,
          expires_at DOUBLE PRECISION NOT NULL,
          consumed_at DOUBLE PRECISION NULL,
          created_at DOUBLE PRECISION NOT NULL
        )
      |}

  let user_json =
    {|
      json_build_object(
        'id', id,
        'username', username,
        'email', email,
        'password_hash', password_hash,
        'role', role,
        'verified', verified,
        'is_banned', is_banned,
        'ban_reason', ban_reason,
        'created_at', created_at,
        'updated_at', updated_at
      )::text
    |}

  let public_user_json =
    {|
      json_build_object(
        'id', id,
        'username', username,
        'email', email,
        'role', role,
        'verified', verified,
        'is_banned', is_banned,
        'ban_reason', ban_reason,
        'created_at', created_at,
        'updated_at', updated_at
      )
    |}

  let email_verification_json =
    {|
      json_build_object(
        'id', id,
        'user_id', user_id,
        'token', token,
        'expires_at', expires_at,
        'consumed_at', consumed_at,
        'created_at', created_at
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
        VALUES (?, ?, ?, ?, FALSE, ?, ?)
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
          role = ?,
          verified = CASE WHEN ? = 'admin' THEN TRUE ELSE verified END,
          updated_at = ?
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
          updated_at = ?
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
          updated_at = ?
        WHERE id = ?
        RETURNING
      |}
      ^ user_json)

  let create_session =
    Caqti_type.(tup4 int string string (tup3 float float float) ->! string)
      {|
        INSERT INTO sessions (
          user_id,
          access_token,
          refresh_token,
          access_expires_at,
          refresh_expires_at,
          created_at
        )
        VALUES (?, ?, ?, ?, ?, ?)
        RETURNING json_build_object(
          'id', id,
          'user_id', user_id,
          'access_token', access_token,
          'refresh_token', refresh_token,
          'access_expires_at', access_expires_at,
          'refresh_expires_at', refresh_expires_at,
          'revoked_at', revoked_at,
          'created_at', created_at
        )::text
      |}

  let find_session_by_access_token =
    Caqti_type.(string ->? string)
      {|
        SELECT json_build_object(
          'id', id,
          'user_id', user_id,
          'access_token', access_token,
          'refresh_token', refresh_token,
          'access_expires_at', access_expires_at,
          'refresh_expires_at', refresh_expires_at,
          'revoked_at', revoked_at,
          'created_at', created_at
        )::text
        FROM sessions
        WHERE access_token = ?
      |}

  let find_session_by_refresh_token =
    Caqti_type.(string ->? string)
      {|
        SELECT json_build_object(
          'id', id,
          'user_id', user_id,
          'access_token', access_token,
          'refresh_token', refresh_token,
          'access_expires_at', access_expires_at,
          'refresh_expires_at', refresh_expires_at,
          'revoked_at', revoked_at,
          'created_at', created_at
        )::text
        FROM sessions
        WHERE refresh_token = ?
      |}

  let revoke_session =
    Caqti_type.(tup2 float int ->. unit)
      {|
        UPDATE sessions
        SET revoked_at = ?
        WHERE id = ?
      |}

  let revoke_user_sessions =
    Caqti_type.(tup2 float int ->. unit)
      {|
        UPDATE sessions
        SET revoked_at = ?
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
        VALUES (?, ?, ?, ?)
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
        SET consumed_at = ?
        WHERE id = ?
      |}
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
  else if contains "duplicate key" message || contains "23505" message then
    Repository.Conflict "Unique field already exists"
  else
    Repository.Storage message

let map_caqti_error error = classify_error (Caqti_error.show error)

let parse_role value =
  match Domain.role_of_string value with
  | Some role -> Ok role
  | None -> Error (Repository.Storage ("Unknown role: " ^ value))

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
    let** () = run_exec Q.create_users_table () in
    let** () = run_exec Q.add_users_email_column () in
    let** () = run_exec Q.backfill_users_email () in
    let** () = run_exec Q.set_users_email_not_null () in
    let** () = run_exec Q.create_users_email_index () in
    let** () = run_exec Q.drop_users_password_salt_column () in
    let** () = run_exec Q.add_users_verified_column () in
    let** () = run_exec Q.backfill_users_verified () in
    let** () = run_exec Q.verify_admin_users () in
    let** () = run_exec Q.set_users_verified_default () in
    let** () = run_exec Q.set_users_verified_not_null () in
    let** () = run_exec Q.create_sessions_table () in
    run_exec Q.create_email_verifications_table ()
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
          (Domain.role_to_string role, created_at, created_at) )
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
    let role_name = Domain.role_to_string role in
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
    let* result =
      Db.find_opt Q.mark_user_verified (updated_at, user_id)
    in
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
      Db.find Q.create_email_verification
        (user_id, token, expires_at, created_at)
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
  }
