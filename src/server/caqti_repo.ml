[@@@alert "-deprecated"]

let ( let* ) = Lwt.bind

module Q = Caqti_repo_query.Q

open Caqti_repo_codec

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
  let update_bootstrap_admin ~user_id ~email ~password_hash ~updated_at =
    let* result =
      Db.find_opt Q.update_bootstrap_admin
        (String.trim email |> String.lowercase_ascii, password_hash, updated_at, user_id)
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
    update_bootstrap_admin;
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
