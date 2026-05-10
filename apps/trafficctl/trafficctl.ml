let socket_arg =
  Cmdliner.Arg.(
    value & opt string "/tmp/trafficd.sock"
    & info [ "socket" ] ~docv:"PATH"
      ~doc:"Unix control socket exposed by trafficd.")

let rate_pos_arg =
  Cmdliner.Arg.(
    required & pos 1 (some float) None
    & info [] ~docv:"RATE" ~doc:"New average request rate in requests per second.")

let operation_pos_arg =
  Cmdliner.Arg.(
    required & pos 0 (some string) None
    & info [] ~docv:"OPERATION"
      ~doc:
        "Traffic operation: list_tasks, view_task, login, submit, logout.")

let optional_operation_pos_arg =
  Cmdliner.Arg.(
    value & pos 0 (some string) None
    & info [] ~docv:"OPERATION"
      ~doc:
        "Optional traffic operation: list_tasks, view_task, login, submit, logout.")

let count_pos_arg =
  Cmdliner.Arg.(
    required & pos 0 (some int) None
    & info [] ~docv:"COUNT" ~doc:"Number of users to add or remove.")

let print_response socket_path command =
  let response =
    Lwt_main.run (Toolkit.Traffic_control.send_command ~socket_path command)
  in
  print_endline response

let make_simple_cmd name ~doc command =
  let term =
    Cmdliner.Term.(
      const
        (fun socket_path -> print_response socket_path command)
      $ socket_arg)
  in
  Cmdliner.Cmd.v (Cmdliner.Cmd.info name ~doc) term

let status_cmd =
  make_simple_cmd "status" ~doc:"Read the current trafficd state." "status"

let start_cmd =
  make_simple_cmd "start" ~doc:"Start generating traffic inside trafficd."
    "start"

let pause_cmd =
  make_simple_cmd "pause" ~doc:"Pause traffic generation inside trafficd."
    "pause"

let get_rate_cmd =
  let doc =
    "Read the current total rate, or the rate of one specific traffic operation, in requests per second."
  in
  let term =
    Cmdliner.Term.(
      const
        (fun socket_path operation ->
          let command =
            match operation with
            | None -> "get-rate"
            | Some value -> "get-rate " ^ value
          in
          print_response socket_path command)
      $ socket_arg $ optional_operation_pos_arg)
  in
  Cmdliner.Cmd.v (Cmdliner.Cmd.info "get-rate" ~doc) term

let get_rates_cmd =
  make_simple_cmd "get-rates"
    ~doc:"Read all per-operation traffic rates in requests per second." "get-rates"

let set_rate_cmd =
  let doc =
    "Update the rate of one traffic operation while trafficd is running, in requests per second."
  in
  let term =
    Cmdliner.Term.(
      const
        (fun socket_path operation rate ->
          print_response socket_path
            (Printf.sprintf "set-rate %s %.6f" operation rate))
      $ socket_arg $ operation_pos_arg $ rate_pos_arg)
  in
  Cmdliner.Cmd.v (Cmdliner.Cmd.info "set-rate" ~doc) term

let add_users_cmd =
  let doc = "Create and register more synthetic users through the API." in
  let term =
    Cmdliner.Term.(
      const
        (fun socket_path count ->
          print_response socket_path (Printf.sprintf "add-users %d" count))
      $ socket_arg $ count_pos_arg)
  in
  Cmdliner.Cmd.v (Cmdliner.Cmd.info "add-users" ~doc) term

let remove_users_cmd =
  let doc = "Delete synthetic users through the API." in
  let term =
    Cmdliner.Term.(
      const
        (fun socket_path count ->
          print_response socket_path (Printf.sprintf "remove-users %d" count))
      $ socket_arg $ count_pos_arg)
  in
  Cmdliner.Cmd.v (Cmdliner.Cmd.info "remove-users" ~doc) term

let stop_cmd =
  make_simple_cmd "stop" ~doc:"Ask trafficd to stop and clean up synthetic data."
    "stop"

let cmd =
  let doc = "Control a running trafficd daemon." in
  Cmdliner.Cmd.group (Cmdliner.Cmd.info "trafficctl" ~doc)
    [
      status_cmd;
      start_cmd;
      pause_cmd;
      get_rate_cmd;
      get_rates_cmd;
      set_rate_cmd;
      add_users_cmd;
      remove_users_cmd;
      stop_cmd;
    ]

let () = exit (Cmdliner.Cmd.eval cmd)
