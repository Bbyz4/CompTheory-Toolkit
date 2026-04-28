let ( let* ) = Lwt.bind

let run_with_connection db_url handler =
  let uri = Uri.of_string db_url in
  let* connected = Caqti_lwt.connect uri in
  match connected with
  | Error error ->
      Lwt.return
        (Error
           (App_error.Internal
              ("Failed to connect to database: " ^ Caqti_error.show error)))
  | Ok connection -> handler connection

let run config clock =
  let* migration_result =
    run_with_connection config.Config.db_url (fun connection ->
        let repo = Caqti_repo.make connection in
        let* result = repo.init_schema () in
        Lwt.return
          (Result.map_error
             (fun repo_error ->
               App_error.Internal
                 ("Failed to initialize schema: "
                 ^ Repository.error_message repo_error))
             result))
  in
  match migration_result with
  | Error _ as error -> Lwt.return error
  | Ok () ->
      run_with_connection config.Config.db_url (fun connection ->
          let repo = Caqti_repo.make connection in
          Auth_service.bootstrap_admin
            {
              repo;
              clock;
              config;
              mailer = Verification_mailer.noop;
            })
