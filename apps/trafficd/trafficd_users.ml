let ( let* ) = Lwt.bind

open Toolkit
open Trafficd_types

let register_user state index =
  let identity = Mock_identity.make ~seed:state.seed ~index in
  let* result = Loadtest_api.register state.client identity in
  match result with
  | Error _ as error -> Lwt.return error
  | Ok session ->
      Lwt.return
        (Ok
           {
             actor = session.actor;
             session = Some session;
           })

let login_user state user =
  let* result = Loadtest_api.login state.client user.actor in
  match result with
  | Ok session ->
      user.session <- Some session;
      Lwt.return (Ok session)
  | Error _ as error -> Lwt.return error

let logout_user state user =
  match user.session with
  | None -> Lwt.return (Ok ())
  | Some session ->
      let* result = Loadtest_api.logout state.client session in
      begin
        match result with
        | Ok () ->
            user.session <- None;
            Lwt.return (Ok ())
        | Error message when Trafficd_helpers.is_auth_error message ->
            user.session <- None;
            Lwt.return (Ok ())
        | Error _ as error -> Lwt.return error
      end

let ensure_live_session state user =
  match user.session with
  | Some session -> Lwt.return (Ok session)
  | None -> login_user state user

let ensure_admin_session state =
  match !(state.admin_session), state.admin_username, state.admin_password with
  | Some session, _, _ -> Lwt.return (Ok session)
  | None, Some username, Some password ->
      let* result =
        Loadtest_api.login_with_credentials state.client ~username ~password
          ~client_id:state.admin_client_id
      in
      begin
        match result with
        | Ok session ->
            state.admin_session := Some session;
            Lwt.return (Ok session)
        | Error _ as error -> Lwt.return error
      end
  | None, _, _ ->
      Lwt.return
        (Error
           "trafficd add-tasks requires --admin-username and --admin-password")

let delete_user state user =
  let* session_result = ensure_live_session state user in
  match session_result with
  | Error message when Trafficd_helpers.has_prefix ~prefix:"HTTP 401" message ->
      Lwt.return (Ok true)
  | Error message -> Lwt.return (Error message)
  | Ok session -> (
      let* result = Loadtest_api.delete_current_user state.client session in
      match result with
      | Ok () -> Lwt.return (Ok true)
      | Error message
        when Trafficd_helpers.is_auth_error message
             || Trafficd_helpers.has_prefix ~prefix:"HTTP 404" message ->
          Lwt.return (Ok true)
      | Error _ as error -> Lwt.return error)

let add_users state requested_count =
  if requested_count < 0 then
    Lwt.return "error add-users count must be non-negative"
  else
    let rec loop added attempts_left =
      if added = requested_count || attempts_left <= 0 then
        Lwt.return added
      else
        let index = !(state.next_index) in
        state.next_index := index + 1;
        let* result = register_user state index in
        match result with
        | Ok user ->
            state.users := user :: !(state.users);
            loop (added + 1) (attempts_left - 1)
        | Error message
          when Trafficd_helpers.has_prefix ~prefix:"HTTP 409" message ->
            loop added (attempts_left - 1)
        | Error message ->
            prerr_endline
              (Printf.sprintf "trafficd add-users failed at index=%d: %s" index
                 message);
            loop added (attempts_left - 1)
    in
    let attempts = max (requested_count * 20) 100 in
    let* added = loop 0 attempts in
    Lwt.return
      (Printf.sprintf "ok added_users %d total_users %d next_index %d" added
         (List.length !(state.users)) !(state.next_index))

let remove_users state requested_count =
  if requested_count < 0 then
    Lwt.return "error remove-users count must be non-negative"
  else
    let rec take n list taken =
      if n <= 0 then
        (List.rev taken, list)
      else
        match list with
        | [] -> (List.rev taken, [])
        | head :: tail -> take (n - 1) tail (head :: taken)
    in
    let selected, remaining = take requested_count !(state.users) [] in
    let rec loop removed kept = function
      | [] ->
          state.users := List.rev_append kept remaining;
          Lwt.return removed
      | user :: tail ->
          let* result = delete_user state user in
          begin
            match result with
            | Ok true -> loop (removed + 1) kept tail
            | Ok false -> loop removed (user :: kept) tail
            | Error message ->
                prerr_endline
                  (Printf.sprintf "trafficd remove-user failed for %s: %s"
                     user.actor.username message);
                loop removed (user :: kept) tail
          end
    in
    let* removed = loop 0 [] selected in
    Lwt.return
      (Printf.sprintf "ok removed_users %d total_users %d" removed
         (List.length !(state.users)))

let pick_zipf_user state =
  match !(state.users) with
  | [] -> None
  | users ->
      let indexed = Array.of_list users in
      let total =
        Array.fold_left
          (fun acc index -> acc +. (1.0 /. float_of_int (index + 1)))
          0.0 (Array.init (Array.length indexed) Fun.id)
      in
      let target = Random.float total in
      let rec loop acc index =
        if index >= Array.length indexed then
          None
        else
          let next = acc +. (1.0 /. float_of_int (index + 1)) in
          if target < next then Some indexed.(index) else loop next (index + 1)
      in
      loop 0.0 0

let cleanup_users state =
  state.running := false;
  let existing = !(state.users) in
  let rec loop removed failed = function
    | [] ->
        state.users := [];
        Lwt.return (removed, failed)
    | user :: tail ->
        let* result = delete_user state user in
        begin
          match result with
          | Ok true -> loop (removed + 1) failed tail
          | Ok false -> loop removed (failed + 1) tail
          | Error message ->
              prerr_endline
                (Printf.sprintf "trafficd shutdown cleanup failed for %s: %s"
                   user.actor.username message);
              loop removed (failed + 1) tail
        end
  in
  let* removed, failed = loop 0 0 existing in
  let* () =
    match !(state.admin_session) with
    | None -> Lwt.return_unit
    | Some session ->
        state.admin_session := None;
        let* _ = Loadtest_api.logout state.client session in
        Lwt.return_unit
  in
  state.cached_tasks := [];
  Printf.printf
    "trafficd cleanup removed_users=%d failed=%d remaining=%d\n%!" removed
    failed (List.length !(state.users));
  Lwt.return_unit
