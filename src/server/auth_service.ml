let ( let* ) = Lwt.bind

type deps = {
  repo : Repository.t;
  clock : Clock.t;
  config : Config.t;
  mailer : Verification_mailer.t;
}

type auth_response = {
  user : Domain.public_user;
  tokens : Domain.auth_tokens;
}

type session_context = {
  user : Domain.user;
  session : Domain.session;
}

let ok value = Lwt.return (Ok value)

let error value = Lwt.return (Error value)

let map_repo_error = function
  | Repository.Conflict message -> App_error.Conflict message
  | Repository.Not_found message -> App_error.Not_found message
  | Repository.Storage message -> App_error.Internal message

let validate_username username =
  let length = String.length username in
  let valid_char = function
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '-' -> true
    | _ -> false
  in
  let valid_start = function
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true
    | _ -> false
  in
  if
    length >= 3
    && length <= 32
    && valid_start username.[0]
    && String.for_all valid_char username
  then
    Ok ()
  else
    Error
      (App_error.Bad_request
         "Username must have 3-32 chars and contain letters, digits, _ or -")

let normalize_email email = email |> String.trim |> String.lowercase_ascii

let validate_email email =
  let email = normalize_email email in
  match Util.split_once ~on:'@' email with
  | Some (local, domain)
    when local <> ""
         && domain <> ""
         && not (String.contains email ' ')
         && String.contains domain '.' ->
      Ok email
  | _ -> Error (App_error.Bad_request "Email must be a valid email address")

let validate_password password =
  if String.length password < 8 then
    Error (App_error.Bad_request "Password must be at least 8 characters long")
  else
    Ok ()

let create_tokens config now =
  {
    Domain.access_token = Token.generate ~bytes:32 ();
    refresh_token = Token.generate ~bytes:48 ();
    access_expires_at = now +. config.Config.access_token_ttl_seconds;
    refresh_expires_at = now +. config.Config.refresh_token_ttl_seconds;
  }

let wrap_auth_response (user : Domain.user) tokens =
  { user = Domain.public_user_of_user user; tokens }

let create_session deps (user : Domain.user) =
  let now = deps.clock.now () in
  let tokens = create_tokens deps.config now in
  let* created =
    deps.repo.create_session ~user_id:user.Domain.id
      ~access_token:tokens.Domain.access_token
      ~refresh_token:tokens.Domain.refresh_token
      ~access_expires_at:tokens.Domain.access_expires_at
      ~refresh_expires_at:tokens.Domain.refresh_expires_at ~created_at:now
  in
  match created with
  | Ok _session -> ok (wrap_auth_response user tokens)
  | Error repo_error -> error (map_repo_error repo_error)

let verification_url config token =
  config.Config.public_web_base_url ^ "/verify?token=" ^ Uri.pct_encode token

let issue_verification_email deps (user : Domain.user) =
  let now = deps.clock.now () in
  let token = Token.generate ~bytes:32 () in
  let expires_at = now +. deps.config.verification_token_ttl_seconds in
  let* created =
    deps.repo.create_email_verification ~user_id:user.Domain.id ~token
      ~expires_at ~created_at:now
  in
  match created with
  | Error repo_error -> error (map_repo_error repo_error)
  | Ok _verification -> (
      let* sent =
        deps.mailer.send_verification_email ~to_email:user.Domain.email
          ~username:user.Domain.username
          ~verification_url:(verification_url deps.config token)
      in
      match sent with
      | Ok () -> ok ()
      | Error message ->
          prerr_endline ("Verification email delivery failed: " ^ message);
          ok ())

let register deps ~username ~email ~password =
  match
    ( validate_username username,
      validate_email email,
      validate_password password )
  with
  | Error app_error, _, _
  | _, Error app_error, _
  | _, _, Error app_error ->
      error app_error
  | Ok (), Ok normalized_email, Ok () ->
      let* existing_user = deps.repo.find_user_by_username username in
      begin
        match existing_user with
        | Error repo_error -> error (map_repo_error repo_error)
        | Ok (Some _) -> error (App_error.Conflict "Username already exists")
        | Ok None ->
            let* existing_email =
              deps.repo.find_user_by_email normalized_email
            in
            begin
              match existing_email with
              | Error repo_error -> error (map_repo_error repo_error)
              | Ok (Some _) -> error (App_error.Conflict "Email already exists")
              | Ok None ->
                  let password_hash = Password.make password in
                  let* created =
                    deps.repo.create_user ~username ~email:normalized_email
                      ~password_hash ~role:Domain.User
                      ~created_at:(deps.clock.now ())
                  in
                  match created with
                  | Error repo_error -> error (map_repo_error repo_error)
                  | Ok user -> (
                      let* verification_result =
                        issue_verification_email deps user
                      in
                      match verification_result with
                      | Error app_error -> error app_error
                      | Ok () -> create_session deps user)
            end
      end

let login deps ~username ~password =
  let* found = deps.repo.find_user_by_username username in
  match found with
  | Error repo_error -> error (map_repo_error repo_error)
  | Ok None -> error (App_error.Unauthorized "Invalid username or password")
  | Ok (Some user) ->
      if user.Domain.is_banned then
        error
          (App_error.Forbidden
             (match user.Domain.ban_reason with
             | Some reason -> "User is banned: " ^ reason
             | None -> "User is banned"))
      else if Password.verify ~expected:user.Domain.password_hash password then
        create_session deps user
      else
        error (App_error.Unauthorized "Invalid username or password")

let authenticate_access_token deps access_token =
  let now = deps.clock.now () in
  let* found = deps.repo.find_session_by_access_token access_token in
  match found with
  | Error repo_error -> error (map_repo_error repo_error)
  | Ok None -> error (App_error.Unauthorized "Invalid access token")
  | Ok (Some session) ->
      if session.Domain.revoked_at <> None || session.Domain.access_expires_at <= now then
        error (App_error.Unauthorized "Access token expired or revoked")
      else
        let* user_result = deps.repo.find_user_by_id session.Domain.user_id in
        match user_result with
        | Error repo_error -> error (map_repo_error repo_error)
        | Ok None -> error (App_error.Unauthorized "Unknown user")
        | Ok (Some user) ->
            if user.Domain.is_banned then
              error
                (App_error.Forbidden
                   (match user.Domain.ban_reason with
                   | Some reason -> "User is banned: " ^ reason
                   | None -> "User is banned"))
            else
              ok { user; session }

let refresh deps ~refresh_token =
  let now = deps.clock.now () in
  let* found = deps.repo.find_session_by_refresh_token refresh_token in
  match found with
  | Error repo_error -> error (map_repo_error repo_error)
  | Ok None -> error (App_error.Unauthorized "Invalid refresh token")
  | Ok (Some session) ->
      if session.Domain.revoked_at <> None || session.Domain.refresh_expires_at <= now then
        error (App_error.Unauthorized "Refresh token expired or revoked")
      else
        let* user_result = deps.repo.find_user_by_id session.Domain.user_id in
        match user_result with
        | Error repo_error -> error (map_repo_error repo_error)
        | Ok None -> error (App_error.Unauthorized "Unknown user")
        | Ok (Some user) when user.Domain.is_banned ->
            error
              (App_error.Forbidden
                 (match user.Domain.ban_reason with
                 | Some reason -> "User is banned: " ^ reason
                 | None -> "User is banned"))
        | Ok (Some user) ->
            let* revoked =
              deps.repo.revoke_session ~session_id:session.Domain.id
                ~revoked_at:now
            in
            match revoked with
            | Error repo_error -> error (map_repo_error repo_error)
            | Ok () -> create_session deps user

let logout deps ~access_token =
  let now = deps.clock.now () in
  let* context_result = authenticate_access_token deps access_token in
  match context_result with
  | Error app_error -> error app_error
  | Ok context -> (
      let* revoked =
        deps.repo.revoke_session ~session_id:context.session.Domain.id
          ~revoked_at:now
      in
      match revoked with
      | Ok () -> ok ()
      | Error repo_error -> error (map_repo_error repo_error))

let current_user deps ~access_token =
  let* context_result = authenticate_access_token deps access_token in
  match context_result with
  | Error app_error -> error app_error
  | Ok context -> ok (Domain.public_user_of_user context.user)

let delete_current_user deps ~access_token =
  let* context_result = authenticate_access_token deps access_token in
  match context_result with
  | Error app_error -> error app_error
  | Ok context ->
      let* deleted = deps.repo.delete_user ~user_id:context.user.id in
      match deleted with
      | Error repo_error -> error (map_repo_error repo_error)
      | Ok None -> error (App_error.Not_found "User not found")
      | Ok (Some user) -> ok (Domain.public_user_of_user user)

let verify_email deps ~token =
  let now = deps.clock.now () in
  let* found = deps.repo.find_email_verification_by_token token in
  match found with
  | Error repo_error -> error (map_repo_error repo_error)
  | Ok None -> error (App_error.Bad_request "Invalid verification token")
  | Ok (Some verification) ->
      if verification.Domain.consumed_at <> None then
        error (App_error.Bad_request "Verification token has already been used")
      else if verification.Domain.expires_at <= now then
        error (App_error.Bad_request "Verification token has expired")
      else
        let* user_result = deps.repo.find_user_by_id verification.Domain.user_id in
        match user_result with
        | Error repo_error -> error (map_repo_error repo_error)
        | Ok None -> error (App_error.Not_found "User not found")
        | Ok (Some user) ->
            let* verified_result =
              if user.Domain.verified then
                ok user
              else
                let* updated =
                  deps.repo.mark_user_verified ~user_id:user.Domain.id
                    ~updated_at:now
                in
                match updated with
                | Error repo_error -> error (map_repo_error repo_error)
                | Ok None -> error (App_error.Not_found "User not found")
                | Ok (Some updated_user) -> ok updated_user
            in
            begin
              match verified_result with
              | Error _ as app_error -> Lwt.return app_error
              | Ok verified_user ->
                  let* consumed =
                    deps.repo.consume_email_verification
                      ~verification_id:verification.Domain.id
                      ~consumed_at:now
                  in
                  match consumed with
                  | Error repo_error -> error (map_repo_error repo_error)
                  | Ok () -> ok (Domain.public_user_of_user verified_user)
            end

let ensure_admin deps ~access_token =
  let* context_result = authenticate_access_token deps access_token in
  match context_result with
  | Error app_error -> error app_error
  | Ok context when context.user.Domain.role <> Domain.Admin ->
      error (App_error.Forbidden "Admin privileges required")
  | Ok context -> ok context

let list_users deps ~access_token =
  let* admin_result = ensure_admin deps ~access_token in
  match admin_result with
  | Error app_error -> error app_error
  | Ok _context -> (
      let* listed = deps.repo.list_users () in
      match listed with
      | Ok users -> ok users
      | Error repo_error -> error (map_repo_error repo_error))

let set_ban deps ~access_token ~user_id ~is_banned ~ban_reason =
  let* admin_result = ensure_admin deps ~access_token in
  match admin_result with
  | Error app_error -> error app_error
  | Ok admin_context ->
      if admin_context.user.Domain.id = user_id then
        error (App_error.Forbidden "Admin cannot ban their own account")
      else
        let* updated =
          deps.repo.update_ban ~user_id ~is_banned ~ban_reason
            ~updated_at:(deps.clock.now ())
        in
        match updated with
        | Error repo_error -> error (map_repo_error repo_error)
        | Ok None -> error (App_error.Not_found "User not found")
        | Ok (Some user) ->
            let* revoked =
              if is_banned then
                deps.repo.revoke_user_sessions ~user_id:user.Domain.id
                  ~revoked_at:(deps.clock.now ())
              else
                Lwt.return (Ok ())
            in
            match revoked with
            | Ok () -> ok (Domain.public_user_of_user user)
            | Error repo_error -> error (map_repo_error repo_error)
