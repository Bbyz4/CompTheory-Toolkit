let create_user (state : In_memory_repo_state.state) ~username ~email
    ~password_hash ~role ~created_at =
  if Hashtbl.mem state.In_memory_repo_state.usernames username then
    Lwt.return (Error (Repository.Conflict "Username already exists"))
  else if Hashtbl.mem state.In_memory_repo_state.emails email then
    Lwt.return (Error (Repository.Conflict "Email already exists"))
  else
    let user =
      {
        Domain.id = state.next_user_id;
        username;
        email;
        password_hash;
        role;
        verified = role = Domain.Admin;
        is_banned = false;
        ban_reason = None;
        created_at;
        updated_at = created_at;
      }
    in
    state.next_user_id <- state.next_user_id + 1;
    Hashtbl.replace state.users user.Domain.id user;
    Hashtbl.replace state.usernames username user.Domain.id;
    Hashtbl.replace state.emails email user.Domain.id;
    Lwt.return (Ok user)

let find_user_by_username (state : In_memory_repo_state.state) username =
  match Hashtbl.find_opt state.In_memory_repo_state.usernames username with
  | None -> Lwt.return (Ok None)
  | Some user_id -> Lwt.return (Ok (In_memory_repo_support.user_by_id state user_id))

let find_user_by_email (state : In_memory_repo_state.state) email =
  match Hashtbl.find_opt state.In_memory_repo_state.emails email with
  | None -> Lwt.return (Ok None)
  | Some user_id -> Lwt.return (Ok (In_memory_repo_support.user_by_id state user_id))

let find_user_by_id (state : In_memory_repo_state.state) user_id =
  Lwt.return (Ok (In_memory_repo_support.user_by_id state user_id))

let list_users (state : In_memory_repo_state.state) () =
  Lwt.return (Ok (In_memory_repo_support.sorted_public_users state))

let update_role (state : In_memory_repo_state.state) ~user_id ~role ~updated_at =
  match In_memory_repo_support.user_by_id state user_id with
  | None -> Lwt.return (Ok None)
  | Some user ->
      let next_user =
        {
          user with
          role;
          verified = user.verified || role = Domain.Admin;
          updated_at;
        }
      in
      Hashtbl.replace state.users user_id next_user;
      Lwt.return (Ok (Some next_user))

let update_bootstrap_admin (state : In_memory_repo_state.state) ~user_id ~email
    ~password_hash ~updated_at =
  match In_memory_repo_support.user_by_id state user_id with
  | None -> Lwt.return (Ok None)
  | Some user ->
      let normalized_email = String.trim email |> String.lowercase_ascii in
      if user.email <> normalized_email then (
        Hashtbl.remove state.emails user.email;
        Hashtbl.replace state.emails normalized_email user_id
      );
      let next_user =
        {
          user with
          email = normalized_email;
          password_hash;
          role = Domain.Admin;
          verified = true;
          is_banned = false;
          ban_reason = None;
          updated_at;
        }
      in
      Hashtbl.replace state.users user_id next_user;
      Lwt.return (Ok (Some next_user))

let update_ban (state : In_memory_repo_state.state) ~user_id ~is_banned
    ~ban_reason ~updated_at =
  match In_memory_repo_support.user_by_id state user_id with
  | None -> Lwt.return (Ok None)
  | Some user ->
      let next_user = { user with is_banned; ban_reason; updated_at } in
      Hashtbl.replace state.users user_id next_user;
      Lwt.return (Ok (Some next_user))

let create_session (state : In_memory_repo_state.state) ~user_id ~access_token ~refresh_token
    ~access_expires_at ~refresh_expires_at ~created_at =
  let session =
    {
      Domain.id = state.next_session_id;
      user_id;
      access_token;
      refresh_token;
      access_expires_at;
      refresh_expires_at;
      revoked_at = None;
      created_at;
    }
  in
  state.next_session_id <- state.next_session_id + 1;
  Hashtbl.replace state.sessions session.Domain.id session;
  Hashtbl.replace state.access_index access_token session.Domain.id;
  Hashtbl.replace state.refresh_index refresh_token session.Domain.id;
  Lwt.return (Ok session)

let find_session_by_access_token (state : In_memory_repo_state.state) access_token =
  match Hashtbl.find_opt state.In_memory_repo_state.access_index access_token with
  | None -> Lwt.return (Ok None)
  | Some session_id ->
      Lwt.return (Ok (In_memory_repo_support.session_by_id state session_id))

let find_session_by_refresh_token (state : In_memory_repo_state.state) refresh_token =
  match Hashtbl.find_opt state.In_memory_repo_state.refresh_index refresh_token with
  | None -> Lwt.return (Ok None)
  | Some session_id ->
      Lwt.return (Ok (In_memory_repo_support.session_by_id state session_id))

let revoke_session (state : In_memory_repo_state.state) ~session_id ~revoked_at =
  match In_memory_repo_support.session_by_id state session_id with
  | None -> Lwt.return (Ok ())
  | Some session ->
      Hashtbl.replace state.sessions session_id
        { session with Domain.revoked_at = Some revoked_at };
      Lwt.return (Ok ())

let revoke_user_sessions (state : In_memory_repo_state.state) ~user_id ~revoked_at =
  Hashtbl.iter
    (fun session_id (session : Domain.session) ->
      if session.user_id = user_id && session.revoked_at = None then
        Hashtbl.replace state.sessions session_id
          { session with revoked_at = Some revoked_at })
    state.sessions;
  Lwt.return (Ok ())

let create_email_verification (state : In_memory_repo_state.state) ~user_id ~token
    ~expires_at ~created_at =
  let verification =
    {
      Domain.id = state.next_verification_id;
      user_id;
      token;
      expires_at;
      consumed_at = None;
      created_at;
    }
  in
  state.next_verification_id <- state.next_verification_id + 1;
  Hashtbl.replace state.verifications verification.id verification;
  Hashtbl.replace state.verification_tokens token verification.id;
  Lwt.return (Ok verification)

let find_email_verification_by_token (state : In_memory_repo_state.state) token =
  match Hashtbl.find_opt state.In_memory_repo_state.verification_tokens token with
  | None -> Lwt.return (Ok None)
  | Some verification_id ->
      Lwt.return
        (Ok (In_memory_repo_support.verification_by_id state verification_id))

let consume_email_verification (state : In_memory_repo_state.state) ~verification_id
    ~consumed_at =
  match In_memory_repo_support.verification_by_id state verification_id with
  | None -> Lwt.return (Ok ())
  | Some verification ->
      Hashtbl.replace state.verifications verification_id
        { verification with consumed_at = Some consumed_at };
      Lwt.return (Ok ())

let mark_user_verified (state : In_memory_repo_state.state) ~user_id ~updated_at =
  match In_memory_repo_support.user_by_id state user_id with
  | None -> Lwt.return (Ok None)
  | Some user ->
      let next_user = { user with verified = true; updated_at } in
      Hashtbl.replace state.users user_id next_user;
      Lwt.return (Ok (Some next_user))

let delete_user (state : In_memory_repo_state.state) ~user_id =
  match In_memory_repo_support.user_by_id state user_id with
  | None -> Lwt.return (Ok None)
  | Some user ->
      let owned_task_ids =
        Hashtbl.to_seq_values state.tasks
        |> Seq.filter (fun (task : Domain.task) -> task.author_id = user_id)
        |> Seq.map (fun (task : Domain.task) -> task.id)
        |> List.of_seq
      in
      List.iter
        (fun task_id ->
          match In_memory_repo_support.task_by_id state task_id with
          | None -> ()
          | Some task ->
              Hashtbl.remove state.tasks task_id;
              begin
                match task.slug with
                | Some slug -> Hashtbl.remove state.task_slugs slug
                | None -> ()
              end)
        owned_task_ids;
      Hashtbl.filter_map_inplace
        (fun _id (submission : Domain.submission) ->
          if submission.user_id = user_id || List.mem submission.task_id owned_task_ids then
            None
          else
            Some submission)
        state.submissions;
      Hashtbl.remove state.users user_id;
      Hashtbl.remove state.usernames user.username;
      Hashtbl.remove state.emails user.email;
      Hashtbl.filter_map_inplace
        (fun _id (session : Domain.session) ->
          if session.user_id = user_id then None else Some session)
        state.sessions;
      Hashtbl.filter_map_inplace
        (fun _token session_id ->
          match In_memory_repo_support.session_by_id state session_id with
          | Some _ -> Some session_id
          | None -> None)
        state.access_index;
      Hashtbl.filter_map_inplace
        (fun _token session_id ->
          match In_memory_repo_support.session_by_id state session_id with
          | Some _ -> Some session_id
          | None -> None)
        state.refresh_index;
      Hashtbl.filter_map_inplace
        (fun _id (verification : Domain.email_verification) ->
          if verification.user_id = user_id then None else Some verification)
        state.verifications;
      Hashtbl.filter_map_inplace
        (fun _token verification_id ->
          match In_memory_repo_support.verification_by_id state verification_id with
          | Some _ -> Some verification_id
          | None -> None)
        state.verification_tokens;
      Lwt.return (Ok (Some user))
