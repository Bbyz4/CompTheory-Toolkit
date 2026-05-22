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
          Random.init seed;
          Lwt_main.run
            (Trafficd_runtime.run ~base_url ~seed ~rate ~report_every
               ~control_socket ~admin_username ~admin_password
               ~admin_client_id))
      $ base_url_arg $ seed_arg $ rate_arg $ report_every_arg
      $ control_socket_arg $ admin_username_arg $ admin_password_arg
      $ admin_client_id_arg)
  in
  Cmdliner.Cmd.v (Cmdliner.Cmd.info "trafficd" ~doc) term

let () = exit (Cmdliner.Cmd.eval cmd)
