let ( let* ) = Lwt.bind

open Toolkit
open Trafficd_types

let install_signal_handlers state =
  let stop _signal = state.stop_requested := true in
  ignore (Lwt_unix.on_signal Sys.sigint stop);
  ignore (Lwt_unix.on_signal Sys.sigterm stop)

let initialize_rates state total =
  let scale = max 0.0 total in
  List.iter
    (fun (operation, weight) ->
      Trafficd_helpers.set_rate state operation (weight *. scale))
    Trafficd_helpers.default_weights

let create_state ~base_url ~seed ~report_every ~admin_username ~admin_password
    ~admin_client_id =
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

let run ~base_url ~seed ~rate ~report_every ~control_socket ~admin_username
    ~admin_password ~admin_client_id =
  let state =
    create_state ~base_url ~seed ~report_every ~admin_username ~admin_password
      ~admin_client_id
  in
  initialize_rates state rate;
  install_signal_handlers state;
  Printf.printf "trafficd base_url=%s control_socket=%s state=paused %s\n%!"
    base_url control_socket (Trafficd_control.get_rates_response state);
  Lwt.async (fun () ->
      Traffic_control.serve ~socket_path:control_socket
        ~should_stop:(fun () -> !(state.stop_requested))
        ~handle_command:(Trafficd_control.handle_command state));
  Lwt.finalize
    (fun () ->
      let rec loop () =
        if !(state.stop_requested) then
          Lwt.return_unit
        else
          let total = Trafficd_helpers.total_rate state in
          if (not !(state.running)) || !(state.users) = [] || total <= 0.0 then
            let* () = Lwt_unix.sleep 0.5 in
            loop ()
          else
            let* () =
              Lwt_unix.sleep (Trafficd_helpers.sample_exponential ~rate:total)
            in
            let* operation = Trafficd_tasks.run_once state in
            state.ops_count := !(state.ops_count) + 1;
            if
              state.report_every > 0
              && !(state.ops_count) mod state.report_every = 0
            then
              Printf.printf "trafficd %s last=%s\n%!"
                (Trafficd_helpers.status_line state)
                operation;
            loop ()
      in
      loop ())
    (fun () -> Trafficd_users.cleanup_users state)
