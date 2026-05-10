let ( let* ) = Lwt.bind

open Toolkit

type synthetic_user = {
  actor : Loadtest_api.actor;
  mutable session : Loadtest_api.session option;
}

type state = {
  client : Loadtest_api.client;
  seed : int;
  report_every : int;
  rate : float ref;
  running : bool ref;
  stop_requested : bool ref;
  next_index : int ref;
  users : synthetic_user list ref;
  ops_count : int ref;
}

let has_prefix ~prefix value =
  let prefix_len = String.length prefix in
  String.length value >= prefix_len
  && String.sub value 0 prefix_len = prefix

let sample_exponential ~rate =
  if rate <= 0.0 then
    0.5
  else
    let u = max 1e-9 (1.0 -. Random.float 1.0) in
    -.log u /. rate

let pick_random list =
  match list with
  | [] -> None
  | _ -> Some (List.nth list (Random.int (List.length list)))

let active_session_count state =
  List.fold_left
    (fun count user -> match user.session with Some _ -> count + 1 | None -> count)
    0 !(state.users)

let status_line state =
  Printf.sprintf "ok state %s rate %.3f users %d sessions %d ops %d next_index %d"
    (if !(state.running) then "running" else "paused")
    !(state.rate) (List.length !(state.users))
    (active_session_count state) !(state.ops_count) !(state.next_index)

let register_user state index =
  let identity = Mock_identity.make ~seed:state.seed ~index in
  let* result = Loadtest_api.register state.client identity in
  match result with
  | Ok session ->
      Lwt.return
        (Ok
           {
             actor = session.actor;
             session = Some session;
           })
  | Error message -> Lwt.return (Error message)

let login_user state user =
  let* result = Loadtest_api.login state.client user.actor in
  match result with
  | Ok session ->
      user.session <- Some session;
      Lwt.return (Ok session)
  | Error _ as error -> Lwt.return error

let ensure_session state user =
  match user.session with
  | Some session -> Lwt.return (Ok session)
  | None -> login_user state user

let is_auth_error message =
  has_prefix ~prefix:"HTTP 401" message || has_prefix ~prefix:"HTTP 403" message

let with_session_retry state user fn =
  let* session_result = ensure_session state user in
  match session_result with
  | Error _ as error -> Lwt.return error
  | Ok session -> (
      let* result = fn session in
      match result with
      | Ok _ as ok -> Lwt.return ok
      | Error message when is_auth_error message ->
          user.session <- None;
          let* retry_session_result = ensure_session state user in
          begin
            match retry_session_result with
            | Error _ as error -> Lwt.return error
            | Ok retry_session -> fn retry_session
          end
      | Error _ as error -> Lwt.return error)

let list_tasks_for_user state user =
  Loadtest_api.list_tasks state.client ~client_id:user.actor.client_id ()

let perform_list_tasks state user =
  let* result = list_tasks_for_user state user in
  match result with
  | Ok _ -> Lwt.return (Ok "list_tasks")
  | Error _ as error -> Lwt.return error

let perform_view_task state user =
  let* tasks_result = list_tasks_for_user state user in
  match tasks_result with
  | Error _ as error -> Lwt.return error
  | Ok [] -> Lwt.return (Ok "view_task_skipped_no_tasks")
  | Ok tasks -> (
      match pick_random tasks with
      | None -> Lwt.return (Ok "view_task_skipped_no_tasks")
      | Some task ->
          let* result =
            Loadtest_api.get_task_by_slug state.client
              ~client_id:user.actor.client_id task.slug
          in
          match result with
          | Ok _ -> Lwt.return (Ok "view_task")
          | Error _ as error -> Lwt.return error)

let perform_submit state user =
  let* tasks_result = list_tasks_for_user state user in
  match tasks_result with
  | Error _ as error -> Lwt.return error
  | Ok [] -> Lwt.return (Ok "submit_skipped_no_tasks")
  | Ok tasks -> (
      match pick_random tasks with
      | None -> Lwt.return (Ok "submit_skipped_no_tasks")
      | Some task ->
          let* result =
            with_session_retry state user (fun session ->
                Loadtest_api.submit state.client session ~task_id:task.id
                  ~data:(`Assoc []))
          in
          match result with
          | Ok _ -> Lwt.return (Ok "submit")
          | Error _ as error -> Lwt.return error)

let perform_list_submissions state user =
  let* result =
    with_session_retry state user (fun session ->
        Loadtest_api.list_submissions state.client session ~scope:`Mine)
  in
  match result with
  | Ok _ -> Lwt.return (Ok "list_submissions")
  | Error _ as error -> Lwt.return error

let perform_logout state user =
  match user.session with
  | None -> Lwt.return (Ok "logout_skipped")
  | Some session ->
      let* result = Loadtest_api.logout state.client session in
      begin
        match result with
        | Ok () ->
            user.session <- None;
            Lwt.return (Ok "logout")
        | Error message when is_auth_error message ->
            user.session <- None;
            Lwt.return (Ok "logout_expired")
        | Error _ as error -> Lwt.return error
      end

let run_once state =
  match pick_random !(state.users) with
  | None -> Lwt.return "idle_no_users"
  | Some user ->
      let operation = Random.int 100 in
      let* result =
        if operation < 45 then
          perform_list_tasks state user
        else if operation < 70 then
          perform_view_task state user
        else if operation < 85 then
          perform_submit state user
        else if operation < 95 then
          perform_list_submissions state user
        else
          perform_logout state user
      in
      match result with
      | Ok label -> Lwt.return label
      | Error message ->
          prerr_endline ("trafficd operation failed: " ^ message);
          Lwt.return "error"

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
        | Error message when has_prefix ~prefix:"HTTP 409" message ->
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

let delete_user state user =
  let* result =
    with_session_retry state user (fun session ->
        Loadtest_api.delete_current_user state.client session)
  in
  match result with
  | Ok () -> Lwt.return true
  | Error message ->
      prerr_endline
        (Printf.sprintf "trafficd remove-user failed for %s: %s"
           user.actor.username message);
      Lwt.return false

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
          let* deleted = delete_user state user in
          if deleted then
            loop (removed + 1) kept tail
          else
            loop removed (user :: kept) tail
    in
    let* removed = loop 0 [] selected in
    Lwt.return
      (Printf.sprintf "ok removed_users %d total_users %d" removed
         (List.length !(state.users)))

let handle_command state command =
  let parts =
    String.split_on_char ' ' (String.trim command)
    |> List.filter (fun part -> part <> "")
  in
  match parts with
  | [] -> Lwt.return "error empty command"
  | [ "status" ] -> Lwt.return (status_line state)
  | [ "get-rate" ] | [ "rate" ] ->
      Lwt.return (Printf.sprintf "ok rate %.3f" !(state.rate))
  | [ "set-rate"; value ] | [ "rate"; value ] -> (
      match float_of_string_opt value with
      | None -> Lwt.return "error rate must be a float"
      | Some parsed when parsed < 0.0 ->
          Lwt.return "error rate must be non-negative"
      | Some parsed ->
          state.rate := parsed;
          Lwt.return (Printf.sprintf "ok rate %.3f" parsed))
  | [ "start" ] ->
      state.running := true;
      Lwt.return (status_line state)
  | [ "pause" ] ->
      state.running := false;
      Lwt.return (status_line state)
  | [ "add-users"; value ] -> (
      match int_of_string_opt value with
      | None -> Lwt.return "error add-users count must be an integer"
      | Some count -> add_users state count)
  | [ "remove-users"; value ] -> (
      match int_of_string_opt value with
      | None -> Lwt.return "error remove-users count must be an integer"
      | Some count -> remove_users state count)
  | [ "stop" ] ->
      state.stop_requested := true;
      Lwt.return "ok stopping"
  | _ -> Lwt.return "error unknown command"

let run ~base_url ~seed ~rate ~report_every ~control_socket =
  let state =
    {
      client = Loadtest_api.make ~base_url;
      seed;
      report_every;
      rate = ref rate;
      running = ref false;
      stop_requested = ref false;
      next_index = ref 1;
      users = ref [];
      ops_count = ref 0;
    }
  in
  Printf.printf
    "trafficd base_url=%s control_socket=%s initial_rate=%.3f state=paused\n%!"
    base_url control_socket rate;
  Lwt.async (fun () ->
      Traffic_control.serve ~socket_path:control_socket
        ~should_stop:(fun () -> !(state.stop_requested))
        ~handle_command:(handle_command state));
  let rec loop () =
    if !(state.stop_requested) then
      Lwt.return_unit
    else if (not !(state.running)) || !(state.users) = [] || !(state.rate) <= 0.0 then
      let* () = Lwt_unix.sleep 0.5 in
      loop ()
    else
      let* () = Lwt_unix.sleep (sample_exponential ~rate:!(state.rate)) in
      let* operation = run_once state in
      state.ops_count := !(state.ops_count) + 1;
      if state.report_every > 0 && !(state.ops_count) mod state.report_every = 0 then
        Printf.printf "trafficd %s last=%s\n%!" (status_line state) operation;
      loop ()
  in
  loop ()

let base_url_arg =
  Cmdliner.Arg.(
    value & opt string "http://127.0.0.1:8080"
    & info [ "base-url" ] ~docv:"URL"
      ~doc:"Base URL of the Recognita API.")

let seed_arg =
  Cmdliner.Arg.(
    value & opt int 20260508 & info [ "seed" ] ~docv:"SEED"
      ~doc:"Initial seed used by Faker for deterministic test identities.")

let rate_arg =
  Cmdliner.Arg.(
    value & opt float 3.0 & info [ "rate" ] ~docv:"REQ_PER_SEC"
      ~doc:"Average request rate used after traffic is started.")

let report_every_arg =
  Cmdliner.Arg.(
    value & opt int 100 & info [ "report-every" ] ~docv:"N"
      ~doc:"Print a short progress line every N operations.")

let control_socket_arg =
  Cmdliner.Arg.(
    value & opt string "/tmp/trafficd.sock"
    & info [ "control-socket" ] ~docv:"PATH"
      ~doc:"Unix socket used to control trafficd while it is running.")

let cmd =
  let doc = "Stateful OCaml daemon for synthetic API traffic." in
  let term =
    Cmdliner.Term.(
      const
        (fun base_url seed rate report_every control_socket ->
          Random.self_init ();
          Lwt_main.run
            (run ~base_url ~seed ~rate ~report_every ~control_socket))
      $ base_url_arg $ seed_arg $ rate_arg $ report_every_arg
      $ control_socket_arg)
  in
  Cmdliner.Cmd.v (Cmdliner.Cmd.info "trafficd" ~doc) term

let () = exit (Cmdliner.Cmd.eval cmd)
