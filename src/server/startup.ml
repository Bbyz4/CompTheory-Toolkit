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

let bootstrap_admin_email config =
  match Auth_service.validate_email config.Config.mail_from with
  | Ok email -> email
  | Error _ -> "noreply@recognita.local"

let ensure_bootstrap_admin (repo : Repository.t) clock config =
  match config.Config.recognita_admin_username, config.recognita_admin_password with
  | None, None -> Lwt.return (Ok ())
  | Some _, None | None, Some _ ->
      Lwt.return
        (Error
           (App_error.Internal
              "RECOGNITA_ADMIN_USERNAME and RECOGNITA_ADMIN_PASSWORD must be set together"))
  | Some username, Some password -> (
      match Auth_service.validate_username username, Auth_service.validate_password password with
      | Error app_error, _ | _, Error app_error ->
          Lwt.return
            (Error
               (App_error.Internal
                  ("Invalid bootstrap admin credentials: "
                  ^ App_error.message app_error)))
      | Ok (), Ok () ->
          let now = clock.Clock.now () in
          let password_hash = Password.make password in
          let email = bootstrap_admin_email config in
          let* found = repo.find_user_by_username username in
          match found with
          | Error repo_error ->
              Lwt.return
                (Error
                   (App_error.Internal
                      ("Failed to load bootstrap admin: "
                      ^ Repository.error_message repo_error)))
          | Ok None ->
              let* created =
                repo.create_user ~username ~email ~password_hash
                  ~role:Domain.Admin ~created_at:now
              in
              begin
                match created with
                | Error repo_error ->
                    Lwt.return
                      (Error
                         (App_error.Internal
                            ("Failed to create bootstrap admin: "
                            ^ Repository.error_message repo_error)))
                | Ok user ->
                    let* verified =
                      repo.mark_user_verified ~user_id:user.Domain.id ~updated_at:now
                    in
                    begin
                      match verified with
                      | Ok _ -> Lwt.return (Ok ())
                      | Error repo_error ->
                          Lwt.return
                            (Error
                               (App_error.Internal
                                  ("Failed to verify bootstrap admin: "
                                  ^ Repository.error_message repo_error)))
                    end
              end
          | Ok (Some user) ->
              let* updated =
                repo.update_bootstrap_admin ~user_id:user.Domain.id ~email
                  ~password_hash ~updated_at:now
              in
              begin
                match updated with
                | Ok _ -> Lwt.return (Ok ())
                | Error repo_error ->
                    Lwt.return
                      (Error
                         (App_error.Internal
                            ("Failed to refresh bootstrap admin: "
                            ^ Repository.error_message repo_error)))
              end)

let run config clock =
  let* migration_result =
    run_with_connection config.Config.db_url (fun connection ->
        let repo = Caqti_repo.make connection in
        let* init_result = repo.init_schema () in
        match init_result with
        | Error repo_error ->
            Lwt.return
              (Error
                 (App_error.Internal
                    ("Failed to initialize schema: "
                    ^ Repository.error_message repo_error)))
        | Ok () -> ensure_bootstrap_admin repo clock config)
  in
  match migration_result with
  | Error _ as error -> Lwt.return error
  | Ok () -> Lwt.return (Ok ())
