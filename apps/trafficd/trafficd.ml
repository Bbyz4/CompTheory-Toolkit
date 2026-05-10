let ( let* ) = Lwt.bind

open Toolkit

type synthetic_user = {
  actor : Loadtest_api.actor;
  mutable session : Loadtest_api.session option;
}

type operation =
  | List_tasks
  | View_task
  | Login
  | Submit

type state = {
  client : Loadtest_api.client;
  seed : int;
  report_every : int;
  admin_username : string option;
  admin_password : string option;
  admin_client_id : string;
  admin_session : Loadtest_api.session option ref;
  running : bool ref;
  stop_requested : bool ref;
  next_index : int ref;
  next_task_index : int ref;
  users : synthetic_user list ref;
  cached_tasks : Loadtest_api.task list ref;
  ops_count : int ref;
  list_tasks_rate : float ref;
  view_task_rate : float ref;
  login_rate : float ref;
  submit_rate : float ref;
}

let all_operations = [ List_tasks; View_task; Login; Submit ]

let operation_name = function
  | List_tasks -> "list_tasks"
  | View_task -> "view_task"
  | Login -> "login"
  | Submit -> "submit"

let operation_of_string = function
  | "list_tasks" | "list-tasks" -> Some List_tasks
  | "view_task" | "view-task" | "open_task" | "open-task" -> Some View_task
  | "login" -> Some Login
  | "submit" -> Some Submit
  | _ -> None

let default_weights =
  [
    (List_tasks, 0.45);
    (View_task, 0.25);
    (Login, 0.15);
    (Submit, 0.15);
  ]

let has_prefix ~prefix value =
  let prefix_len = String.length prefix in
  String.length value >= prefix_len
  && String.sub value 0 prefix_len = prefix

let rate_ref state = function
  | List_tasks -> state.list_tasks_rate
  | View_task -> state.view_task_rate
  | Login -> state.login_rate
  | Submit -> state.submit_rate

let current_rate state operation = !(rate_ref state operation)

let set_rate state operation value = rate_ref state operation := value

let total_rate state =
  List.fold_left
    (fun total operation -> total +. current_rate state operation)
    0.0 all_operations

let rates_summary state =
  all_operations
  |> List.map (fun operation ->
         Printf.sprintf "%s=%.3f" (operation_name operation)
           (current_rate state operation))
  |> String.concat " "

let active_session_count state =
  List.fold_left
    (fun count user -> match user.session with Some _ -> count + 1 | None -> count)
    0 !(state.users)

let status_line state =
  Printf.sprintf
    "ok state %s total_rate %.3f users %d sessions %d cached_tasks %d ops %d \
     next_index %d rates %s"
    (if !(state.running) then "running" else "paused")
    (total_rate state) (List.length !(state.users))
    (active_session_count state) (List.length !(state.cached_tasks))
    !(state.ops_count) !(state.next_index) (rates_summary state)

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

let is_auth_error message =
  has_prefix ~prefix:"HTTP 401" message || has_prefix ~prefix:"HTTP 403" message

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
        | Error message when is_auth_error message ->
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

let ensure_session_for_cleanup state user =
  ensure_live_session state user

let delete_user state user =
  let* session_result = ensure_session_for_cleanup state user in
  match session_result with
  | Error message when has_prefix ~prefix:"HTTP 401" message ->
      Lwt.return (Ok true)
  | Error message -> Lwt.return (Error message)
  | Ok session -> (
      let* result =
        Loadtest_api.delete_current_user state.client session
      in
      match result with
      | Ok () -> Lwt.return (Ok true)
      | Error message
        when is_auth_error message || has_prefix ~prefix:"HTTP 404" message ->
          Lwt.return (Ok true)
      | Error _ as error -> Lwt.return error)

let refresh_cached_tasks state =
  let client_id =
    match !(state.users) with
    | user :: _ -> user.actor.client_id
    | [] -> "trafficd-public"
  in
  let* result = Loadtest_api.list_tasks state.client ~client_id () in
  match result with
  | Ok tasks ->
      state.cached_tasks := tasks;
      Lwt.return (Ok tasks)
  | Error _ as error -> Lwt.return error

let perform_list_tasks state =
  let* result = refresh_cached_tasks state in
  match result with
  | Ok _ -> Lwt.return (Ok "list_tasks")
  | Error _ as error -> Lwt.return error

let perform_view_task state =
  match pick_random !(state.cached_tasks) with
  | None -> Lwt.return (Ok "view_task_skipped_no_tasks")
  | Some task ->
      let client_id =
        match pick_random !(state.users) with
        | Some user -> user.actor.client_id
        | None -> "trafficd-public"
      in
      let* result =
        Loadtest_api.get_task_by_slug state.client ~client_id task.slug
      in
      begin
        match result with
        | Ok _ -> Lwt.return (Ok "view_task")
        | Error message when has_prefix ~prefix:"HTTP 404" message ->
            state.cached_tasks := [];
            Lwt.return (Ok "view_task_stale_cache")
        | Error _ as error -> Lwt.return error
      end

let perform_login state =
  match pick_random !(state.users) with
  | None -> Lwt.return (Ok "login_skipped_no_users")
  | Some user ->
      let* logout_result = logout_user state user in
      begin
        match logout_result with
        | Error _ as error -> Lwt.return error
        | Ok () ->
            let* login_result = login_user state user in
            match login_result with
            | Ok _ -> Lwt.return (Ok "login_relogin")
            | Error _ as error -> Lwt.return error
      end

let perform_submit state =
  match pick_random !(state.users) with
  | None -> Lwt.return (Ok "submit_skipped_no_users")
  | Some user -> (
      match pick_random !(state.cached_tasks) with
      | None -> Lwt.return (Ok "submit_skipped_no_tasks")
      | Some task ->
          let submit_once session =
            Loadtest_api.submit state.client session ~task_id:task.id
              ~data:(`Assoc [])
          in
          let* session_result = ensure_live_session state user in
          begin
            match session_result with
            | Error _ as error -> Lwt.return error
            | Ok session ->
                let* result = submit_once session in
                begin
                  match result with
                  | Ok _ -> Lwt.return (Ok "submit")
                  | Error message when is_auth_error message ->
                      user.session <- None;
                      let* relogin_result = login_user state user in
                      begin
                        match relogin_result with
                        | Error _ as error -> Lwt.return error
                        | Ok session ->
                            let* retry_result = submit_once session in
                            begin
                              match retry_result with
                              | Ok _ -> Lwt.return (Ok "submit_after_relogin")
                              | Error _ as error -> Lwt.return error
                            end
                      end
                  | Error message when has_prefix ~prefix:"HTTP 404" message ->
                      state.cached_tasks := [];
                      Lwt.return (Ok "submit_stale_cache")
                  | Error _ as error -> Lwt.return error
                end
          end)

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

let add_tasks state requested_count =
  if requested_count < 0 then
    Lwt.return "error add-tasks count must be non-negative"
  else if !(state.users) = [] then
    Lwt.return "error add-tasks requires at least one synthetic user"
  else
    let rec loop created attempts_left =
      if created = requested_count || attempts_left <= 0 then
        Lwt.return (Ok created)
      else
        let index = !(state.next_task_index) in
        state.next_task_index := index + 1;
        let spec = Mock_task.make ~seed:state.seed ~index in
        match pick_zipf_user state with
        | None -> Lwt.return (Ok created)
        | Some author -> (
            let* admin_result = ensure_admin_session state in
            match admin_result with
            | Error _ as error -> Lwt.return error
            | Ok admin_session ->
                let* result =
                  Loadtest_api.create_task state.client admin_session
                    ~client_id:state.admin_client_id ~author_id:author.actor.user_id
                    ~title:spec.title ~description:spec.description
                    ~difficulty:spec.difficulty ()
                in
                match result with
                | Ok task ->
                    state.cached_tasks := task :: !(state.cached_tasks);
                    loop (created + 1) (attempts_left - 1)
                | Error message when is_auth_error message ->
                    state.admin_session := None;
                    loop created (attempts_left - 1)
                | Error message ->
                    prerr_endline
                      (Printf.sprintf "trafficd add-task failed at index=%d: %s"
                         index message);
                    loop created (attempts_left - 1))
    in
    let attempts = max (requested_count * 10) 50 in
    let* result = loop 0 attempts in
    match result with
    | Error message -> Lwt.return ("error " ^ message)
    | Ok created ->
        Lwt.return
          (Printf.sprintf "ok added_tasks %d cached_tasks %d next_task_index %d"
             created (List.length !(state.cached_tasks)) !(state.next_task_index))

let choose_operation state =
  let total = total_rate state in
  if total <= 0.0 then
    None
  else
    let target = Random.float total in
    let rec loop accumulated = function
      | [] -> None
      | operation :: rest ->
          let next = accumulated +. current_rate state operation in
          if target < next then Some operation else loop next rest
    in
    loop 0.0 all_operations

let run_once state =
  match choose_operation state with
  | None -> Lwt.return "idle_no_enabled_operations"
  | Some operation ->
      let* result =
        match operation with
        | List_tasks -> perform_list_tasks state
        | View_task -> perform_view_task state
        | Login -> perform_login state
        | Submit -> perform_submit state
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

let get_rate_response state operation_name_or_none =
  match operation_name_or_none with
  | None -> Printf.sprintf "ok total_rate %.3f" (total_rate state)
  | Some name -> (
      match operation_of_string name with
      | None -> "error unknown operation"
      | Some operation ->
          Printf.sprintf "ok rate %s %.3f" (operation_name operation)
            (current_rate state operation))

let get_rates_response state =
  Printf.sprintf "ok total_rate %.3f %s" (total_rate state) (rates_summary state)

let handle_command state command =
  let parts =
    String.split_on_char ' ' (String.trim command)
    |> List.filter (fun part -> part <> "")
  in
  match parts with
  | [] -> Lwt.return "error empty command"
  | [ "status" ] -> Lwt.return (status_line state)
  | [ "get-rate" ] | [ "rate" ] -> Lwt.return (get_rate_response state None)
  | [ "get-rate"; name ] | [ "rate"; name ] ->
      Lwt.return (get_rate_response state (Some name))
  | [ "get-rates" ] -> Lwt.return (get_rates_response state)
  | [ "set-rate"; name; value ] | [ "rate"; name; value ] -> (
      match operation_of_string name, float_of_string_opt value with
      | None, _ -> Lwt.return "error unknown operation"
      | _, None -> Lwt.return "error rate must be a float"
      | Some _, Some parsed when parsed < 0.0 ->
          Lwt.return "error rate must be non-negative"
      | Some operation, Some parsed ->
          set_rate state operation parsed;
          Lwt.return (get_rates_response state))
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
  | [ "add-tasks"; value ] -> (
      match int_of_string_opt value with
      | None -> Lwt.return "error add-tasks count must be an integer"
      | Some count -> add_tasks state count)
  | [ "remove-users"; value ] -> (
      match int_of_string_opt value with
      | None -> Lwt.return "error remove-users count must be an integer"
      | Some count -> remove_users state count)
  | [ "stop" ] ->
      state.stop_requested := true;
      Lwt.return "ok stopping"
  | _ -> Lwt.return "error unknown command"

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

let install_signal_handlers state =
  let stop _signal = state.stop_requested := true in
  ignore (Lwt_unix.on_signal Sys.sigint stop);
  ignore (Lwt_unix.on_signal Sys.sigterm stop)

let initialize_rates state total =
  let scale = max 0.0 total in
  List.iter
    (fun (operation, weight) -> set_rate state operation (weight *. scale))
    default_weights

let run ~base_url ~seed ~rate ~report_every ~control_socket ~admin_username
    ~admin_password ~admin_client_id =
  let state =
    {
      client = Loadtest_api.make ~base_url;
      seed;
      report_every;
      admin_username;
      admin_password;
      admin_client_id;
      admin_session = ref None;
      running = ref false;
      stop_requested = ref false;
      next_index = ref 1;
      next_task_index = ref 1;
      users = ref [];
      cached_tasks = ref [];
      ops_count = ref 0;
      list_tasks_rate = ref 0.0;
      view_task_rate = ref 0.0;
      login_rate = ref 0.0;
      submit_rate = ref 0.0;
    }
  in
  initialize_rates state rate;
  install_signal_handlers state;
  Printf.printf "trafficd base_url=%s control_socket=%s state=paused %s\n%!"
    base_url control_socket (get_rates_response state);
  Lwt.async (fun () ->
      Traffic_control.serve ~socket_path:control_socket
        ~should_stop:(fun () -> !(state.stop_requested))
        ~handle_command:(handle_command state));
  Lwt.finalize
    (fun () ->
      let rec loop () =
        if !(state.stop_requested) then
          Lwt.return_unit
        else
          let total = total_rate state in
          if (not !(state.running)) || !(state.users) = [] || total <= 0.0 then
            let* () = Lwt_unix.sleep 0.5 in
            loop ()
          else
            let* () = Lwt_unix.sleep (sample_exponential ~rate:total) in
            let* operation = run_once state in
            state.ops_count := !(state.ops_count) + 1;
            if
              state.report_every > 0
              && !(state.ops_count) mod state.report_every = 0
            then
              Printf.printf "trafficd %s last=%s\n%!" (status_line state)
                operation;
            loop ()
      in
      loop ())
    (fun () -> cleanup_users state)

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
      ~doc:"Initial total request rate, split across operation types.")

let report_every_arg =
  Cmdliner.Arg.(
    value & opt int 100 & info [ "report-every" ] ~docv:"N"
      ~doc:"Print a short progress line every N operations.")

let control_socket_arg =
  Cmdliner.Arg.(
    value & opt string "/tmp/trafficd.sock"
    & info [ "control-socket" ] ~docv:"PATH"
      ~doc:"Unix socket used to control trafficd while it is running.")

let admin_username_arg =
  Cmdliner.Arg.(
    value
    & opt (some string)
        (match Sys.getenv_opt "TRAFFICD_ADMIN_USERNAME" with
        | Some value when String.trim value <> "" -> Some value
        | _ -> Sys.getenv_opt "RECOGNITA_ADMIN_USERNAME")
    & info [ "admin-username" ] ~docv:"USERNAME"
      ~doc:"Optional admin username used for add-tasks through the API.")

let admin_password_arg =
  Cmdliner.Arg.(
    value
    & opt (some string)
        (match Sys.getenv_opt "TRAFFICD_ADMIN_PASSWORD" with
        | Some value when String.trim value <> "" -> Some value
        | _ -> Sys.getenv_opt "RECOGNITA_ADMIN_PASSWORD")
    & info [ "admin-password" ] ~docv:"PASSWORD"
      ~doc:"Optional admin password used for add-tasks through the API.")

let admin_client_id_arg =
  Cmdliner.Arg.(
    value
    & opt string
        (match Sys.getenv_opt "TRAFFICD_ADMIN_CLIENT_ID" with
        | Some value when String.trim value <> "" -> value
        | _ -> "trafficd-admin")
    & info [ "admin-client-id" ] ~docv:"CLIENT_ID"
      ~doc:"Client id used by trafficd when logging in as the admin user.")

let cmd =
  let doc = "Stateful OCaml daemon for synthetic Poisson API traffic." in
  let term =
    Cmdliner.Term.(
      const
        (fun base_url seed rate report_every control_socket admin_username
             admin_password admin_client_id ->
          Random.self_init ();
          Lwt_main.run
            (run ~base_url ~seed ~rate ~report_every ~control_socket
               ~admin_username ~admin_password ~admin_client_id))
      $ base_url_arg $ seed_arg $ rate_arg $ report_every_arg
      $ control_socket_arg $ admin_username_arg $ admin_password_arg
      $ admin_client_id_arg)
  in
  Cmdliner.Cmd.v (Cmdliner.Cmd.info "trafficd" ~doc) term

let () = exit (Cmdliner.Cmd.eval cmd)
