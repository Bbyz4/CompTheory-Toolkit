let ( let* ) = Lwt.bind

let run_with_connection db_url handler =
  let uri = Uri.of_string db_url in
  let* connected = Caqti_lwt.connect uri in
  match connected with
  | Error error ->
      Lwt.fail_with
        ("Failed to connect to database: " ^ Caqti_error.show error)
  | Ok connection -> handler connection

let () =
  Random.self_init ();
  let config = Toolkit.Config.load () in
  let clock = Toolkit.Clock.system in
  let startup_result = Lwt_main.run (Toolkit.Startup.run config clock) in
  (match startup_result with
  | Error app_error ->
      prerr_endline
        ("Startup failed: " ^ Toolkit.App_error.message app_error);
      exit 1
  | Ok () -> ());
  let queue =
    Toolkit.Submission_queue.make_rabbitmq_http
      ~base_url:config.rabbitmq_api_base_url ~username:config.rabbitmq_user
      ~password:config.rabbitmq_password ~vhost:config.rabbitmq_vhost
      ~queue_name:config.rabbitmq_submission_queue ()
  in
  Lwt_main.run
    (run_with_connection config.db_url (fun connection ->
         let repo = Toolkit.Caqti_repo.make connection in
         let worker_deps : Toolkit.Submission_worker.deps = { repo; queue; clock } in
         Toolkit.Submission_worker.run_forever
           ~poll_interval_seconds:config.submission_worker_poll_interval_seconds
           worker_deps))
