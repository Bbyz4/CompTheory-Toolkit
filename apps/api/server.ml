let () =
  let config = Toolkit.Config.load () in
  let clock = Toolkit.Clock.system in
  let mailer =
    Toolkit.Verification_mailer.make_smtp ~host:config.smtp_host
      ~port:config.smtp_port ~from_address:config.mail_from
      ~site_name:"Recognita"
  in
  let rate_limiter =
    Toolkit.Rate_limiter.make ~clock
      ~auth_rule:
        {
          Toolkit.Rate_limiter.max_requests = config.auth_rate_limit_max_requests;
          window_seconds = config.auth_rate_limit_window_seconds;
        }
      ~default_rule:
        {
          Toolkit.Rate_limiter.max_requests = config.rate_limit_max_requests;
          window_seconds = config.rate_limit_window_seconds;
        }
  in
  let startup_result = Lwt_main.run (Toolkit.Startup.run config clock) in
  (match startup_result with
  | Error app_error ->
      prerr_endline
        ("Startup failed: " ^ Toolkit.App_error.message app_error);
      exit 1
  | Ok () -> ());
  let app =
    let app_config : Toolkit.App.t =
      {
        config;
        clock;
        rate_limiter;
        mailer;
        with_repo =
          (fun request handler ->
            Dream.sql request (fun connection ->
                handler (Toolkit.Caqti_repo.make connection)));
      }
    in
    Toolkit.App.make app_config
  in
  Dream.run ~interface:config.host ~port:config.port
  @@ Dream.logger
  @@ Dream.sql_pool config.db_url
  @@ app
