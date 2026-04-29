type state = {
  mutable next_user_id : int;
  mutable next_session_id : int;
  mutable next_verification_id : int;
  users : (int, Domain.user) Hashtbl.t;
  usernames : (string, int) Hashtbl.t;
  emails : (string, int) Hashtbl.t;
  sessions : (int, Domain.session) Hashtbl.t;
  access_index : (string, int) Hashtbl.t;
  refresh_index : (string, int) Hashtbl.t;
  verifications : (int, Domain.email_verification) Hashtbl.t;
  verification_tokens : (string, int) Hashtbl.t;
}

let create_state () =
  {
    next_user_id = 1;
    next_session_id = 1;
    next_verification_id = 1;
    users = Hashtbl.create 16;
    usernames = Hashtbl.create 16;
    emails = Hashtbl.create 16;
    sessions = Hashtbl.create 32;
    access_index = Hashtbl.create 32;
    refresh_index = Hashtbl.create 32;
    verifications = Hashtbl.create 32;
    verification_tokens = Hashtbl.create 32;
  }

let make () =
  let state = create_state () in
  let user_by_id id = Hashtbl.find_opt state.users id in
  let session_by_id id = Hashtbl.find_opt state.sessions id in
  let verification_by_id id = Hashtbl.find_opt state.verifications id in
  let create_user ~username ~email ~password_hash ~role ~created_at =
    if Hashtbl.mem state.usernames username then
      Lwt.return (Error (Repository.Conflict "Username already exists"))
    else if Hashtbl.mem state.emails email then
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
  in
  let find_user_by_username username =
    match Hashtbl.find_opt state.usernames username with
    | None -> Lwt.return (Ok None)
    | Some user_id -> Lwt.return (Ok (user_by_id user_id))
  in
  let find_user_by_email email =
    match Hashtbl.find_opt state.emails email with
    | None -> Lwt.return (Ok None)
    | Some user_id -> Lwt.return (Ok (user_by_id user_id))
  in
  let find_user_by_id user_id = Lwt.return (Ok (user_by_id user_id)) in
  let list_users () =
    let user_rows : Domain.user list =
      Hashtbl.to_seq_values state.users |> List.of_seq
    in
    let sorted_rows =
      List.sort
        (fun (left : Domain.user) (right : Domain.user) ->
          Int.compare left.Domain.id right.Domain.id)
        user_rows
    in
    let users : Domain.public_user list =
      List.map
        (fun (user : Domain.user) -> Domain.public_user_of_user user)
        sorted_rows
    in
    Lwt.return (Ok users)
  in
  let update_role ~user_id ~role ~updated_at =
    match user_by_id user_id with
    | None -> Lwt.return (Ok None)
    | Some user ->
        let next_user =
          { user with role; verified = user.verified || role = Domain.Admin; updated_at }
        in
        Hashtbl.replace state.users user_id next_user;
        Lwt.return (Ok (Some next_user))
  in
  let update_ban ~user_id ~is_banned ~ban_reason ~updated_at =
    match user_by_id user_id with
    | None -> Lwt.return (Ok None)
    | Some user ->
        let next_user = { user with is_banned; ban_reason; updated_at } in
        Hashtbl.replace state.users user_id next_user;
        Lwt.return (Ok (Some next_user))
  in
  let create_session ~user_id ~access_token ~refresh_token ~access_expires_at
      ~refresh_expires_at ~created_at =
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
  in
  let find_session_by_access_token access_token =
    match Hashtbl.find_opt state.access_index access_token with
    | None -> Lwt.return (Ok None)
    | Some session_id -> Lwt.return (Ok (session_by_id session_id))
  in
  let find_session_by_refresh_token refresh_token =
    match Hashtbl.find_opt state.refresh_index refresh_token with
    | None -> Lwt.return (Ok None)
    | Some session_id -> Lwt.return (Ok (session_by_id session_id))
  in
  let revoke_session ~session_id ~revoked_at =
    match session_by_id session_id with
    | None -> Lwt.return (Ok ())
    | Some session ->
        Hashtbl.replace state.sessions session_id
          { session with Domain.revoked_at = Some revoked_at };
        Lwt.return (Ok ())
  in
  let revoke_user_sessions ~user_id ~revoked_at =
    Hashtbl.iter
      (fun session_id (session : Domain.session) ->
        if session.Domain.user_id = user_id && session.Domain.revoked_at = None then
          Hashtbl.replace state.sessions session_id
            { session with Domain.revoked_at = Some revoked_at })
      state.sessions;
    Lwt.return (Ok ())
  in
  let create_email_verification ~user_id ~token ~expires_at ~created_at =
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
    Hashtbl.replace state.verifications verification.Domain.id verification;
    Hashtbl.replace state.verification_tokens token verification.Domain.id;
    Lwt.return (Ok verification)
  in
  let find_email_verification_by_token token =
    match Hashtbl.find_opt state.verification_tokens token with
    | None -> Lwt.return (Ok None)
    | Some verification_id ->
        Lwt.return (Ok (verification_by_id verification_id))
  in
  let consume_email_verification ~verification_id ~consumed_at =
    match verification_by_id verification_id with
    | None -> Lwt.return (Ok ())
    | Some verification ->
        Hashtbl.replace state.verifications verification_id
          { verification with Domain.consumed_at = Some consumed_at };
        Lwt.return (Ok ())
  in
  let mark_user_verified ~user_id ~updated_at =
    match user_by_id user_id with
    | None -> Lwt.return (Ok None)
    | Some user ->
        let next_user = { user with verified = true; updated_at } in
        Hashtbl.replace state.users user_id next_user;
        Lwt.return (Ok (Some next_user))
  in
  {
    Repository.init_schema = (fun () -> Lwt.return (Ok ()));
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
